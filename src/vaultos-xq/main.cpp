// vaultos-xq — batch xfconf get/set/reset over one libxfconf connection.
//
// Replaces the per-property `xfconf-query` get + set pairs in bin/vault-os
// (xq_set / xq_get). A set is skipped when the stored value already matches
// (string match, or numeric match so 100 == 100.000000), because xfwm4 and
// the panel treat a same-value write as a reload.
//
// Usage:
//   vaultos-xq [opts] set CHANNEL PROP -t TYPE -s VALUE [-t TYPE -s VALUE ...]
//   vaultos-xq [opts] set CHANNEL PROP TYPE VALUE [TYPE VALUE ...]
//   vaultos-xq [opts] get CHANNEL PROP          (prints like xfconf-query)
//   vaultos-xq [opts] reset CHANNEL PROP [-R]
//   vaultos-xq [opts] [batch]                   (ops on stdin, one per line)
//
// Batch lines: [set|get|reset] CHANNEL PROP [TYPE VALUE]...
//   A line without an op word is a set. Fields are TAB-separated when the line
//   holds a TAB, otherwise split shell-style ("quotes" and \ escapes work).
//   Blank lines and lines starting with # are ignored. Several TYPE VALUE
//   pairs make an array. `reset` takes an optional trailing -R (recursive).
//   Batch get output: CHANNEL<TAB>PROP<TAB>VALUE[<TAB>VALUE...] per line,
//   nothing for a missing property.
//
// Options: -n/--dry-run (report, never write)  -v/--verbose  --stats
// Types:   string int uint int64 uint64 bool float double
// Exit:    0 ok, 1 some op failed / get of a missing property,
//          2 usage or unsupported type (callers fall back to xfconf-query),
//          3 could not reach xfconfd.
#include <xfconf/xfconf.h>
#include <cctype>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

namespace {

struct Opts {
  bool dry = false, verbose = false, stats = false, batch_out = false;
};

struct Stats {
  int set = 0, same = 0, failed = 0, got = 0, reset = 0;
};

Opts g_opt;
Stats g_stats;

constexpr int kOk = 0, kFail = 1, kUsage = 2, kNoDaemon = 3;

// ---- value <-> string -------------------------------------------------------

std::string scalar_to_string(const GValue* v) {
  char buf[64];
  switch (G_VALUE_TYPE(v)) {
    case G_TYPE_STRING: {
      const char* s = g_value_get_string(v);
      return s ? s : "";
    }
    case G_TYPE_BOOLEAN: return g_value_get_boolean(v) ? "true" : "false";
    case G_TYPE_INT: return std::to_string(g_value_get_int(v));
    case G_TYPE_UINT: return std::to_string(g_value_get_uint(v));
    case G_TYPE_INT64: return std::to_string(g_value_get_int64(v));
    case G_TYPE_UINT64: return std::to_string(g_value_get_uint64(v));
    case G_TYPE_UCHAR: return std::to_string(g_value_get_uchar(v));
    case G_TYPE_CHAR: return std::to_string(g_value_get_schar(v));
    case G_TYPE_DOUBLE:
      std::snprintf(buf, sizeof buf, "%f", g_value_get_double(v));
      return buf;
    case G_TYPE_FLOAT:
      std::snprintf(buf, sizeof buf, "%f", double(g_value_get_float(v)));
      return buf;
    default: break;
  }
  if (G_VALUE_HOLDS(v, XFCONF_TYPE_INT16)) return std::to_string(xfconf_g_value_get_int16(v));
  if (G_VALUE_HOLDS(v, XFCONF_TYPE_UINT16)) return std::to_string(xfconf_g_value_get_uint16(v));
  GValue sv = G_VALUE_INIT;
  g_value_init(&sv, G_TYPE_STRING);
  std::string out;
  if (g_value_transform(v, &sv) && g_value_get_string(&sv)) out = g_value_get_string(&sv);
  g_value_unset(&sv);
  return out;
}

bool is_array(const GValue* v) { return G_VALUE_HOLDS(v, G_TYPE_PTR_ARRAY); }

// Flatten like xq_set's read loop: arrays become their item lines.
std::vector<std::string> value_lines(const GValue* v) {
  std::vector<std::string> out;
  if (is_array(v)) {
    auto* arr = static_cast<GPtrArray*>(g_value_get_boxed(v));
    for (guint i = 0; arr && i < arr->len; ++i)
      out.push_back(scalar_to_string(static_cast<const GValue*>(g_ptr_array_index(arr, i))));
  } else {
    out.push_back(scalar_to_string(v));
  }
  return out;
}

bool is_plain_number(const std::string& s) {  // ^-?[0-9]+([.][0-9]+)?$
  size_t i = 0, n = s.size();
  if (i < n && s[i] == '-') ++i;
  size_t d = i;
  while (i < n && std::isdigit(static_cast<unsigned char>(s[i]))) ++i;
  if (i == d) return false;
  if (i < n && s[i] == '.') {
    size_t f = ++i;
    while (i < n && std::isdigit(static_cast<unsigned char>(s[i]))) ++i;
    if (i == f) return false;
  }
  return i == n;
}

bool vals_equal(const std::string& a, const std::string& b) {
  if (a == b) return true;
  if (!is_plain_number(a) || !is_plain_number(b)) return false;
  return g_ascii_strtod(a.c_str(), nullptr) == g_ascii_strtod(b.c_str(), nullptr);
}

// Fill an uninitialised GValue from TYPE + text. false on bad type/text.
bool parse_value(const std::string& type, const std::string& text, GValue* v, std::string* err) {
  const char* s = text.c_str();
  char* end = nullptr;
  errno = 0;
  auto bad = [&](const char* what) {
    *err = std::string("cannot parse \"") + text + "\" as " + what;
    return false;
  };
  if (type == "string") {
    g_value_init(v, G_TYPE_STRING);
    g_value_set_string(v, s);
  } else if (type == "bool") {
    gboolean b;
    if (!g_ascii_strcasecmp(s, "true") || !std::strcmp(s, "1")) b = TRUE;
    else if (!g_ascii_strcasecmp(s, "false") || !std::strcmp(s, "0")) b = FALSE;
    else return bad("bool");
    g_value_init(v, G_TYPE_BOOLEAN);
    g_value_set_boolean(v, b);
  } else if (type == "int") {
    long long n = std::strtoll(s, &end, 0);
    if (!*s || *end || errno || n < G_MININT || n > G_MAXINT) return bad("int");
    g_value_init(v, G_TYPE_INT);
    g_value_set_int(v, int(n));
  } else if (type == "uint") {
    if (*s == '-') return bad("uint");
    unsigned long long n = std::strtoull(s, &end, 0);
    if (!*s || *end || errno || n > G_MAXUINT) return bad("uint");
    g_value_init(v, G_TYPE_UINT);
    g_value_set_uint(v, guint(n));
  } else if (type == "int64") {
    long long n = std::strtoll(s, &end, 0);
    if (!*s || *end || errno) return bad("int64");
    g_value_init(v, G_TYPE_INT64);
    g_value_set_int64(v, n);
  } else if (type == "uint64") {
    if (*s == '-') return bad("uint64");
    unsigned long long n = std::strtoull(s, &end, 0);
    if (!*s || *end || errno) return bad("uint64");
    g_value_init(v, G_TYPE_UINT64);
    g_value_set_uint64(v, n);
  } else if (type == "double" || type == "float") {
    double d = g_ascii_strtod(s, &end);
    if (!*s || *end || errno || !std::isfinite(d)) return bad(type.c_str());
    if (type == "double") {
      g_value_init(v, G_TYPE_DOUBLE);
      g_value_set_double(v, d);
    } else {
      g_value_init(v, G_TYPE_FLOAT);
      g_value_set_float(v, float(d));
    }
  } else {
    *err = "unsupported type \"" + type + "\"";
    return false;
  }
  return true;
}

// ---- ops ----------------------------------------------------------------------

struct Pair {
  std::string type, value;
};

std::string join(const std::vector<std::string>& v, const char* sep) {
  std::string out;
  for (size_t i = 0; i < v.size(); ++i) out += (i ? sep : "") + v[i];
  return out;
}

int op_get(const std::string& ch, const std::string& prop) {
  XfconfChannel* c = xfconf_channel_get(ch.c_str());
  GValue v = G_VALUE_INIT;
  if (!xfconf_channel_get_property(c, prop.c_str(), &v)) {
    if (!g_opt.batch_out)
      std::fprintf(stderr, "Property \"%s\" does not exist on channel \"%s\".\n", prop.c_str(), ch.c_str());
    return kFail;
  }
  ++g_stats.got;
  auto lines = value_lines(&v);
  if (g_opt.batch_out) {
    std::printf("%s\t%s\t%s\n", ch.c_str(), prop.c_str(), join(lines, "\t").c_str());
  } else if (is_array(&v)) {
    std::printf("Value is an array with %zu items:\n\n", lines.size());
    for (auto& l : lines) std::printf("%s\n", l.c_str());
  } else {
    std::printf("%s\n", lines[0].c_str());
  }
  g_value_unset(&v);
  return kOk;
}

int op_set(const std::string& ch, const std::string& prop, const std::vector<Pair>& pairs) {
  if (pairs.empty()) {
    std::fprintf(stderr, "vaultos-xq: set %s %s: no value\n", ch.c_str(), prop.c_str());
    return kUsage;
  }
  // Parse first so a bad line never half-applies.
  std::vector<GValue*> vals;
  std::string err;
  auto free_vals = [&] {
    for (GValue* g : vals) {
      g_value_unset(g);
      g_free(g);
    }
  };
  for (auto& p : pairs) {
    GValue* g = g_new0(GValue, 1);
    vals.push_back(g);
    if (!parse_value(p.type, p.value, g, &err)) {
      std::fprintf(stderr, "vaultos-xq: set %s %s: %s\n", ch.c_str(), prop.c_str(), err.c_str());
      free_vals();
      return kUsage;
    }
  }

  XfconfChannel* c = xfconf_channel_get(ch.c_str());
  std::vector<std::string> want;
  for (auto& p : pairs) want.push_back(p.value);
  std::vector<std::string> cur;
  GValue curv = G_VALUE_INIT;
  bool exists = xfconf_channel_get_property(c, prop.c_str(), &curv);
  if (exists) {
    cur = value_lines(&curv);
    g_value_unset(&curv);
  }
  if (exists && cur.size() == want.size()) {
    bool same = true;
    for (size_t i = 0; i < want.size() && same; ++i) same = vals_equal(cur[i], want[i]);
    if (same) {
      ++g_stats.same;
      if (g_opt.verbose) std::fprintf(stderr, "same  %s %s = %s\n", ch.c_str(), prop.c_str(), join(want, ",").c_str());
      free_vals();
      return kOk;
    }
  }
  if (g_opt.dry || g_opt.verbose)
    std::fprintf(g_opt.dry ? stdout : stderr, "%s %s %s: %s -> %s\n", g_opt.dry ? "would set" : "set ",
                 ch.c_str(), prop.c_str(), exists ? ("[" + join(cur, ",") + "]").c_str() : "(missing)",
                 ("[" + join(want, ",") + "]").c_str());
  if (g_opt.dry) {
    ++g_stats.set;
    free_vals();
    return kOk;
  }

  auto write = [&]() -> bool {
    if (vals.size() == 1) return xfconf_channel_set_property(c, prop.c_str(), vals[0]);
    GPtrArray* arr = g_ptr_array_sized_new(vals.size());
    for (GValue* g : vals) g_ptr_array_add(arr, g);
    gboolean ok = xfconf_channel_set_arrayv(c, prop.c_str(), arr);
    g_ptr_array_free(arr, TRUE);  // values still owned by `vals`
    return ok;
  };
  bool ok = write();
  if (!ok && exists) {  // type clash: same as xq_set's -r then -n
    xfconf_channel_reset_property(c, prop.c_str(), FALSE);
    ok = write();
  }
  free_vals();
  if (!ok) {
    ++g_stats.failed;
    std::fprintf(stderr, "vaultos-xq: set %s %s failed\n", ch.c_str(), prop.c_str());
    return kFail;
  }
  ++g_stats.set;
  return kOk;
}

int op_reset(const std::string& ch, const std::string& prop, bool recursive) {
  XfconfChannel* c = xfconf_channel_get(ch.c_str());
  if (g_opt.dry) {
    std::printf("would reset %s %s%s\n", ch.c_str(), prop.c_str(), recursive ? " (recursive)" : "");
    ++g_stats.reset;
    return kOk;
  }
  xfconf_channel_reset_property(c, prop.c_str(), recursive);
  ++g_stats.reset;
  return kOk;
}

// args after the op word: CHANNEL PROP [...]
int run_op(const std::string& op, const std::vector<std::string>& a) {
  if (a.size() < 2 || a[0].empty() || a[1].empty() || a[1][0] != '/') {
    std::fprintf(stderr, "vaultos-xq: %s needs CHANNEL /PROP\n", op.c_str());
    return kUsage;
  }
  const std::string &ch = a[0], &prop = a[1];
  if (op == "get") return a.size() == 2 ? op_get(ch, prop) : kUsage;
  if (op == "reset") {
    bool rec = a.size() == 3 && (a[2] == "-R" || a[2] == "--recursive");
    if (a.size() > 3 || (a.size() == 3 && !rec)) return kUsage;
    return op_reset(ch, prop, rec);
  }
  // set: "-t T -s V" pairs (xfconf-query style) or bare "T V" pairs
  std::vector<Pair> pairs;
  for (size_t i = 2; i < a.size();) {
    if (a[i] == "-t" || a[i] == "--type") {
      if (i + 2 >= a.size() || (a[i + 2] != "-s" && a[i + 2] != "--set") || i + 3 >= a.size()) return kUsage;
      pairs.push_back({a[i + 1], a[i + 3]});
      i += 4;
    } else if (!a[i].empty() && a[i][0] == '-' && a[i].size() > 1 && !std::isdigit(static_cast<unsigned char>(a[i][1]))) {
      return kUsage;  // -n, -a, --force-array, ... : let xfconf-query handle it
    } else {
      if (i + 1 >= a.size()) return kUsage;
      pairs.push_back({a[i], a[i + 1]});
      i += 2;
    }
  }
  return op_set(ch, prop, pairs);
}

bool split_line(const std::string& line, std::vector<std::string>* out) {
  out->clear();
  if (line.find('\t') != std::string::npos) {
    size_t start = 0;
    for (;;) {
      size_t t = line.find('\t', start);
      out->push_back(line.substr(start, t == std::string::npos ? std::string::npos : t - start));
      if (t == std::string::npos) break;
      start = t + 1;
    }
    return true;
  }
  int argc = 0;
  gchar** argv = nullptr;
  if (!g_shell_parse_argv(line.c_str(), &argc, &argv, nullptr)) return false;
  for (int i = 0; i < argc; ++i) out->push_back(argv[i]);
  g_strfreev(argv);
  return true;
}

int run_batch() {
  g_opt.batch_out = true;
  int rc = kOk;
  std::string line;
  long n = 0;
  std::vector<std::string> f;
  while (std::getline(std::cin, line)) {
    ++n;
    if (!line.empty() && line.back() == '\r') line.pop_back();
    size_t lead = line.find_first_not_of(" \t");
    if (lead == std::string::npos || line[lead] == '#') continue;
    if (!split_line(line, &f) || f.empty()) {
      std::fprintf(stderr, "vaultos-xq: line %ld: cannot parse\n", n);
      rc = kFail;
      ++g_stats.failed;
      continue;
    }
    std::string op = "set";
    if (f[0] == "set" || f[0] == "get" || f[0] == "reset") {
      op = f[0];
      f.erase(f.begin());
    }
    int r = run_op(op, f);
    if (r == kFail && op == "get") r = kOk;  // missing on get is not an error in batch
    if (r != kOk) {
      if (r == kUsage) {
        std::fprintf(stderr, "vaultos-xq: line %ld: bad op\n", n);
        ++g_stats.failed;
      }
      rc = kFail;
    }
  }
  return rc;
}

void usage() {
  std::fputs(
      "usage: vaultos-xq [-n|--dry-run] [-v] [--stats] set CH /PROP -t TYPE -s VALUE [...]\n"
      "       vaultos-xq [opts] get CH /PROP\n"
      "       vaultos-xq [opts] reset CH /PROP [-R]\n"
      "       vaultos-xq [opts] [batch] < lines   ([set|get|reset] CH /PROP [TYPE VALUE]...)\n",
      stderr);
}

}  // namespace

int main(int argc, char** argv) {
  std::vector<std::string> args;
  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    if (args.empty() && (a == "-n" || a == "--dry-run")) g_opt.dry = true;
    else if (args.empty() && (a == "-v" || a == "--verbose")) g_opt.verbose = true;
    else if (args.empty() && a == "--stats") g_opt.stats = true;
    else if (args.empty() && (a == "-h" || a == "--help")) { usage(); return kOk; }
    else args.push_back(a);
  }
  std::string op = args.empty() ? "batch" : args[0];
  if (op == "-") op = "batch";
  if (op != "batch" && op != "set" && op != "get" && op != "reset") {
    usage();
    return kUsage;
  }

  GError* err = nullptr;
  if (!xfconf_init(&err)) {
    std::fprintf(stderr, "vaultos-xq: cannot reach xfconfd: %s\n", err ? err->message : "?");
    if (err) g_error_free(err);
    return kNoDaemon;
  }
  int rc;
  if (op == "batch") rc = args.size() <= 1 ? run_batch() : kUsage;
  else rc = run_op(op, std::vector<std::string>(args.begin() + 1, args.end()));
  if (rc == kUsage && op != "batch") usage();
  if (g_opt.stats || g_opt.verbose)
    std::fprintf(stderr, "vaultos-xq: %d set%s, %d unchanged, %d reset, %d got, %d failed\n", g_stats.set,
                 g_opt.dry ? " (dry-run)" : "", g_stats.same, g_stats.reset, g_stats.got, g_stats.failed);
  std::fflush(stdout);
  xfconf_shutdown();  // flushes pending property writes
  return rc;
}

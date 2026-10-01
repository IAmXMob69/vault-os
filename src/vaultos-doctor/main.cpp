// vaultos-doctor — native port of the read-only checks in bin/vault-os:
//
//   vaultos-doctor lint [PATH]   repo design-bar lint (no X session)
//   vaultos-doctor doctor        status + live rules + repo lint
//   vaultos-doctor status        the status block on its own
//
// Options (bin/vault-os passes them when it delegates):
//   --repo PATH          checkout for doctor (default: $VAULT_OS_ROOT,
//                        ~/Projects/vault-os, ~/Vault.OS)
//   --cli-version V      version of the calling vault-os script
//
// Output is byte-for-byte the bash output, including ordering: find/grep -r
// walk directories in readdir order, globs and diff -r sort with strcoll,
// `sort -u` too. Nothing here writes: no xfconf sets, no restarts, no
// ensure-*. `vault-os doctor --fix` stays in bash.
#include <dirent.h>
#include <fnmatch.h>
#include <locale.h>
#include <sys/stat.h>
#include <unistd.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <regex>
#include <string>
#include <vector>

#include "proc.hpp"
#include "text.hpp"

using std::string;
using std::vector;
using vaultos::contains;
using vaultos::is_dir;
using vaultos::is_reg;
using vaultos::slurp;
using vaultos::starts_with;

namespace {

// ------------------------------------------------------------- output ----

int g_fail = 0, g_warn = 0;
string g_out;  // buffered stdout, flushed at exit (and before child output)

void emit(const string& s) { g_out += s; }
void flush_out() {
  fwrite(g_out.data(), 1, g_out.size(), stdout);
  fflush(stdout);
  g_out.clear();
}

string pad(const string& s, size_t w) { return s.size() >= w ? s : s + string(w - s.size(), ' '); }

// _chk OK|WARN|FAIL|SKIP label detail
void chk(const string& v, const string& label, const string& detail) {
  if (v == "FAIL") ++g_fail;
  if (v == "WARN") ++g_warn;
  emit(pad(label, 14) + " " + pad(v, 4) + " " + detail + "\n");
}

// printf '%s\n' "$x" | _chk_list N
void chk_list(const string& text, int max, bool add_newline = true) {
  string t = add_newline ? text + "\n" : text;
  vector<string> ls = vaultos::split(t, '\n');
  if (!ls.empty() && ls.back().empty()) ls.pop_back();  // read loop ignores a final unterminated ""
  int n = 0;
  for (auto& l : ls) {
    ++n;
    if (n <= max) emit("                    " + l + "\n");
  }
  if (n > max) emit("                    … +" + std::to_string(n - max) + " more\n");
}

string join(const vector<string>& v, const string& sep) {
  string o;
  for (size_t i = 0; i < v.size(); ++i) o += (i ? sep : "") + v[i];
  return o;
}

// -------------------------------------------------------- environment ----

string HOME, XDG_CFG;
string VERSION = "?";
std::map<string, string> CONF;

string env_or(const char* k, const string& d) {
  const char* v = std::getenv(k);
  return (v && *v) ? v : d;
}

bool exists(const string& p) { struct stat st; return stat(p.c_str(), &st) == 0; }

string realpath_s(const string& p) {
  char* r = realpath(p.c_str(), nullptr);
  if (!r) return "";
  string s = r;
  free(r);
  return s;
}

int coll(const string& a, const string& b) {
  int r = strcoll(a.c_str(), b.c_str());
  return r ? r : a.compare(b);
}
void sort_coll(vector<string>& v) {
  std::sort(v.begin(), v.end(), [](const string& a, const string& b) { return coll(a, b) < 0; });
}

// "$dir"/PATTERN as bash expands it: no dotfiles, sorted with strcoll.
vector<string> glob_dir(const string& dir, const string& pat) {
  vector<string> names;
  DIR* d = opendir(dir.c_str());
  if (!d) return names;
  while (dirent* e = readdir(d)) {
    string n = e->d_name;
    if (n == "." || n == "..") continue;
    if (fnmatch(pat.c_str(), n.c_str(), FNM_PERIOD) == 0) names.push_back(n);
  }
  closedir(d);
  sort_coll(names);
  for (auto& n : names) n = dir + "/" + n;
  return names;
}

// Directory entries in readdir order (what find/grep -r/fts see).
vector<string> readdir_names(const string& dir) {
  vector<string> names;
  DIR* d = opendir(dir.c_str());
  if (!d) return names;
  while (dirent* e = readdir(d)) {
    string n = e->d_name;
    if (n != "." && n != "..") names.push_back(n);
  }
  closedir(d);
  return names;
}

// Pre-order walk like `find -P PATH`: VISIT(path, name, is_dir, is_reg)
// returns false to prune a directory.
template <class F>
void walk(const string& path, const string& name, F&& visit) {
  struct stat st;
  if (lstat(path.c_str(), &st) != 0) return;
  bool d = S_ISDIR(st.st_mode);
  if (!visit(path, name, d, S_ISREG(st.st_mode))) return;
  if (!d) return;
  for (auto& n : readdir_names(path)) walk(path + "/" + n, n, visit);
}
template <class F>
void walk(const string& path, F&& visit) {
  size_t s = path.find_last_of('/');
  walk(path, s == string::npos ? path : path.substr(s + 1), visit);
}

string first_line(const string& s) {
  size_t n = s.find('\n');
  return n == string::npos ? s : s.substr(0, n);
}
string last_line(const string& s) {  // `| tail -1` then $(...)
  string t = vaultos::chomp(s);
  size_t n = t.rfind('\n');
  return n == string::npos ? t : t.substr(n + 1);
}

bool grep_x(const string& file, const string& line) {  // grep -qx LINE (fixed regex chars are literal here)
  string s;
  if (!slurp(file, s)) return false;
  for (auto& l : vaultos::split(s, '\n')) if (l == line) return true;
  return false;
}
bool grep_re(const string& file, const std::regex& re) {
  string s;
  if (!slurp(file, s)) return false;
  for (auto& l : vaultos::split(s, '\n')) if (std::regex_search(l, re)) return true;
  return false;
}
bool cmp_s(const string& a, const string& b) {
  string x, y;
  return slurp(a, x) && slurp(b, y) && x == y;
}

// $(cat FILE 2>/dev/null || echo DEF)
string cat_or(const string& f, const string& def) {
  string s;
  if (!slurp(f, s)) return def;
  return vaultos::chomp(s);
}

// ---------------------------------------------------------------- scan ----
// _scan ROOT REGEX GLOB path... — "relpath:line: text" for every line that
// matches (case-insensitive). CSS block comments are blanked first. Binary
// files (NUL before the first match, like grep -I) are skipped.

struct Pattern {
  std::regex re;
  vector<string> needles;  // lowercase literals; a matching line has one of them
};

string lower_s(const string& s) { return vaultos::lower(s); }

bool has_needle(const string& low, const Pattern& p) {
  for (auto& n : p.needles) if (low.find(n) != string::npos) return true;
  return false;
}

// Lowercase substring search without copying the file.
bool has_needle_ci(const string& t, const Pattern& p) {
  for (auto& n : p.needles) {
    auto it = std::search(t.begin(), t.end(), n.begin(), n.end(),
                          [](char a, char b) { return std::tolower(static_cast<unsigned char>(a)) == b; });
    if (it != t.end()) return true;
  }
  return false;
}

void scan_file(const string& root, const string& f, const Pattern& p, string& out) {
  // Binary files (icons, fonts) have a NUL in the first 32 KiB: decide from
  // that prefix and never read the rest, like grep -I.
  FILE* fp = fopen(f.c_str(), "rb");
  if (!fp) return;
  char head[32768];
  size_t hn = fread(head, 1, sizeof head, fp);
  if (memchr(head, '\0', hn)) { fclose(fp); return; }
  string t(head, hn);
  char buf[65536];
  size_t r;
  while ((r = fread(buf, 1, sizeof buf, fp)) > 0) t.append(buf, r);
  fclose(fp);
  if (!has_needle_ci(t, p)) return;
  size_t nul = t.find('\0');
  // grep -I: first matching line in the raw text decides
  if (nul != string::npos) {
    if (nul < 32768) return;
    size_t start = 0, first = string::npos;
    while (start <= t.size()) {
      size_t e = t.find('\n', start);
      string l = t.substr(start, e == string::npos ? string::npos : e - start);
      if (has_needle(lower_s(l), p) && std::regex_search(l, p.re)) { first = start; break; }
      if (e == string::npos) break;
      start = e + 1;
    }
    if (first == string::npos || nul < first) return;
  }
  if (vaultos::ends_with(f, ".css")) {
    // s{/\*.*?\*/}{newlines only}gs
    string o;
    size_t i = 0;
    while (i < t.size()) {
      size_t b = t.find("/*", i);
      if (b == string::npos) { o.append(t, i, string::npos); break; }
      size_t e = t.find("*/", b + 2);
      if (e == string::npos) { o.append(t, i, string::npos); break; }
      o.append(t, i, b - i);
      for (size_t k = b; k < e + 2; ++k) if (t[k] == '\n') o += '\n';
      i = e + 2;
    }
    t.swap(o);
  }
  string rel = f;
  if (starts_with(rel, root + "/")) rel = rel.substr(root.size() + 1);
  int n = 0;
  for (auto& l : vaultos::split(t, '\n')) {
    ++n;
    if (!has_needle(lower_s(l), p) || !std::regex_search(l, p.re)) continue;
    size_t k = 0;
    while (k < l.size() && (l[k] == ' ' || l[k] == '\t' || l[k] == '\n' || l[k] == '\r' || l[k] == '\f' || l[k] == '\v')) ++k;
    out += rel + ":" + std::to_string(n) + ": " + l.substr(k, 110) + "\n";
  }
}

string scan(const string& root, const Pattern& p, const string& glob, const vector<string>& paths) {
  string out;
  for (auto& base : paths) {
    if (!exists(base) && !vaultos::is_link(base)) continue;
    vector<string> files;
    walk(base, [&](const string& path, const string& name, bool d, bool r) {
      if (name == "__pycache__" || name == ".git") return false;
      (void)d;
      if (!r) return true;
      if (fnmatch(glob.c_str(), name.c_str(), 0) != 0) return true;
      if (vaultos::ends_with(name, ".md") || vaultos::ends_with(name, ".bak") || contains(name, ".bak-") ||
          vaultos::ends_with(name, "~"))
        return true;
      if (fnmatch("*.bak-*", name.c_str(), 0) == 0) return true;
      files.push_back(path);
      return true;
    });
    for (auto& f : files) scan_file(root, f, p, out);
  }
  return vaultos::chomp(out);
}

// Patterns are split so this file never matches its own checks.
const string kHexA = "33FF" "6A", kHexB = "44FF" "3D";
Pattern banned_hex() {
  return {std::regex("(#|0x)(" + kHexA + "|" + kHexB + ")|rgba?\\(\\s*(51\\s*,\\s*255\\s*,\\s*106|68\\s*,\\s*255\\s*,\\s*61)\\b",
                     std::regex::icase),
          {lower_s(kHexA), lower_s(kHexB), "rgb"}};
}
Pattern important() { return {std::regex(string("!\\s*import") + "ant", std::regex::icase), {"!"}}; }
Pattern css_junk() {
  return {std::regex(string("text-trans") + "form|:(before|after)\\b|-GtkNote" + "book-", std::regex::icase),
          {string("text-trans") + "form", ":before", ":after", string("-gtknote") + "book-"}};
}
Pattern sb_none() {
  return {std::regex(string("ScrollingBar") + "=NONE|TERMINAL_SCROLLBAR_" + "NONE", std::regex::icase),
          {string("scrollingbar") + "=none", string("terminal_scrollbar_") + "none"}};
}

// ------------------------------------------------------------ dir diff ----
// _dir_diff A B [extra -x...]: `diff -rq -x ... A B | sed "s|A/||g; s|B/||g"`

bool excluded(const string& name, const vector<string>& ex) {
  for (auto& x : ex) if (fnmatch(x.c_str(), name.c_str(), 0) == 0) return true;
  return false;
}

const char* type_name(const string& p) {
  struct stat st;
  if (stat(p.c_str(), &st) != 0) return "unknown";
  if (S_ISDIR(st.st_mode)) return "directory";
  if (S_ISREG(st.st_mode)) return st.st_size == 0 ? "regular empty file" : "regular file";
  if (S_ISFIFO(st.st_mode)) return "fifo";
  if (S_ISCHR(st.st_mode)) return "character special file";
  if (S_ISBLK(st.st_mode)) return "block special file";
  if (S_ISSOCK(st.st_mode)) return "socket";
  return "weird file";
}

void diff_rq(const string& a, const string& b, const vector<string>& ex, string& out) {
  vector<string> na, nb;
  for (auto& n : readdir_names(a)) if (!excluded(n, ex)) na.push_back(n);
  for (auto& n : readdir_names(b)) if (!excluded(n, ex)) nb.push_back(n);
  sort_coll(na);
  sort_coll(nb);
  size_t i = 0, j = 0;
  while (i < na.size() || j < nb.size()) {
    int c = i >= na.size() ? 1 : j >= nb.size() ? -1 : coll(na[i], nb[j]);
    if (c < 0) { out += "Only in " + a + ": " + na[i] + "\n"; ++i; continue; }
    if (c > 0) { out += "Only in " + b + ": " + nb[j] + "\n"; ++j; continue; }
    string pa = a + "/" + na[i], pb = b + "/" + nb[j];
    ++i; ++j;
    bool da = is_dir(pa), db = is_dir(pb);
    if (da && db) { diff_rq(pa, pb, ex, out); continue; }
    bool ra = is_reg(pa), rb = is_reg(pb);
    if (ra && rb) {
      if (!cmp_s(pa, pb)) out += "Files " + pa + " and " + pb + " differ\n";
      continue;
    }
    if (da != db || ra != rb)
      out += string("File ") + pa + " is a " + type_name(pa) + " while file " + pb + " is a " + type_name(pb) + "\n";
  }
}

void replace_all(string& s, const string& from, const string& to) {
  if (from.empty()) return;
  size_t p = 0;
  while ((p = s.find(from, p)) != string::npos) { s.replace(p, from.size(), to); p += to.size(); }
}

string dir_diff(const string& a, const string& b, vector<string> extra = {}) {
  vector<string> ex = {"README.md", "*.py", "__pycache__", "*.bak", "*.bak-*"};
  ex.insert(ex.end(), extra.begin(), extra.end());
  string out;
  if (!is_dir(a) || !is_dir(b)) return "";
  diff_rq(a, b, ex, out);
  replace_all(out, a + "/", "");
  replace_all(out, b + "/", "");
  return vaultos::chomp(out);
}

// _xpm_class: hexsym | symonly | mixed | none
string xpm_class(const string& f) {
  static const std::regex none_re(" c [Nn]one"), hx_re(" c #[0-9A-Fa-f]+"), sy_re(" s [A-Za-z_0-9]+");
  bool hdr = false;
  long n = 0;
  int tot = 0, both = 0, so = 0;
  for (auto& l : vaultos::split(slurp(f), '\n')) {
    if (l.empty() || l[0] != '"') continue;
    if (!hdr) {
      auto w = vaultos::words(l.substr(1));
      n = w.size() >= 3 ? std::strtol(w[2].c_str(), nullptr, 10) : 0;
      hdr = true;
      continue;
    }
    if (n > 0) {
      --n;
      if (std::regex_search(l, none_re)) continue;
      ++tot;
      bool hx = std::regex_search(l, hx_re), sy = std::regex_search(l, sy_re);
      if (hx && sy) ++both;
      else if (sy && !hx) ++so;
    }
  }
  if (tot == 0) return "none";
  if (both == tot) return "hexsym";
  if (so == tot) return "symonly";
  return "mixed";
}

// ---------------------------------------------------------------- lint ----

void lint_repo(const string& R) {
  string hits;
  vector<string> ship, legacy;
  for (const char* p : {"themes/Vault.OS", "themes/Vault.OS-Reduced", "source", "bin", "icons/Vault.OS", "overlay",
                        "iso/airootfs", "tokens.css", "tokens-reduced.css", "install.sh", "config/gtk-3.0",
                        "config/gtk-4.0", "config/gtkrc-2.0", "config/xfce4", "config/fallout-nv",
                        "config/environment.d", "extras/panel", "extras/lightdm", "extras/dock"})
    if (exists(R + "/" + p)) ship.push_back(R + "/" + p);
  for (const char* p : {"themes/PipBoy-NV", "icons/PipBoy-Dock", "config/pipboy", "config/Kvantum/PipBoy-NV",
                        "config/vscode", "config/discord", "config/firefox", "config/chromium"})
    if (exists(R + "/" + p)) legacy.push_back(R + "/" + p);
  Pattern hex = banned_hex();
  hits = scan(R, hex, "*", ship);
  if (hits.empty()) {
    chk("OK", "palette", "no banned phosphor hexes (" + kHexA + "/" + kHexB + ") in Vault.OS trees");
  } else {
    chk("FAIL", "palette", "banned phosphor hex in shipped Vault.OS files (canon 1AFF6B, Reduced 66FF9C):");
    chk_list(hits, 12);
  }
  if (!legacy.empty()) {
    vector<string> files;
    string raw = scan(R, hex, "*", legacy);
    if (!raw.empty())
      for (auto& l : vaultos::split(raw, '\n')) files.push_back(l.substr(0, l.find(':')));
    // sort -u: strcoll order, lines that collate equal are one
    sort_coll(files);
    vector<string> uniq;
    for (auto& f : files) if (uniq.empty() || strcoll(uniq.back().c_str(), f.c_str()) != 0) uniq.push_back(f);
    if (!uniq.empty()) {
      chk("WARN", "palette-old", "legacy PipBoy-NV app themes still carry banned hexes (" + std::to_string(uniq.size()) + " files)");
      chk_list(join(uniq, "\n"), 8);
    } else {
      chk("OK", "palette-old", "legacy PipBoy-NV app themes free of banned phosphor colours");
    }
  }

  vector<string> gtkcss;
  for (const char* p : {"themes/Vault.OS", "themes/Vault.OS-Reduced", "source/gtk-2.0", "source/gtk-3.0",
                        "source/gtk-3.20", "source/gtk-reduced/gtk-3.0", "source/gtk-reduced/gtk-3.20",
                        "source/gtk-overlay", "source/lock", "source/lightdm", "source/xfce4-notifyd",
                        "source/xfce4-panel", "source/xfce4-terminal", "config/gtk-3.0", "config/gtk-4.0"})
    if (exists(R + "/" + p)) gtkcss.push_back(R + "/" + p);
  hits = scan(R, important(), "*.css", gtkcss);
  if (hits.empty()) chk("OK", "gtk-important", "no !-important in GTK css");
  else { chk("FAIL", "gtk-important", "GTK CssProvider treats !-important as junk:"); chk_list(hits, 12); }
  hits = scan(R, css_junk(), "*.css", gtkcss);
  if (hits.empty()) chk("OK", "gtk-webcss", "no text-transform / :before / :after / -GtkNotebook-* in GTK css");
  else { chk("FAIL", "gtk-webcss", "web-only CSS in GTK themes (CssProvider parse errors):"); chk_list(hits, 12); }

  vector<string> miss;
  for (const char* pair : {"themes/Vault.OS", "themes/Vault.OS-Reduced", "source", "source/gtk-reduced"}) {
    if (!is_dir(R + "/" + pair)) continue;
    if (!is_reg(R + "/" + pair + "/gtk-3.0/gtk.css")) miss.push_back(string(pair) + "/gtk-3.0/gtk.css");
    if (!is_reg(R + "/" + pair + "/gtk-3.20/gtk.css")) miss.push_back(string(pair) + "/gtk-3.20/gtk.css");
  }
  if (!miss.empty()) chk("FAIL", "gtk-dirs", "missing: " + join(miss, " "));
  else chk("OK", "gtk-dirs", "gtk-3.0 + gtk-3.20 in both packs (themes + source)");

  string out;
  for (auto pr : vector<std::pair<string, string>>{{"source/gtk-3.0", "themes/Vault.OS/gtk-3.0"},
                                                   {"source/gtk-3.20", "themes/Vault.OS/gtk-3.20"},
                                                   {"source/gtk-reduced/gtk-3.0", "themes/Vault.OS-Reduced/gtk-3.0"},
                                                   {"source/gtk-reduced/gtk-3.20", "themes/Vault.OS-Reduced/gtk-3.20"}}) {
    string src = R + "/" + pr.first, dst = R + "/" + pr.second;
    if (!is_dir(src) || !is_dir(dst)) continue;
    for (auto& f : glob_dir(src, "*.css")) {
      if (!is_reg(f)) continue;
      string base = f.substr(f.rfind('/') + 1);
      string d = dst + "/" + base;
      if (!is_reg(d)) continue;
      if (!cmp_s(f, d)) out += pr.first + "/" + base + " ≠ " + pr.second + "/" + base + "\n";
    }
  }
  if (out.empty()) chk("OK", "gtk-sync", "source/ ≡ themes/ for shared GTK css");
  else { chk("WARN", "gtk-sync", "source/ and themes/ GTK css drifted (GTK-02 / HUD-04):"); chk_list(out, 12, false); }

  for (auto t : vector<vector<string>>{{"source/xfwm4", "themes/Vault.OS/xfwm4", "CANON"},
                                       {"source/xfwm4-reduced", "themes/Vault.OS-Reduced/xfwm4", "Reduced"}}) {
    const string &src = t[0], &dst = t[1], label = "xfwm-" + t[2];
    if (!is_dir(R + "/" + src) || !is_dir(R + "/" + dst)) {
      chk("SKIP", label, src + " or " + dst + " not in repo");
      continue;
    }
    out = dir_diff(R + "/" + src, R + "/" + dst);
    if (out.empty()) chk("OK", label, src + " ≡ " + dst);
    else { chk("FAIL", label, src + " and " + dst + " differ (replace the whole dir):"); chk_list(out, 10); }
    if (!is_reg(R + "/" + dst + "/themerc")) chk("FAIL", label, dst + "/themerc missing");
    std::map<string, int> n;
    vector<string> odd;
    for (auto& x : glob_dir(R + "/" + dst, "*.xpm")) {
      if (!is_reg(x)) continue;
      string cls = xpm_class(x);
      ++n[cls];
      if (cls != "hexsym") odd.push_back(x.substr(x.rfind('/') + 1) + "(" + cls + ")");
    }
    string classes;
    for (const char* c : {"hexsym", "symonly", "mixed", "none"})  // bash assoc-array walk order
      if (n.count(c)) classes += string(c) + "=" + std::to_string(n[c]) + " ";
    if (!classes.empty()) classes.pop_back();
    if (n.size() > 1 || n.count("mixed")) {
      chk("FAIL", label, "mixed XPM tree (" + classes + "): replace the whole dir");
      chk_list(join(odd, "\n"), 8);
    } else if (n.size() == 1) {
      chk("OK", label, "XPMs one color style (" + classes + ")");
    }
  }

  vector<string> tfiles;
  for (auto& f : glob_dir(R + "/source/xfce4-terminal", "terminalrc*")) if (is_reg(f)) tfiles.push_back(f);
  for (auto& f : glob_dir(R + "/config/xfce4/terminal", "terminalrc*")) if (is_reg(f)) tfiles.push_back(f);
  if (tfiles.empty()) {
    chk("SKIP", "terminal", "no terminalrc* in repo");
  } else {
    vector<string> paths = tfiles;
    paths.push_back(R + "/bin/vaultos-terminal-phosphor");
    paths.push_back(R + "/bin/vault-os");
    string bad = scan(R, sb_none(), "*", paths), missing;
    for (auto& f : tfiles)
      if (!grep_x(f, "ScrollingBar=TERMINAL_SCROLLBAR_RIGHT")) missing += f.substr(R.size() + 1) + " ";
    if (!bad.empty()) { chk("FAIL", "terminal", "scrollbar forced off:"); chk_list(bad, 8); }
    if (!missing.empty()) chk("FAIL", "terminal", "no ScrollingBar=TERMINAL_SCROLLBAR_RIGHT in: " + missing);
    string tp = R + "/bin/vaultos-terminal-phosphor";
    if (is_reg(tp) && !contains(slurp(tp), "TERMINAL_SCROLLBAR_RIGHT"))
      chk("WARN", "terminal", "vaultos-terminal-phosphor does not pin TERMINAL_SCROLLBAR_RIGHT");
    if (bad.empty() && missing.empty())
      chk("OK", "terminal", std::to_string(tfiles.size()) + " terminalrc* keep TERMINAL_SCROLLBAR_RIGHT; none forced off");
  }

  string sd = R + "/source/xfce4-screensaver/vaultos-arch-spin.desktop", wrap = "/usr/lib/xfce4-screensaver/vaultos-arch-spin";
  static const std::regex hidden_re("^Hidden=");
  if (is_reg(sd)) {
    out.clear();
    if (grep_re(sd, hidden_re)) out += "Hidden= present; ";
    if (!grep_x(sd, "Exec=" + wrap)) out += "Exec≠" + wrap + "; ";
    if (!grep_x(sd, "TryExec=" + wrap)) out += "TryExec≠" + wrap + "; ";
    if (out.empty()) chk("OK", "saver-src", "vaultos-arch-spin.desktop: no Hidden=, Exec/TryExec → " + wrap);
    else chk("FAIL", "saver-src", "source/xfce4-screensaver/vaultos-arch-spin.desktop: " + out);
  } else {
    chk("SKIP", "saver-src", "source/xfce4-screensaver/vaultos-arch-spin.desktop not in repo");
  }
  if (contains(slurp(R + "/bin/vault-os"), "saver_want=\"screensavers-vaultos-arch-spin\""))
    chk("OK", "saver-id", "ensure-theme pins screensavers-vaultos-arch-spin");
  else
    chk("FAIL", "saver-id", "bin/vault-os ensure-theme does not pin screensavers-vaultos-arch-spin");
  {
    static const std::regex fl_re("^Exec=.*vaultos");
    out.clear();
    walk(R, [&](const string& path, const string& name, bool, bool r) {
      if (path == R + "/.git") return false;
      if (r && fnmatch("xfce-floaters.desktop*", name.c_str(), 0) == 0 && grep_re(path, fl_re))
        out += path.substr(R.size() + 1) + "\n";
      return true;
    });
    out = vaultos::chomp(out);
    if (!out.empty()) { chk("FAIL", "saver-floaters", "repo ships a hijacked xfce-floaters.desktop:"); chk_list(out, 4); }
    else chk("OK", "saver-floaters", "no xfce-floaters.desktop hijack shipped");
  }

  string autos = R + "/bin/vaultos-spin-arch-autostart";
  if (is_reg(autos)) {
    string tmpl = env_or("TMPDIR", "/tmp") + "/vault-os-lint.XXXXXX";
    vector<char> b(tmpl.begin(), tmpl.end());
    b.push_back('\0');
    string tmp = mkdtemp(b.data()) ? b.data() : "";
    string got_def, got_full, got_junk;
    if (!tmp.empty()) {
      mkdir((tmp + "/.local").c_str(), 0755);
      mkdir((tmp + "/.local/bin").c_str(), 0755);
      mkdir((tmp + "/.config").c_str(), 0755);
      mkdir((tmp + "/.config/Vault.OS").c_str(), 0755);
      string fake = tmp + "/.local/bin/vaultos-spin-arch";
      if (FILE* f = fopen(fake.c_str(), "w")) { fputs("#!/bin/sh\necho \"$*\"\n", f); fclose(f); }
      chmod(fake.c_str(), 0755);
      auto spin_run = [&]() {
        return vaultos::chomp(vaultos::capture(
            {"env", "-i", "HOME=" + tmp, "XDG_CONFIG_HOME=" + tmp + "/.config", "PATH=/usr/bin:/bin", "bash", autos}));
      };
      got_def = spin_run();
      auto put = [&](const char* v) {
        if (FILE* f = fopen((tmp + "/.config/Vault.OS/desktop-spin").c_str(), "w")) { fputs(v, f); fclose(f); }
      };
      put("full\n");
      got_full = spin_run();
      put("bogus\n");
      got_junk = spin_run();
      vaultos::run({"rm", "-rf", tmp});
    }
    if ((got_def + got_full).empty())
      chk("WARN", "spin-default", "could not exercise vaultos-spin-arch-autostart (no vaultos-spin-arch call)");
    else if (contains(got_def, "--full") || contains(got_junk, "--full"))
      chk("FAIL", "spin-default", "autostart spins without desktop-spin=full (default='" + got_def + "' junk='" + got_junk + "')");
    else if (!contains(got_full, "--full"))
      chk("WARN", "spin-default", "desktop-spin=full does not pass --full (got '" + got_full + "')");
    else
      chk("OK", "spin-default", "static by default ('" + got_def + "'); --full only with desktop-spin=full");
  } else {
    chk("SKIP", "spin-default", "bin/vaultos-spin-arch-autostart not in repo");
  }
  {
    static const std::regex full_re("^Exec=.*vaultos-spin-arch( |$).*--full");
    out.clear();
    walk(R, [&](const string& path, const string& name, bool d, bool r) {
      if (d && name == ".git" && path != R) return false;
      if (r && fnmatch("*.desktop", name.c_str(), 0) == 0 && grep_re(path, full_re))
        out += path.substr(R.size() + 1) + "\n";
      return true;
    });
    out = vaultos::chomp(out);
    if (!out.empty()) { chk("FAIL", "spin-autostart", "hard --full Exec (use vaultos-spin-arch-autostart):"); chk_list(out, 4); }
    else chk("OK", "spin-autostart", "no shipped .desktop hard-codes vaultos-spin-arch --full");
  }

  if (is_reg(R + "/ERRORS.md") && is_reg(R + "/source/ERRORS.md")) {
    if (cmp_s(R + "/ERRORS.md", R + "/source/ERRORS.md")) chk("OK", "errors-sync", "ERRORS.md ≡ source/ERRORS.md");
    else chk("FAIL", "errors-sync", "ERRORS.md and source/ERRORS.md differ (keep in sync)");
  } else {
    chk("SKIP", "errors-sync", "ERRORS.md or source/ERRORS.md missing");
  }
  for (auto pr : vector<std::pair<string, string>>{
           {"DESIGN.md", "design-sync"}, {"tokens.css", "tokens-sync"}, {"tokens-reduced.css", "tokensR-sync"}}) {
    if (!is_reg(R + "/" + pr.first) || !is_reg(R + "/source/" + pr.first)) continue;
    if (cmp_s(R + "/" + pr.first, R + "/source/" + pr.first)) chk("OK", pr.second, pr.first + " ≡ source/" + pr.first);
    else chk("WARN", pr.second, pr.first + " and source/" + pr.first + " differ");
  }

  out.clear();
  vector<string> sh = glob_dir(R + "/bin", "*");
  sh.push_back(R + "/install.sh");
  sh.push_back(R + "/source/xfce4-screensaver/install-system.sh");
  static const std::regex shebang("^#!.*\\b(bash|sh)\\b");
  for (auto& f : sh) {
    if (!is_reg(f)) continue;
    if (!std::regex_search(first_line(slurp(f)), shebang)) continue;
    vaultos::RunOpts q;
    q.quiet_out = q.quiet_err = q.null_in = true;
    if (vaultos::run({"bash", "-n", f}, q) != 0) out += f.substr(R.size() + 1) + " ";
  }
  if (out.empty()) chk("OK", "shell-syntax", "bash -n clean on bin/ + installers");
  else chk("FAIL", "shell-syntax", "bash -n fails: " + out);
}

bool summary(const string& what) {
  emit("\n" + what + ": " + std::to_string(g_fail) + " FAIL, " + std::to_string(g_warn) + " WARN\n");
  return g_fail == 0;
}

// --------------------------------------------------------------- live ----

string xq_get(const string& ch, const string& prop) {
  if (vaultos::have("xfconf-query")) return vaultos::capture({"xfconf-query", "-c", ch, "-p", prop});
  const char* xq = std::getenv("VAULTOS_XQ");
  string x = xq ? xq : vaultos::find_in_path("vaultos-xq");
  if (!x.empty() && vaultos::is_exec_file(x)) return vaultos::capture({x, "get", ch, prop});
  return "\n";
}
string xq1(const string& ch, const string& prop) { return first_line(vaultos::chomp(xq_get(ch, prop))); }

// pgrep -x NAME: pids whose comm is NAME, ascending.
vector<long> pgrep_x(const string& name) {
  vector<long> pids;
  long self = getpid();
  for (auto& n : readdir_names("/proc")) {
    if (n.empty() || !std::all_of(n.begin(), n.end(), ::isdigit)) continue;
    long pid = std::atol(n.c_str());
    if (pid == self) continue;
    if (vaultos::chomp(slurp("/proc/" + n + "/comm")) == name.substr(0, 15)) pids.push_back(pid);
  }
  std::sort(pids.begin(), pids.end());
  return pids;
}

// pgrep -af PATTERN-literal: command lines that contain NEEDLE.
vector<string> pgrep_af(const string& needle) {
  vector<string> out;
  long self = getpid();
  for (auto& n : readdir_names("/proc")) {
    if (n.empty() || !std::all_of(n.begin(), n.end(), ::isdigit)) continue;
    if (std::atol(n.c_str()) == self) continue;
    string c = slurp("/proc/" + n + "/cmdline");
    while (!c.empty() && c.back() == '\0') c.pop_back();
    std::replace(c.begin(), c.end(), '\0', ' ');
    if (contains(c, needle)) out.push_back(n + " " + c);
  }
  return out;
}

double awk_num(const string& s) {  // awk "v+0"
  const char* p = s.c_str();
  while (*p == ' ' || *p == '\t' || *p == '\n') ++p;
  if ((p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) || ((p[0] == '+' || p[0] == '-') && p[1] == '0' && (p[2] == 'x' || p[2] == 'X')))
    return 0;
  string t(p);
  if (starts_with(lower_s(t), "inf") || starts_with(lower_s(t), "nan") || starts_with(lower_s(t), "+inf") ||
      starts_with(lower_s(t), "-inf") || starts_with(lower_s(t), "+nan") || starts_with(lower_s(t), "-nan"))
    return 0;
  return std::strtod(p, nullptr);
}
bool panel_num_ok(const string& v, double m) { return awk_num(v.empty() ? "0" : v) >= m; }

string cfg(const string& k) { auto it = CONF.find(k); return it == CONF.end() ? "" : it->second; }

void load_config() {
  CONF = {{"THEME_NAME", "Vault.OS"}, {"ICON_THEME", "Vault.OS"}, {"WM_THEME", "Vault.OS"},
          {"CURSOR_THEME", "Vault.OS"}, {"INTRO_ENABLED", "0"},
          {"INTRO_FILE", HOME + "/.local/share/fallout-nv/boot-intro.mp4"}};
  string rt = env_or("XDG_RUNTIME_DIR", "/run/user/" + std::to_string(getuid()));
  string conf = XDG_CFG + "/fallout-nv/vault-os.conf";
  string s;
  if (!slurp(conf, s)) return;
  static const std::regex key_re("^[A-Za-z_][A-Za-z0-9_]*$"), comment("^[[:space:]]*#.*");
  for (auto& line : vaultos::lines(s)) {
    if (std::regex_match(line, comment)) continue;
    string nosp;
    for (char c : line) if (c != ' ') nosp += c;
    if (nosp.empty()) continue;
    size_t eq = line.find('=');
    string key = line.substr(0, eq), val = eq == string::npos ? line : line.substr(eq + 1);
    key.erase(std::remove(key.begin(), key.end(), ' '), key.end());
    if (!std::regex_match(key, key_re)) continue;
    replace_all(val, "$HOME", HOME);
    replace_all(val, "$XDG_RUNTIME_DIR", rt);
    CONF[key] = val;
  }
}

bool has_share_tech_mono() {
  if (is_reg(HOME + "/.local/share/fonts/ShareTechMono/ShareTechMono-Regular.ttf")) return true;
  if (is_reg(HOME + "/.local/share/fonts/pipboy/ShareTechMono-Regular.ttf")) return true;
  if (lower_s(vaultos::capture({"fc-list", ":", "family"})).find("share tech mono") != string::npos) return true;
  if (lower_s(vaultos::capture({"fc-list"})).find("sharetechmono") != string::npos) return true;
  return false;
}

int cmd_status() {
  int ec = 0;
  emit("vault-os " + VERSION + "\n───────────────\n");
  string t = xq1("xsettings", "/Net/ThemeName"), i = xq1("xsettings", "/Net/IconThemeName"), w = xq1("xfwm4", "/general/theme");
  emit("theme      " + t + " " + (t == cfg("THEME_NAME") ? "OK" : "DRIFT") + "\n");
  emit("icons      " + i + " " + (i == cfg("ICON_THEME") ? "OK" : "DRIFT") + "\n");
  emit("wm         " + w + " " + (w == cfg("WM_THEME") ? "OK" : "DRIFT") + "\n");
  auto panel = pgrep_x("xfce4-panel");
  if (!panel.empty()) emit("panel      running pid=" + std::to_string(panel[0]) + "\n");
  else { emit("panel      DEAD\n"); ec = 1; }
  string p1 = xq1("xfce4-panel", "/panels/panel-1/length"), p2 = xq1("xfce4-panel", "/panels/panel-2/length"),
         pos2 = xq1("xfce4-panel", "/panels/panel-2/position");
  emit("panel-1    length=" + p1 + "\n");
  emit("panel-2    length=" + p2 + " position=" + pos2 + "\n");
  if (!panel_num_ok(p2, 50)) { emit("panel-2    LENGTH_BAD\n"); ec = 1; }
  if (!contains(pos2, "x=")) { emit("panel-2    POSITION_INCOMPLETE\n"); ec = 1; }
  if (cfg("INTRO_ENABLED") == "1" && !is_reg(XDG_CFG + "/fallout-nv/skip-boot-intro")) {
    if (is_reg(cfg("INTRO_FILE")) || is_reg(HOME + "/.local/share/fallout-nv/FNVIntro-1080p-1m26s.mp4"))
      emit("intro      enabled (media OK)\n");
    else
      emit("intro      enabled (media missing)\n");
  } else {
    emit("intro      disabled\n");
  }
  if (is_dir(HOME + "/.themes/" + cfg("THEME_NAME"))) emit("theme_dir  OK\n"); else { emit("theme_dir  MISSING\n"); ec = 1; }
  if (is_dir(HOME + "/.local/share/icons/" + cfg("ICON_THEME")) || is_dir(HOME + "/.icons/" + cfg("ICON_THEME")))
    emit("icon_dir   OK\n");
  else { emit("icon_dir   MISSING\n"); ec = 1; }
  string wall_prop;
  for (auto& l : vaultos::lines(vaultos::capture({"xfconf-query", "-c", "xfce4-desktop", "-l"})))
    if (vaultos::ends_with(l, "last-image")) { wall_prop = l; break; }
  if (!wall_prop.empty()) {
    string wl = xq1("xfce4-desktop", wall_prop);
    bool ok = is_reg(wl);
    emit(string("wallpaper  ") + (ok ? "OK" : "MISSING") + " " + wl.substr(wl.rfind('/') == string::npos ? 0 : wl.rfind('/') + 1) + "\n");
  } else {
    emit("wallpaper  unset\n");
  }
  string cur = xq1("xsettings", "/Gtk/CursorThemeName");
  if (cur == cfg("CURSOR_THEME")) emit("cursor     " + cur + " OK\n");
  else emit("cursor     " + (cur.empty() ? string("none") : cur) + " DRIFT (want " + cfg("CURSOR_THEME") + ")\n");
  string nt = xq1("xfce4-notifyd", "/theme");
  emit("notify     " + (nt.empty() ? string("default") : nt) + "\n");
  emit(string("font       Share Tech Mono ") + (has_share_tech_mono() ? "OK" : "MISSING") + "\n");
  string ct = cfg("CURSOR_THEME").empty() ? "Vault.OS" : cfg("CURSOR_THEME");
  if (is_dir(HOME + "/.icons/" + ct + "/cursors") || is_dir(HOME + "/.local/share/icons/" + ct + "/cursors"))
    emit("cursor_dir OK\n");
  else { emit("cursor_dir MISSING\n"); ec = 1; }
  emit(string("picom      ") + (pgrep_x("picom").empty() ? "not running" : "running") + "\n");
  if (!pgrep_x("xfdesktop").empty()) emit("xfdesktop  running\n"); else { emit("xfdesktop  DEAD\n"); ec = 1; }
  emit(string("notify_thm ") + (is_dir(HOME + "/.themes/" + cfg("THEME_NAME") + "/xfce-notify-4.0") ? "OK" : "MISSING") + "\n");
  vector<string> ldm;
  for (auto& l : vaultos::lines(slurp("/etc/lightdm/lightdm-gtk-greeter.conf")))
    if (starts_with(l, "theme-name=")) { auto f = vaultos::split(l, '='); ldm.push_back(f.size() > 1 ? f[1] : ""); }
  string lt = join(ldm, "\n");
  if (lt == "Vault.OS" || lt == "Vault.OS-Reduced") emit("greeter    " + lt + " conf\n");
  else emit("greeter    conf missing\n");
  if (is_dir("/usr/share/themes/Vault.OS/gtk-3.0") && is_reg("/usr/share/backgrounds/Vault.OS/vault-111.png"))
    emit("greeter_sys OK\n");
  else
    emit("greeter_sys MISSING (pkexec install)\n");
  return ec;
}

string tilde(const string& s) { return starts_with(s, HOME) ? "~" + s.substr(HOME.size()) : s; }

void doctor_live(const string& R) {
  string out;
  string inst = HOME + "/.local/bin/vault-os";
  if (vaultos::path_exists(inst) && exists(inst)) {
    if (!R.empty() && realpath_s(inst) == realpath_s(R + "/bin/vault-os")) {
      chk("OK", "cli", "~/.local/bin/vault-os → this checkout");
    } else {
      string iv;
      for (auto& l : vaultos::split(slurp(inst), '\n'))
        if (starts_with(l, "readonly VERSION=")) { auto f = vaultos::split(l, '"'); iv = f.size() > 1 ? f[1] : ""; break; }
      if (iv == VERSION) chk("OK", "cli", "~/.local/bin/vault-os " + iv + " → " + realpath_s(inst));
      else chk("WARN", "cli", "~/.local/bin/vault-os " + (iv.empty() ? string("?") : iv) + " ≠ this " + VERSION + " (" + realpath_s(inst) + ")");
    }
  } else {
    chk("WARN", "cli", "~/.local/bin/vault-os missing (vault-os install)");
  }

  vector<string> livep;
  for (const char* t : {"Vault.OS", "Vault.OS-Reduced"}) if (is_dir(HOME + "/.themes/" + t)) livep.push_back(HOME + "/.themes/" + t);
  if (is_reg(HOME + "/.config/gtk-3.0/gtk.css")) livep.push_back(HOME + "/.config/gtk-3.0/gtk.css");
  if (is_reg(HOME + "/.config/gtk-4.0/gtk.css")) livep.push_back(HOME + "/.config/gtk-4.0/gtk.css");
  string a = scan(HOME, banned_hex(), "*", livep), b = scan(HOME, important(), "*.css", livep);
  out = vaultos::chomp((a.empty() ? "" : a + "\n") + b);
  if (out.empty()) chk("OK", "live-gtk", "no banned hexes / !-important in ~/.themes Vault.OS* + GTK overlays");
  else { chk("FAIL", "live-gtk", "live theme/overlay breaks the palette or CssProvider rules:"); chk_list(out, 10); }
  out.clear();
  for (const char* t : {"Vault.OS", "Vault.OS-Reduced"}) {
    string d = HOME + "/.themes/" + t;
    if (!is_dir(d)) { out += string(t) + "(not installed) "; continue; }
    if (!is_reg(d + "/gtk-3.0/gtk.css")) out += string(t) + "/gtk-3.0 ";
    if (!is_reg(d + "/gtk-3.20/gtk.css")) out += string(t) + "/gtk-3.20 ";
  }
  if (out.empty()) chk("OK", "live-gtk-dirs", "~/.themes packs ship gtk-3.0 + gtk-3.20");
  else chk("FAIL", "live-gtk-dirs", "missing: " + out);
  string ov = HOME + "/.config/gtk-3.0/gtk.css";
  if (is_reg(ov)) {
    static const std::regex cmt("^[[:space:]]*/\\*.*");
    bool spin = false;
    for (auto& l : vaultos::split(slurp(ov), '\n'))
      if (!std::regex_match(l, cmt) && contains(lower_s(l), "spinner")) spin = true;
    if (spin) chk("WARN", "gtk-overlay", "~/.config/gtk-3.0/gtk.css carries a spinner override (HUD @import only)");
    else chk("OK", "gtk-overlay", "~/.config/gtk-3.0/gtk.css is HUD import only");
  }

  if (!R.empty()) {
    for (auto t : vector<vector<string>>{{"themes/Vault.OS/xfwm4", "Vault.OS/xfwm4", "xfwm"},
                                         {"themes/Vault.OS-Reduced/xfwm4", "Vault.OS-Reduced/xfwm4", "xfwm-R"},
                                         {"themes/Vault.OS/gtk-3.0", "Vault.OS/gtk-3.0", "gtk3"},
                                         {"themes/Vault.OS/gtk-3.20", "Vault.OS/gtk-3.20", "gtk320"},
                                         {"themes/Vault.OS-Reduced/gtk-3.0", "Vault.OS-Reduced/gtk-3.0", "gtk3-R"},
                                         {"themes/Vault.OS-Reduced/gtk-3.20", "Vault.OS-Reduced/gtk-3.20", "gtk320-R"}}) {
      if (!is_dir(R + "/" + t[0]) || !is_dir(HOME + "/.themes/" + t[1])) continue;
      out = dir_diff(R + "/" + t[0], HOME + "/.themes/" + t[1], {"terminal.css"});
      if (out.empty()) chk("OK", "live-" + t[2], "~/.themes/" + t[1] + " ≡ repo");
      else { chk("WARN", "live-" + t[2], "~/.themes/" + t[1] + " differs from repo " + t[0] + " (vault-os install to sync):"); chk_list(out, 6); }
    }
  }

  string pm = cat_or(XDG_CFG + "/Vault.OS/terminal-phosphor", "reduced");
  if (pm != "full" && pm != "reduced" && pm != "clear") pm = "reduced";
  string tsrc = R.empty() ? "" : R + "/source/xfce4-terminal/terminal." + pm + ".css";
  if (!tsrc.empty() && is_reg(tsrc)) {
    out.clear();
    for (const char* t : {"gtk-3.0", "gtk-3.20"}) {
      string f = HOME + "/.themes/Vault.OS/" + t + "/terminal.css";
      if (!is_reg(f)) continue;
      if (!cmp_s(f, tsrc)) out += string(t) + " ";
    }
    if (out.empty()) chk("OK", "live-term-css", "~/.themes/Vault.OS terminal.css = phosphor dial '" + pm + "'");
    else chk("WARN", "live-term-css", "terminal.css in " + out + "≠ source terminal." + pm + ".css (vaultos-terminal-phosphor " + pm + ")");
  }

  string trc = HOME + "/.config/xfce4/terminal/terminalrc";
  static const std::regex sbn(string("ScrollingBar") + "=NONE|TERMINAL_SCROLLBAR_" + "NONE");
  if (is_reg(trc) && grep_re(trc, sbn)) chk("FAIL", "live-term", "terminalrc forces the scrollbar off");
  string sb = xq1("xfce4-terminal", "/scrolling-bar");
  if (sb == "TERMINAL_SCROLLBAR_RIGHT") chk("OK", "live-term", "xfce4-terminal /scrolling-bar = RIGHT");
  else if (sb.empty()) {
    if (is_reg(trc) && grep_x(trc, "ScrollingBar=TERMINAL_SCROLLBAR_RIGHT"))
      chk("OK", "live-term", "terminalrc ScrollingBar=TERMINAL_SCROLLBAR_RIGHT (xfconf unset)");
    else
      chk("WARN", "live-term", "scrollbar not pinned to RIGHT (xfconf unset)");
  } else {
    chk("FAIL", "live-term", "xfce4-terminal /scrolling-bar = " + sb + " (want TERMINAL_SCROLLBAR_RIGHT)");
  }

  string sysd = "/usr/share/applications/screensavers/vaultos-arch-spin.desktop", wrap = "/usr/lib/xfce4-screensaver/vaultos-arch-spin";
  string saver = last_line(xq_get("xfce4-screensaver", "/saver/themes/list"));
  if (saver == "screensavers-vaultos-arch-spin") chk("OK", "live-saver", "theme = screensavers-vaultos-arch-spin");
  else chk("FAIL", "live-saver", "theme = '" + (saver.empty() ? string("unset") : saver) + "' (want screensavers-vaultos-arch-spin)");
  static const std::regex hidden_re("^Hidden=");
  if (is_reg(sysd)) {
    out.clear();
    if (grep_re(sysd, hidden_re)) out += "Hidden= present; ";
    if (!grep_x(sysd, "Exec=" + wrap)) out += "Exec≠" + wrap + "; ";
    if (!grep_x(sysd, "TryExec=" + wrap)) out += "TryExec≠" + wrap + "; ";
    if (out.empty()) chk("OK", "live-saver", "system desktop: no Hidden=, Exec/TryExec → " + wrap);
    else chk("FAIL", "live-saver", sysd + ": " + out + "(sudo: install-system.sh)");
  } else {
    chk("FAIL", "live-saver", sysd + " missing (sudo: source/xfce4-screensaver/install-system.sh)");
  }
  if (vaultos::is_exec_file(wrap)) {
    if (!R.empty() && is_reg(R + "/source/xfce4-screensaver/vaultos-arch-spin.wrapper") &&
        !cmp_s(wrap, R + "/source/xfce4-screensaver/vaultos-arch-spin.wrapper"))
      chk("WARN", "live-saver", wrap + " differs from source wrapper (sudo re-run install-system.sh to refresh)");
    else
      chk("OK", "live-saver", wrap + " present");
  } else {
    chk("FAIL", "live-saver", wrap + " missing or not executable (sudo: install-system.sh)");
  }
  string fl = "/usr/share/applications/screensavers/xfce-floaters.desktop";
  static const std::regex fl_re("^(Try)?Exec=.*vaultos");
  if (is_reg(fl) && grep_re(fl, fl_re))
    chk("FAIL", "live-saver", "stock xfce-floaters.desktop is hijacked (restore .vaultos-stock; needs sudo)");
  else if (is_reg(HOME + "/.local/share/applications/screensavers/xfce-floaters.desktop"))
    chk("FAIL", "live-saver", "user-local xfce-floaters.desktop override → (null) Exec; remove it");
  else
    chk("OK", "live-saver", "stock xfce-floaters.desktop untouched");

  string lc = xq1("xfce4-session", "/general/LockCommand");
  if (contains(lc, "xflock4")) chk("FAIL", "live-lock", "LockCommand = " + lc + " (never xflock4)");
  else if (lc.empty()) chk("WARN", "live-lock", "LockCommand unset (want vaultos-session-lock)");
  else chk("OK", "live-lock", "LockCommand = " + tilde(lc));

  string mode = cat_or(XDG_CFG + "/Vault.OS/desktop-spin", "reduced");
  bool found = false;
  static const std::regex ex_spin("^Exec=.*vaultos-spin-arch"), ex_full("^Exec=.*--full"),
      ex_auto("^Exec=.*vaultos-spin-arch-autostart");
  for (auto& f : glob_dir(XDG_CFG + "/autostart", "*.desktop")) {
    if (!is_reg(f) || !grep_re(f, ex_spin) || grep_x(f, "Hidden=true")) continue;
    found = true;
    if (grep_re(f, ex_full) || !grep_re(f, ex_auto)) {
      string ex;
      for (auto& l : vaultos::split(slurp(f), '\n')) if (starts_with(l, "Exec=")) { ex = l; break; }
      chk("FAIL", "live-spin", tilde(f) + ": " + ex + " (use vaultos-spin-arch-autostart)");
    } else {
      chk("OK", "live-spin", f.substr(f.rfind('/') + 1) + " → vaultos-spin-arch-autostart");
    }
  }
  if (!found) chk("WARN", "live-spin", "no enabled desktop Arch spin autostart");
  if (mode == "full") chk("OK", "spin-mode", "full (opt-in via ~/.config/Vault.OS/desktop-spin=full)");
  else if (mode == "off") chk("OK", "spin-mode", "off (desktop-spin=off)");
  else chk("OK", "spin-mode", "static (default)");
  if (mode != "full") {
    for (auto& l : pgrep_af("vaultos-spin-arch"))
      if (contains(l, "--instance desktop") && contains(l, "--full")) {
        chk("WARN", "spin-mode", "desktop spin running --full without desktop-spin=full (CPU on HD 630)");
        break;
      }
  }

  string gt = xq1("xsettings", "/Net/ThemeName"), wm = xq1("xfwm4", "/general/theme"), tn = cfg("THEME_NAME");
  if (gt == "Vault.OS-Reduced" || wm == "Vault.OS-Reduced" || tn == "Vault.OS-Reduced") {
    if (gt == "Vault.OS-Reduced" && wm == "Vault.OS-Reduced" && tn == "Vault.OS-Reduced")
      chk("OK", "reduced", "Reduced: GTK + xfwm + conf all Vault.OS-Reduced");
    else
      chk("WARN", "reduced", "Reduced mismatch: gtk=" + gt + " xfwm=" + wm + " conf=" + (tn.empty() ? string("?") : tn) + " (vault-os ensure-theme)");
  } else {
    chk("OK", "reduced", "CANON: gtk=" + (gt.empty() ? string("?") : gt) + " xfwm=" + (wm.empty() ? string("?") : wm) + " (Reduced not active)");
  }
}

string find_repo() {
  for (const string& c : {env_or("VAULT_OS_ROOT", ""), HOME + "/Projects/vault-os", HOME + "/Vault.OS"})
    if (!c.empty() && is_dir(c + "/themes/Vault.OS") && is_dir(c + "/source")) return c;
  return "";
}

string version_from(const string& R) {
  for (auto& l : vaultos::split(slurp(R + "/bin/vault-os"), '\n'))
    if (starts_with(l, "readonly VERSION=")) { auto f = vaultos::split(l, '"'); if (f.size() > 1) return f[1]; }
  return "?";
}

int usage(int rc) {
  fprintf(rc ? stderr : stdout, "usage: vaultos-doctor lint [PATH] | doctor | status  [--repo PATH] [--cli-version V]\n");
  return rc;
}

}  // namespace

int main(int argc, char** argv) {
  setlocale(LC_COLLATE, "");  // globs, diff -r and sort -u use strcoll
  setlocale(LC_CTYPE, "");
  HOME = env_or("HOME", "/");
  XDG_CFG = env_or("XDG_CONFIG_HOME", HOME + "/.config");
  string cmd, path, repo, ver;
  bool repo_set = false;
  for (int i = 1; i < argc; ++i) {
    string a = argv[i];
    if (a == "--repo" && i + 1 < argc) { repo = argv[++i]; repo_set = true; }
    else if (a == "--cli-version" && i + 1 < argc) ver = argv[++i];
    else if (a == "-h" || a == "--help") return usage(0);
    else if (cmd.empty()) cmd = a;
    else if (path.empty()) path = a;
    else return usage(2);
  }
  // Same session environment and PATH as bin/vault-os.
  if (!std::getenv("DISPLAY")) setenv("DISPLAY", ":0", 1);
  if (!std::getenv("XAUTHORITY")) setenv("XAUTHORITY", (HOME + "/.Xauthority").c_str(), 1);
  string rt = env_or("XDG_RUNTIME_DIR", "/run/user/" + std::to_string(getuid()));
  setenv("XDG_RUNTIME_DIR", rt.c_str(), 1);
  if (!std::getenv("DBUS_SESSION_BUS_ADDRESS")) setenv("DBUS_SESSION_BUS_ADDRESS", ("unix:path=" + rt + "/bus").c_str(), 1);
  setenv("PATH", (HOME + "/.local/bin:/usr/local/bin:/usr/bin:/bin:" + env_or("PATH", "")).c_str(), 1);

  if (cmd == "lint") {
    string R = path.empty() ? (repo_set ? repo : find_repo()) : path;
    if (R.empty()) { fprintf(stderr, "vault-os lint: no checkout found (pass a path)\n"); return 2; }
    string abs = realpath_s(R);
    if (abs.empty() || !is_dir(abs)) { fprintf(stderr, "vault-os lint: cd: %s: No such file or directory\n", R.c_str()); return 2; }
    // `cd "$R" && pwd` keeps symlinked components; realpath does not. Prefer
    // the logical path when it names the same directory.
    if (R[0] == '/' && realpath_s(R) == abs) abs = R;
    while (abs.size() > 1 && abs.back() == '/') abs.pop_back();
    if (!is_dir(abs + "/themes/Vault.OS")) { fprintf(stderr, "vault-os lint: %s is not a Vault.OS checkout\n", abs.c_str()); return 2; }
    emit("vault-os lint " + abs + "\n───────────────\n");
    lint_repo(abs);
    bool ok = summary("lint");
    flush_out();
    return ok ? 0 : 1;
  }
  if (cmd == "doctor" || cmd == "status") {
    if (!path.empty()) return usage(2);
    string R = repo_set ? repo : find_repo();
    VERSION = !ver.empty() ? ver : (R.empty() ? "?" : version_from(R));
    load_config();
    int ec = cmd_status() ? 1 : 0;
    if (cmd == "status") { flush_out(); return ec; }
    g_fail = g_warn = 0;
    emit("\nlive rules\n───────────────\n");
    doctor_live(R);
    emit("\nrepo lint " + (R.empty() ? string("(none)") : R) + "\n───────────────\n");
    if (!R.empty()) lint_repo(R);
    else chk("SKIP", "lint", "no Vault.OS checkout found (set VAULT_OS_ROOT)");
    if (!summary("doctor")) ec = 1;
    if (ec) emit("Unhealthy. Session drift: vault-os doctor --fix. Repo FAILs and sudo items above need a commit or a human.\n");
    flush_out();
    return ec;
  }
  return usage(2);
}

// vaultos-firstuser — Vault.OS first-boot wizard: machine + first login account.
// C++ port of overlay/libexec/vaultos-firstuser.sh, which stays the fallback
// and the reference: same answers file, same files written, same stamps, same
// log, and iso/test-firstboot.sh runs the same scenarios against both.
// Never partitions disks or writes the bootloader.
//
//   vaultos-firstuser             real run (root only; the systemd unit runs it)
//   vaultos-firstuser --dry-run   read everything, print what would change, write nothing
//
// Environment (same as the shell wizard):
//   VAULTOS_TEST_ROOT       prefix every /etc /var /home path (harness only;
//                           no useradd/chpasswd/hostnamectl/... are run)
//   VAULTOS_LIB             data dir with overlay/skel (default /usr/lib/vaultos)
//   VAULTOS_FIRSTBOOT_CONF  answers file (also kernel vaultos.firstboot=PATH)
//   VAULTOS_TEST_CMDLINE    stands in for /proc/cmdline, only with VAULTOS_TEST_ROOT
//
// Failure handling matches the shell's EXIT trap: any error, EOF or signal
// after useradd removes the half-made account again, keeps the answers file
// (0600) for a retry, and prints "Setup failed/cancelled". The stamp is the
// commit point; after it nothing is rolled back. Typeahead is thrown away
// before every prompt and echo is off during slow steps, so keys pressed early
// never become the username or show a password in clear.
#include <crypt.h>
#include <fcntl.h>
#include <grp.h>
#include <poll.h>
#include <signal.h>
#include <sys/stat.h>
#include <termios.h>
#include <unistd.h>
#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <regex>
#include <string>
#include <vector>

#include "phosphor.hpp"
#include "proc.hpp"
#include "text.hpp"

namespace fs = std::filesystem;
using std::string;
using std::vector;
using vaultos::is_dir;
using vaultos::is_link;
using vaultos::is_reg;
using vaultos::path_exists;

namespace {

// ---------------------------------------------------------------- state ----

struct Abort {  // unwinds to main(), which runs the shell's on_exit logic
  int rc;
};

string P;    // VAULTOS_TEST_ROOT
string LIB;  // VAULTOS_LIB
string STAMP, USER_STAMP, LOG, CONF_DEFAULT;
bool g_dry = false;
bool g_traps = false;  // shell: EXIT/INT/TERM traps installed
bool g_cancelled = false;
bool g_stamped = false;
volatile sig_atomic_t g_sig = 0;

bool g_skip = false;
string g_answer_file;  // from the kernel cmdline
string g_answer_path;  // the file actually read (shredded on success)
std::map<string, string> ANSWERS;
string g_reply;
string g_created_user, g_reset_only;

bool g_tty_saved = false;
struct termios g_tty {};

bool g_color = false;
string G, Rd, S, A, N;  // phosphor, reduced phosphor, steel, amber (warn), reset

bool in_test() { return !P.empty(); }

void init_colors() {
  g_color = isatty(1) && std::getenv("NO_COLOR") == nullptr;
  if (!g_color) return;
  auto rgb = [](unsigned v) {
    return "\033[38;2;" + std::to_string((v >> 16) & 0xFF) + ";" + std::to_string((v >> 8) & 0xFF) + ";" +
           std::to_string(v & 0xFF) + "m";
  };
  G = rgb(vaultos::kPhosphorHex);
  Rd = rgb(vaultos::kPhosphorReducedHex);
  S = rgb(vaultos::kSteelHex);
  A = rgb(0xFFB000);  // amber is for warnings only (DESIGN.md)
  N = "\033[0m";
}

// ------------------------------------------------------------- output ----

void out(const string& s) { std::cout << s << std::flush; }
void say(const string& s = "") { std::cout << s << "\n" << std::flush; }

void log(const string& m) {
  if (g_dry) return;
  std::ofstream f(LOG, std::ios::app);
  f << "vaultos-firstboot " << vaultos::now_iso() << " " << m << "\n";
}

void warn(const string& m) {
  std::cerr << "vaultos-firstboot: " << m << "\n" << std::flush;
  log("warn: " + m);
}

void dry(const string& m) { say(Rd + "[dry-run] " + m + N); }

void checkpoint() {
  if (g_sig) {
    int s = g_sig;
    log(s == SIGINT ? "interrupted" : "terminated");
    g_cancelled = true;
    throw Abort{s == SIGINT ? 130 : s == SIGQUIT ? 131 : 143};
  }
}

void nap(int ms) {
  struct timespec ts {ms / 1000, (ms % 1000) * 1000000L};
  while (nanosleep(&ts, &ts) != 0 && errno == EINTR) checkpoint();
}

// Typewriter effect, only on a real terminal.
void type(const string& s, int ms) {
  if (!isatty(1)) { out(s); return; }
  for (char c : s) {
    std::cout << c << std::flush;
    if (c != ' ' && c != '\n') nap(ms);
  }
}

// ------------------------------------------------------- file mutators ----
// Every change to the (fake) root goes through these, so --dry-run is honest.

void mkdirs(const string& d) {
  if (g_dry) return;
  std::error_code ec;
  fs::create_directories(d, ec);
}

mode_t g_umask = 022;

// Replace PATH atomically. An existing file keeps its mode; a new one gets
// 0666 & ~umask, like a shell redirect. Failure aborts, like set -e.
void put(const string& path, const string& data) {
  if (g_dry) { dry("write " + path); return; }
  struct stat st;
  mode_t mode = 0666 & ~g_umask;
  if (stat(path.c_str(), &st) == 0) mode = st.st_mode & 07777;
  string tmp = path + ".vaultos-tmp";
  int fd = open(tmp.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
  bool ok = fd >= 0;
  if (ok) {
    const char* p = data.data();
    size_t left = data.size();
    while (ok && left > 0) {
      ssize_t w = write(fd, p, left);
      if (w < 0 && errno == EINTR) continue;
      if (w <= 0) ok = false; else { p += w; left -= size_t(w); }
    }
    ok = fchmod(fd, mode) == 0 && ok;
    ok = fsync(fd) == 0 && ok;
    ok = close(fd) == 0 && ok;
  }
  if (ok) ok = rename(tmp.c_str(), path.c_str()) == 0;
  if (!ok) {
    unlink(tmp.c_str());
    std::cerr << "vaultos-firstboot: cannot write " << path << ": " << strerror(errno) << "\n";
    log("cannot write " + path);
    throw Abort{1};
  }
}

void append(const string& path, const string& data) {
  string cur;
  vaultos::slurp(path, cur);
  if (!cur.empty() && cur.back() != '\n') cur += '\n';
  put(path, cur + data);
}

void symlink_force(const string& target, const string& link) {
  if (g_dry) { dry("ln -sfn " + target + " " + link); return; }
  string tmp = link + ".vaultos-tmp";
  unlink(tmp.c_str());
  if (symlink(target.c_str(), tmp.c_str()) != 0 || rename(tmp.c_str(), link.c_str()) != 0) {
    unlink(tmp.c_str());
    std::cerr << "vaultos-firstboot: cannot link " << link << "\n";
    throw Abort{1};
  }
}

void rm_rf(const string& p) {
  if (g_dry) { dry("rm -rf " + p); return; }
  std::error_code ec;
  fs::remove_all(p, ec);
}

// A command that changes the system. In --dry-run it is only printed.
int sys(const vector<string>& argv, const vaultos::RunOpts& o = vaultos::RunOpts()) {
  if (g_dry) {
    string line;
    for (auto& a : argv) line += (line.empty() ? "" : " ") + a;
    dry(line);
    return 0;
  }
  return vaultos::run(argv, o);
}

int sys_quiet(const vector<string>& argv) {
  vaultos::RunOpts o;
  o.quiet_out = o.quiet_err = true;
  return sys(argv, o);
}

// ------------------------------------------------------------- stamps ----

void stamp_ok(const string& reason, const string& user = "") {
  string host = vaultos::chomp(vaultos::slurp(P + "/etc/hostname"));
  string tz;
  if (!vaultos::slurp(P + "/etc/timezone", tz)) tz = vaultos::read_link(P + "/etc/localtime");
  else tz = vaultos::chomp(tz);
  string body = "done=" + vaultos::now_iso() + "\nreason=" + reason + "\nuser=" + user + "\nhostname=" + host +
                "\ntimezone=" + tz + "\n";
  if (g_dry) {
    dry("stamp " + STAMP + " reason=" + reason + " user=" + user);
    return;
  }
  put(STAMP, body);
  chmod(STAMP.c_str(), 0644);
  std::error_code ec;
  fs::copy_file(STAMP, USER_STAMP, fs::copy_options::overwrite_existing, ec);
  log("stamped " + STAMP + " (" + reason + ")");
}

// ------------------------------------------------------- answers file ----
// The answers file can hold password= and wifi_psk= in clear text. Only read
// it when it is a regular file owned by root:root with mode 0600 (tightened
// with a warning if loose; refused if not root-owned or a symlink). After a
// successful run it is shredded; after a failed run it stays, still 0600, so
// the next boot can retry.

void answers_owner(uid_t& u, gid_t& g) {
  if (in_test()) { u = getuid(); g = getgid(); } else { u = 0; g = 0; }
}

string octal(mode_t m) {
  char b[16];
  snprintf(b, sizeof b, "%o", unsigned(m & 07777));
  return b;
}

bool answers_file_secure(const string& f) {
  uid_t want_u; gid_t want_g;
  answers_owner(want_u, want_g);
  struct stat st;
  if (lstat(f.c_str(), &st) != 0 || S_ISLNK(st.st_mode) || !S_ISREG(st.st_mode)) {
    warn("answers file " + f + " is not a regular file; ignoring it");
    return false;
  }
  if (st.st_uid != want_u) {
    warn("answers file " + f + " is owned by uid " + std::to_string(st.st_uid) + ", not root; ignoring it");
    return false;
  }
  if (st.st_gid != want_g || (st.st_mode & 07177)) {
    warn("answers file " + f + " was mode " + octal(st.st_mode) + " group " + std::to_string(st.st_gid) +
         "; setting 0600 root:root. A password in it may already have been readable.");
    if (g_dry) { dry("chown " + std::to_string(want_u) + ":" + std::to_string(want_g) + " + chmod 0600 " + f); return true; }
    if (chown(f.c_str(), want_u, want_g) != 0 || chmod(f.c_str(), 0600) != 0) {
      warn("could not secure " + f + "; ignoring it");
      return false;
    }
  }
  return true;
}

void remove_answers() {
  string f = g_answer_path;
  if (f.empty() || is_link(f) || !is_reg(f)) return;
  g_answer_path.clear();
  if (g_dry) { dry("shred -u -z " + f); return; }
  if (vaultos::have("shred") && sys_quiet({"shred", "-u", "-z", f}) == 0) {
    log("answers file " + f + " shredded");
  } else if (unlink(f.c_str()) == 0) {
    log("answers file " + f + " removed (shred unavailable or failed)");
  } else {
    // Read-only media or similar: at least drop the secrets.
    static const std::regex secret("^[[:space:]]*(password|wifi_psk)[[:space:]]*=.*");
    string kept;
    for (auto& l : vaultos::lines(vaultos::slurp(f)))
      if (!std::regex_match(l, secret)) kept += l + "\n";
    std::ofstream o(f, std::ios::trunc);
    o << kept;
    o.close();
    if (o) warn("could not delete " + f + "; removed password keys from it");
    else warn("could not delete or scrub " + f + "; remove it by hand");
  }
}

void keep_answers_for_retry() {
  string f = g_answer_path;
  if (f.empty() || is_link(f) || !is_reg(f) || g_dry) return;
  uid_t u; gid_t g;
  answers_owner(u, g);
  if (chown(f.c_str(), u, g) != 0) {}
  chmod(f.c_str(), 0600);
  log("answers file " + f + " kept (0600) for the next attempt");
}

void finish_ok(const string& reason, const string& user = "") {
  stamp_ok(reason, user);
  g_stamped = true;  // commit point: never roll back after this
  remove_answers();
}

// Boot options: vaultos.firstboot=skip | vaultos.firstboot=/path/answers.conf
void parse_cmdline() {
  string cl;
  const char* t = std::getenv("VAULTOS_TEST_CMDLINE");
  if (in_test() && t) cl = t;
  else if (!vaultos::slurp("/proc/cmdline", cl)) return;
  for (auto& w : vaultos::words(cl)) {
    if (w == "vaultos.firstboot=skip") g_skip = true;
    else if (vaultos::starts_with(w, "vaultos.firstboot=")) g_answer_file = w.substr(18);
  }
}

void load_answers() {
  const char* e = std::getenv("VAULTOS_FIRSTBOOT_CONF");
  string f = (e && *e) ? e : g_answer_file;
  if (f.empty() && is_reg(CONF_DEFAULT)) f = CONF_DEFAULT;
  if (f.empty() || !path_exists(f)) return;
  if (!answers_file_secure(f)) return;
  g_answer_path = f;
  log("answers " + f);
  static const std::regex skip_re("^[[:space:]]*(#.*)?$");
  for (auto& line : vaultos::lines(vaultos::slurp(f))) {
    if (std::regex_match(line, skip_re)) continue;
    size_t eq = line.find('=');
    string k = line.substr(0, eq);
    string v = eq == string::npos ? line : line.substr(eq + 1);
    if (!k.empty()) ANSWERS[k] = v;
  }
}

string answer(const string& k) {
  auto it = ANSWERS.find(k);
  return it == ANSWERS.end() ? "" : it->second;
}

// ------------------------------------------------------ passwd/shadow ----

vector<vector<string>> read_db(const string& path) {
  vector<vector<string>> rows;
  for (auto& l : vaultos::lines(vaultos::slurp(path))) rows.push_back(vaultos::split(l, ':'));
  return rows;
}

bool db_has(const string& path, const string& name) {
  for (auto& r : read_db(path)) if (!r.empty() && r[0] == name) return true;
  return false;
}

bool all_digits(const string& s) {
  return !s.empty() && std::all_of(s.begin(), s.end(), [](char c) { return c >= '0' && c <= '9'; });
}

string first_login_user() {
  for (auto& r : read_db(P + "/etc/passwd")) {
    if (r.size() < 3 || !all_digits(r[2]) || r[2].size() > 9) continue;
    long uid = std::stol(r[2]);
    if (uid >= 1000 && uid < 65534) return r[0];
  }
  return "";
}

bool shadow_readable() { return access((P + "/etc/shadow").c_str(), R_OK) == 0; }

string shadow_hash_for(const string& name) {
  for (auto& r : read_db(P + "/etc/shadow"))
    if (!r.empty() && r[0] == name) return r.size() > 1 ? r[1] : "";
  return "";
}

bool hash_usable(const string& h) { return !h.empty() && h != "!" && h != "*" && h != "!!" && h[0] == '$'; }

// --------------------------------------------------------------- input ----

void hold_input() {
  if (!isatty(0)) return;
  if (!g_tty_saved && tcgetattr(0, &g_tty) == 0) g_tty_saved = true;
  struct termios t;
  if (tcgetattr(0, &t) == 0) { t.c_lflag &= ~tcflag_t(ECHO); tcsetattr(0, TCSANOW, &t); }
}

void restore_tty() {
  if (g_tty_saved) { tcsetattr(0, TCSANOW, &g_tty); g_tty_saved = false; }
}

// Throw away everything typed ahead, including a half-typed line, and keep
// doing so until the keyboard has been quiet for 50 ms (the shell's
// read -t 0.05 loop). Only on a TTY.
void drain_input() {
  if (!isatty(0)) return;
  for (int i = 0; i < 40; ++i) {
    tcflush(0, TCIFLUSH);
    struct pollfd p {0, POLLIN, 0};
    int r = poll(&p, 1, 50);
    if (r < 0 && errno == EINTR) { checkpoint(); continue; }
    if (r <= 0) break;
  }
  tcflush(0, TCIFLUSH);
  restore_tty();
}

// One line from fd 0, unbuffered (so drain_input really empties the queue).
// false on EOF before a newline, like bash read.
bool read_line(string& line, bool secret = false) {
  line.clear();
  struct termios old;
  bool silent = secret && isatty(0) && tcgetattr(0, &old) == 0;
  if (silent) {
    struct termios t = old;
    t.c_lflag &= ~tcflag_t(ECHO);
    tcsetattr(0, TCSANOW, &t);
  }
  bool nl = false;
  for (;;) {
    char c;
    ssize_t n = read(0, &c, 1);
    if (n < 0 && errno == EINTR) {
      if (g_sig) { if (silent) tcsetattr(0, TCSANOW, &old); checkpoint(); }
      continue;
    }
    if (n <= 0) break;
    if (c == '\n') { nl = true; break; }
    line += c;
  }
  if (silent) tcsetattr(0, TCSANOW, &old);
  return nl;
}

// ask KEY DEFAULT PROMPT — answers file first, else the keyboard.
void ask(const string& key, const string& def, const string& prompt) {
  checkpoint();
  string a = answer(key);
  if (!a.empty()) {
    g_reply = a;
    say(G + "  " + prompt + " [" + def + "]: " + N + g_reply);
    return;
  }
  drain_input();
  out(G + "  " + prompt + " [" + def + "]: " + N);
  if (!read_line(g_reply)) { say(); throw Abort{1}; }
  checkpoint();
  if (g_reply.empty()) g_reply = def;
}

void bad(const string& m) { say("  " + A + m + N); }

// ------------------------------------------------------------- machine ----

bool valid_hostname(const string& h) {
  static const std::regex re("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$");
  return std::regex_match(vaultos::lower(h), re);
}

void apply_hostname(const string& h) {
  put(P + "/etc/hostname", h + "\n");
  if (!in_test() && vaultos::have("hostnamectl")) sys({"hostnamectl", "set-hostname", h});
  string hosts = P + "/etc/hosts";
  if (is_reg(hosts)) {
    static const std::regex lo("^127\\.0\\.1\\.1[[:space:]].*");
    bool found = false;
    string outs;
    for (auto& l : vaultos::lines(vaultos::slurp(hosts))) {
      if (std::regex_match(l, lo)) { outs += "127.0.1.1\t" + h + "\n"; found = true; }
      else outs += l + "\n";
    }
    if (found) put(hosts, outs);
    else append(hosts, "127.0.1.1\t" + h + "\n");
  } else {
    put(hosts, "127.0.0.1\tlocalhost\n127.0.1.1\t" + h + "\n");
  }
  log("hostname " + h);
}

vector<string> list_timezones() {
  vector<string> zones;
  if (vaultos::have("timedatectl") && !in_test()) {
    int rc = 0;
    string o = vaultos::capture({"timedatectl", "list-timezones"}, &rc);
    if (rc == 0) return vaultos::lines(o);
  }
  string z = P + "/usr/share/zoneinfo";
  if (!is_dir(z)) z = "/usr/share/zoneinfo";
  if (!is_dir(z)) return zones;
  std::error_code ec;
  for (auto it = fs::recursive_directory_iterator(z, ec); !ec && it != fs::recursive_directory_iterator();
       it.increment(ec)) {
    if (!it->is_regular_file(ec) || it->is_symlink(ec)) continue;
    string p = it->path().string();
    if (vaultos::contains(p, "/posix/") || vaultos::contains(p, "/right/")) continue;
    string rel = p.substr(z.size() + 1);
    if (!rel.empty() && rel[0] >= 'A' && rel[0] <= 'Z') zones.push_back(rel);
  }
  std::sort(zones.begin(), zones.end());
  return zones;
}

// A zone is a file under zoneinfo. Reject directories ("America"), absolute
// paths, and ".." so /etc/localtime never points outside zoneinfo.
bool valid_timezone(const string& tz) {
  if (tz.empty() || tz[0] == '/' || vaultos::contains(tz, "..")) return false;
  return is_reg(P + "/usr/share/zoneinfo/" + tz) || is_reg("/usr/share/zoneinfo/" + tz);
}

void apply_timezone(const string& tz) {
  put(P + "/etc/timezone", tz + "\n");
  string src = "/usr/share/zoneinfo/" + tz;
  if (path_exists(P + "/usr/share/zoneinfo/" + tz)) src = P + "/usr/share/zoneinfo/" + tz;
  symlink_force(src, P + "/etc/localtime");
  if (!in_test() && vaultos::have("timedatectl")) sys({"timedatectl", "set-timezone", tz});
  log("timezone " + tz);
}

void apply_locale(const string& loc) {
  string gen = P + "/etc/locale.gen";
  mkdirs(P + "/etc");
  string cur;
  vaultos::slurp(gen, cur);
  vector<string> ls = vaultos::lines(cur);
  auto ws = [](char c) { return c == ' ' || c == '\t'; };
  bool commented = false, active = false;
  for (auto& l : ls) {
    // ^#\s*LOC[[:space:]]  ->  "LOC "
    if (!l.empty() && l[0] == '#') {
      size_t i = 1;
      while (i < l.size() && ws(l[i])) ++i;
      if (l.compare(i, loc.size(), loc) == 0 && i + loc.size() < l.size() && ws(l[i + loc.size()])) {
        l = loc + " " + l.substr(i + loc.size() + 1);
        commented = true;
      }
    } else if (vaultos::starts_with(l, loc) && l.size() > loc.size() && ws(l[loc.size()])) {
      active = true;
    }
  }
  if (commented) {
    string o;
    for (auto& l : ls) o += l + "\n";
    put(gen, o);
  } else if (!active) {
    append(gen, loc + " UTF-8\n");
  }
  put(P + "/etc/locale.conf", "LANG=" + loc + "\n");
  if (!in_test() && vaultos::have("locale-gen"))
    if (sys_quiet({"locale-gen"}) != 0) sys({"locale-gen"});
  if (!in_test() && vaultos::have("localectl")) sys({"localectl", "set-locale", "LANG=" + loc});
  log("locale " + loc);
}

void apply_keymap(const string& km) {
  mkdirs(P + "/etc/vconsole.d");
  mkdirs(P + "/etc/X11/xorg.conf.d");
  put(P + "/etc/vconsole.conf", "KEYMAP=" + km + "\n");
  put(P + "/etc/X11/xorg.conf.d/00-keyboard.conf",
      "Section \"InputClass\"\n    Identifier \"system-keyboard\"\n    MatchIsKeyboard \"on\"\n"
      "    Option \"XkbLayout\" \"" + km + "\"\nEndSection\n");
  if (!in_test() && vaultos::have("localectl")) {
    sys({"localectl", "set-keymap", km});
    sys({"localectl", "set-x11-keymap", km});
  }
  log("keymap " + km);
}

bool net_online() {
  if (in_test()) return answer("online") == "1";
  vaultos::RunOpts q;
  q.quiet_out = q.quiet_err = true;
  q.null_in = true;
  // Public anycast resolvers, same as the shell wizard.
  return vaultos::run({"ping", "-c1", "-W2", "9.9.9.9"}, q) == 0 ||
         vaultos::run({"ping", "-c1", "-W2", "1.1.1.1"}, q) == 0;
}

string wifi_device() {
  if (in_test()) return answer("wifi_dev");
  if (!vaultos::have("nmcli")) return "";
  for (auto& l : vaultos::lines(vaultos::capture({"nmcli", "-t", "-f", "TYPE,DEVICE", "device", "status"}))) {
    auto f = vaultos::split(l, ':');
    if (f.size() >= 2 && f[0] == "wifi") return f[1];
  }
  return "";
}

bool apply_wifi(const string& ssid, const string& psk) {
  log("wifi ssid=" + ssid);
  if (in_test()) return true;
  vaultos::RunOpts in;
  in.null_in = true;
  if (vaultos::have("nmcli") && sys({"nmcli", "device", "wifi", "connect", ssid, "password", psk}, in) == 0)
    return true;
  if (vaultos::have("iwctl")) {
    string dev = wifi_device();
    if (dev.empty()) return false;
    return sys({"iwctl", "--passphrase", psk, "station", dev, "connect", ssid}, in) == 0;
  }
  return false;
}

void banner() {
  if (isatty(1)) out("\033[2J\033[H");
  out(G);
  type("\n  VAULT-TEC INDUSTRIES (TM) TERMLINK PROTOCOL\n", 10);
  out(Rd);
  type("  ENTERING OVERSEER REGISTRATION . . .\n", 18);
  say(N);
}

void prompt_machine() {
  say();
  say(G + "  Vault.OS setup" + N);
  say(S + "  ──────────────" + N);
  say(S + "  Enter accepts the value in [brackets]." + N);
  say();

  string h;
  for (;;) {
    ask("hostname", "vaultos", "Hostname");
    h = vaultos::lower(g_reply);
    if (valid_hostname(h)) break;
    bad("Use letters, digits, and hyphen (RFC 1123). Try again.");
    ANSWERS["hostname"] = "";
  }
  apply_hostname(h);

  string tz;
  for (;;) {
    ask("timezone", "UTC", "Timezone (type a zone, or a search like 'New_York')");
    tz = g_reply;
    if (valid_timezone(tz)) break;
    say("Matches:");
    string needle = vaultos::lower(tz);
    int n = 0;
    for (auto& z : list_timezones()) {
      if (!vaultos::contains(vaultos::lower(z), needle)) continue;
      say(z);
      if (++n >= 20) break;
    }
    bad("Type a full zone from the list (example: America/New_York).");
    ANSWERS["timezone"] = "";
  }
  apply_timezone(tz);

  static const std::regex loc_re("^[A-Za-z0-9_@.-]+$");
  string loc;
  for (;;) {
    ask("locale", "en_US.UTF-8", "Locale");
    loc = g_reply;
    if (std::regex_match(loc, loc_re)) break;
    bad("Example: en_US.UTF-8");
    ANSWERS["locale"] = "";
  }
  say(Rd + "  Applying locale " + loc + "… (this can take a few seconds; please wait)" + N);
  hold_input();
  apply_locale(loc);
  checkpoint();

  static const std::regex km_re("^[a-z0-9_-]+$");
  string km;
  for (;;) {
    ask("keymap", "us", "Keyboard layout");
    km = vaultos::lower(g_reply);
    if (std::regex_match(km, km_re)) break;
    bad("Example: us, uk, de, fr");
    ANSWERS["keymap"] = "";
  }
  say(Rd + "  Applying keyboard layout " + km + "… (please wait)" + N);
  hold_input();
  apply_keymap(km);
  checkpoint();

  if (net_online()) { say("  Network: online."); return; }
  say("  Network: offline.");
  if (wifi_device().empty()) {
    say("  No Wi-Fi device detected. Plug in Ethernet or configure after login.");
    return;
  }
  // skip_wifi=1 means "skip"; it is not the answer to "Connect?".
  string q = vaultos::lower(answer("skip_wifi"));
  if (q == "1" || q == "y" || q == "yes" || q == "true") q = "n";
  else if (q == "0" || q == "n" || q == "no" || q == "false") q = "y";
  else { ask("connect_wifi", "n", "Connect Wi-Fi now? (y/n)"); q = vaultos::lower(g_reply); }
  if (q != "y" && q != "yes") { say("  Skipping Wi-Fi."); return; }
  ask("wifi_ssid", "", "Wi-Fi SSID");
  string ssid = g_reply;
  if (ssid.empty()) return;
  string psk = answer("wifi_psk");
  if (psk.empty()) {
    drain_input();
    out(G + "  Wi-Fi password: " + N);
    read_line(psk, true);
    say();
    checkpoint();
  }
  if (!apply_wifi(ssid, psk)) bad("Wi-Fi connect failed; you can set it up after login.");
  explicit_bzero(psk.data(), psk.size());
}

// ------------------------------------------------------------- account ----

bool reserved(const string& u) {
  static const char* names[] = {"root", "daemon", "bin", "sys", "sync", "games", "man", "lp", "mail", "news",
                                "uucp", "proxy", "www-data", "backup", "nobody", "nfsnobody", "nobody4",
                                "nogroup", "guest", "vaultos-live"};
  for (auto n : names) if (u == n) return true;
  return vaultos::starts_with(u, "systemd-");
}

bool valid_name(const string& u) {
  static const std::regex re("^[a-z_][a-z0-9_-]{0,31}$");
  return std::regex_match(u, re) && !reserved(u);
}

void ensure_wheel_sudo() {
  string drop = P + "/etc/sudoers.d/wheel";
  mkdirs(P + "/etc/sudoers.d");
  mkdirs(P + "/tmp");
  if (g_dry) { dry("install -m 0440 (visudo -c checked) " + drop); return; }
  string tmpl = P + "/tmp/vaultos-sudoers.XXXXXX";
  vector<char> b(tmpl.begin(), tmpl.end());
  b.push_back('\0');
  int fd = mkstemp(b.data());
  if (fd < 0) {
    string alt = "/tmp/vaultos-sudoers.XXXXXX";
    b.assign(alt.begin(), alt.end());
    b.push_back('\0');
    fd = mkstemp(b.data());
  }
  if (fd < 0) { say("sudoers drop-in: no temp file"); throw Abort{1}; }
  string tmp = b.data();
  const char rule[] = "%wheel ALL=(ALL:ALL) ALL\n";
  bool ok = write(fd, rule, sizeof rule - 1) == ssize_t(sizeof rule - 1);
  close(fd);
  if (ok && vaultos::have("visudo")) {
    vaultos::RunOpts q;
    q.quiet_out = true;
    q.null_in = true;
    if (vaultos::run({"visudo", "-c", "-f", tmp}, q) != 0) {
      unlink(tmp.c_str());
      say("sudoers drop-in failed visudo -c");
      throw Abort{1};
    }
    checkpoint();
  }
  string data = vaultos::slurp(tmp);
  unlink(tmp.c_str());
  if (!ok) { say("sudoers drop-in: write failed"); throw Abort{1}; }
  if (!g_dry) unlink(drop.c_str());  // install(1) replaces the file and sets 0440
  put(drop, data);
  if (!g_dry && chmod(drop.c_str(), 0440) != 0) { say("sudoers drop-in: chmod failed"); throw Abort{1}; }
  log("sudoers " + drop);
}

string read_password() {
  if (ANSWERS.count("password")) {
    string pw = ANSWERS["password"];
    if (pw.empty()) { bad("Password cannot be empty."); throw Abort{1}; }
    return pw;
  }
  for (;;) {
    string p1, p2;
    drain_input();
    out(G + "  Password: " + N);
    if (!read_line(p1, true)) { say(); throw Abort{1}; }
    say();
    checkpoint();
    drain_input();
    out(G + "  Password (again): " + N);
    if (!read_line(p2, true)) { say(); throw Abort{1}; }
    say();
    checkpoint();
    if (p1.empty()) { bad("Password cannot be empty."); continue; }
    if (p1 != p2) { bad("Passwords do not match."); explicit_bzero(p1.data(), p1.size()); continue; }
    explicit_bzero(p2.data(), p2.size());
    return p1;
  }
}

bool set_password(const string& user, const string& pw) {
  if (in_test()) {
    // A real SHA-512 crypt hash, so the fake shadow looks like the real one.
    char salt[CRYPT_GENSALT_OUTPUT_SIZE];
    struct crypt_data cd;
    memset(&cd, 0, sizeof cd);
    string hash = "$6$testsalt$testhash";
    if (crypt_gensalt_rn("$6$", 0, nullptr, 0, salt, sizeof salt)) {
      const char* h = crypt_r(pw.c_str(), salt, &cd);
      if (h && h[0] == '$') hash = h;
    }
    explicit_bzero(&cd, sizeof cd);
    string shadow = P + "/etc/shadow";
    if (db_has(shadow, user)) {
      string o;
      for (auto& l : vaultos::lines(vaultos::slurp(shadow))) {
        auto f = vaultos::split(l, ':');
        if (f.size() >= 2 && f[0] == user) {
          f[1] = hash;
          string j;
          for (size_t i = 0; i < f.size(); ++i) j += (i ? ":" : "") + f[i];
          o += j + "\n";
        } else {
          o += l + "\n";
        }
      }
      put(shadow, o);
    } else {
      append(shadow, user + ":" + hash + ":1:0:99999:7:::\n");
    }
    return true;
  }
  if (g_dry) { dry("chpasswd (" + user + ")"); return true; }
  string line = user + ":" + pw + "\n";
  vaultos::RunOpts o;
  o.input = &line;
  int rc = vaultos::run({"chpasswd"}, o);
  explicit_bzero(line.data(), line.size());
  return rc == 0;
}

void test_useradd(const string& user, const vector<string>& groups) {
  append(P + "/etc/passwd", user + ":x:1000:1000::" + P + "/home/" + user + ":/bin/bash\n");
  append(P + "/etc/group", user + ":x:1000:\n");
  mkdirs(P + "/home/" + user);
  string gpath = P + "/etc/group";
  for (auto& g : groups) {
    if (!db_has(gpath, g)) continue;
    string o;
    for (auto& l : vaultos::lines(vaultos::slurp(gpath))) {
      auto f = vaultos::split(l, ':');
      if (!f.empty() && f[0] == g) {
        while (f.size() < 4) f.push_back("");
        f[3] = f[3].empty() ? user : f[3] + "," + user;
        string j;
        for (size_t i = 0; i < f.size(); ++i) j += (i ? ":" : "") + f[i];
        o += j + "\n";
      } else {
        o += l + "\n";
      }
    }
    put(gpath, o);
  }
}

vector<string> existing_groups() {
  vector<string> out_g;
  for (const char* g : {"wheel", "video", "audio", "input", "network"}) {
    if (in_test() ? db_has(P + "/etc/group", g) : getgrnam(g) != nullptr) out_g.push_back(g);
  }
  return out_g;
}

string self_dir() {
  string exe = vaultos::read_link("/proc/self/exe");
  return exe.empty() ? "." : fs::path(exe).parent_path().string();
}

void seed_skel_home(const string& home, const string& who) {
  string skel = LIB + "/overlay/skel";
  if (!is_dir(skel)) skel = self_dir() + "/../overlay/skel";
  if (is_dir(skel)) {
    mkdirs(home);
    sys_quiet({"cp", "-a", skel + "/.", home + "/"});
  }
  string vo = LIB + "/../bin/vault-os";
  if (vaultos::is_exec_file(vo)) {
    if (in_test()) return;
    sys_quiet({"sudo", "-u", who, "-H", "env", "HOME=" + home, vo, "install"});
  }
}

void set_lightdm_session() {
  string d = P + "/etc/lightdm/lightdm.conf.d";
  mkdirs(d);
  mkdirs(P + "/usr/share/xsessions");
  put(d + "/50-vaultos.conf",
      "[Seat:*]\nuser-session=vaultos\ngreeter-session=lightdm-gtk-greeter\n"
      "greeter-hide-users=false\ngreeter-show-manual-login=true\n");
  string xs = LIB + "/overlay/xsessions/vaultos.desktop";
  if (is_reg(xs)) {
    string dst = P + "/usr/share/xsessions/vaultos.desktop";
    put(dst, vaultos::slurp(xs));
    if (!g_dry) chmod(dst.c_str(), 0644);
  }
  log("lightdm user-session=vaultos");
}

void prompt_account() {
  say();
  if (!g_reset_only.empty()) {
    say("  Account " + G + g_reset_only + N + " exists but has no password. Set one now.");
    string pw = read_password();
    if (!set_password(g_reset_only, pw)) { explicit_bzero(pw.data(), pw.size()); throw Abort{1}; }
    explicit_bzero(pw.data(), pw.size());
    ensure_wheel_sudo();
    set_lightdm_session();
    say("  Password updated for " + g_reset_only + ".");
    return;
  }

  say(G + "  Create the account you will log in with." + N);
  say(S + "  Username: lowercase letters, digits, _ or -  (not root)." + N);
  say();
  string user;
  for (;;) {
    ask("username", "", "Username");
    user.clear();
    for (char c : vaultos::lower(g_reply)) if (c != ' ') user += c;
    if (!valid_name(user)) { bad("That username is not allowed. Try another."); ANSWERS["username"] = ""; continue; }
    if (db_has(P + "/etc/passwd", user)) { bad("That username is taken."); ANSWERS["username"] = ""; continue; }
    break;
  }

  string pw = read_password();
  vector<string> groups = existing_groups();
  string gl;
  for (auto& g : groups) gl += (gl.empty() ? "" : ",") + g;
  string home = P + "/home/" + user;
  checkpoint();
  if (in_test()) {
    g_created_user = user;  // set first: a failed write half-way must still roll back
    test_useradd(user, groups);
  } else {
    vector<string> argv = {"useradd", "-m"};
    if (!gl.empty()) { argv.push_back("-G"); argv.push_back(gl); }
    argv.insert(argv.end(), {"-s", "/bin/bash", user});
    int rc = sys(argv);
    // useradd may have made the account even if it then failed (home copy).
    if (rc == 0 || (!g_dry && db_has("/etc/passwd", user))) g_created_user = user;
    if (rc != 0) { bad("useradd failed for " + user + "."); explicit_bzero(pw.data(), pw.size()); throw Abort{1}; }
  }
  checkpoint();

  if (!set_password(user, pw)) {
    explicit_bzero(pw.data(), pw.size());
    bad("Could not set password.");
    throw Abort{1};
  }
  explicit_bzero(pw.data(), pw.size());

  ensure_wheel_sudo();
  seed_skel_home(home, user);
  if (!in_test()) sys_quiet({"chown", "-R", user + ":" + user, home});
  set_lightdm_session();
  checkpoint();
  say();
  say("  Account " + G + user + N + " is ready.");
}

void rollback_user() {
  string u = g_created_user;
  if (u.empty()) return;
  log("rollback " + u);
  g_created_user.clear();
  if (g_dry) { dry("rollback: " + string(in_test() ? "remove " : "userdel -r ") + u); return; }
  if (in_test()) {
    auto filter = [&](const string& path, bool groups) {
      string o;
      for (auto& l : vaultos::lines(vaultos::slurp(path))) {
        auto f = vaultos::split(l, ':');
        if (!f.empty() && f[0] == u) continue;
        if (groups && f.size() >= 4) {
          string m;
          for (auto& x : vaultos::split(f[3], ','))
            if (!x.empty() && x != u) m += (m.empty() ? "" : ",") + x;
          f[3] = m;
          string j;
          for (size_t i = 0; i < f.size(); ++i) j += (i ? ":" : "") + f[i];
          o += j + "\n";
        } else {
          o += l + "\n";
        }
      }
      try { put(path, o); } catch (const Abort&) {}
    };
    filter(P + "/etc/passwd", false);
    filter(P + "/etc/shadow", false);
    filter(P + "/etc/group", true);
    rm_rf(P + "/home/" + u);
  } else {
    sys_quiet({"userdel", "-r", u});
  }
}

void on_signal(int sig) { g_sig = sig; }

void install_traps() {
  struct sigaction sa {};
  sa.sa_handler = on_signal;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;  // no SA_RESTART: a blocked read returns EINTR and we unwind
  for (int s : {SIGINT, SIGTERM, SIGHUP, SIGQUIT}) sigaction(s, &sa, nullptr);
  g_traps = true;
}

int on_exit_rc(int rc) {
  restore_tty();
  if (!g_traps) return rc;
  if (rc != 0 && g_stamped) {
    // Account and stamp are in place; a late error (e.g. a hung-up tty on the
    // final message) must not delete the user or block LightDM.
    log("error rc=" + std::to_string(rc) + " after stamp; keeping account");
    return 0;
  }
  if (rc != 0) {
    log("fail rc=" + std::to_string(rc));
    try { rollback_user(); } catch (...) {}
    try { keep_answers_for_retry(); } catch (...) {}
    std::cout << "\n" << A << (g_cancelled ? "  Setup cancelled. Reboot to try again." : "  Setup failed. Reboot to try again.")
              << N << "\n" << std::flush;
  }
  return rc;
}

int wizard() {
  if ((is_dir("/run/archiso") || is_reg("/run/archiso/bootmnt")) && !in_test()) {
    stamp_ok("live");
    return 0;
  }
  parse_cmdline();
  load_answers();
  if (answer("skip") == "1") g_skip = true;
  if (g_skip) { finish_ok("skip"); return 0; }
  if (path_exists(STAMP)) { log("already stamped"); return 0; }

  string existing = first_login_user();
  if (!existing.empty()) {
    if (g_dry && !shadow_readable()) {
      dry("cannot read " + P + "/etc/shadow (not root); treating " + existing + " as an account with a password");
      finish_ok("existing-user", existing);
      return 0;
    }
    if (hash_usable(shadow_hash_for(existing))) { finish_ok("existing-user", existing); return 0; }
    g_reset_only = existing;
    log("user " + existing + " has no usable password; reset-only");
  }

  if (!in_test() && !g_dry) {
    struct stat st;
    if (stat("/dev/tty1", &st) == 0 && S_ISCHR(st.st_mode)) {
      int fd = open("/dev/tty1", O_RDWR);
      if (fd >= 0) { dup2(fd, 0); dup2(fd, 1); dup2(fd, 2); if (fd > 2) close(fd); }
      init_colors();
    }
    if (vaultos::have("plymouth")) sys_quiet({"plymouth", "quit"});
  }

  install_traps();
  banner();
  prompt_machine();
  prompt_account();
  finish_ok("created", g_created_user.empty() ? g_reset_only : g_created_user);
  string who = vaultos::upper(g_created_user.empty() ? g_reset_only : g_created_user);
  out(G);
  type("  WELCOME TO VAULT.OS, OVERSEER " + who + ".\n", 22);
  say(Rd + "  Continuing to login…" + N);
  if (isatty(1)) nap(1000);
  return 0;
}

void usage() {
  std::cout << "usage: vaultos-firstuser [--dry-run]\n"
               "First-boot wizard (hostname, timezone, locale, keymap, Wi-Fi, account).\n"
               "Runs as root from vaultos-firstuser.service. --dry-run changes nothing.\n"
               "Answers file: /etc/vaultos/firstboot.conf (root:root 0600) or\n"
               "VAULTOS_FIRSTBOOT_CONF or kernel vaultos.firstboot=PATH; vaultos.firstboot=skip skips.\n";
}

}  // namespace

int main(int argc, char** argv) {
  for (int i = 1; i < argc; ++i) {
    string a = argv[i];
    if (a == "--dry-run") g_dry = true;
    else if (a == "-h" || a == "--help") { usage(); return 0; }
    else { std::cerr << "vaultos-firstuser: unknown option " << a << "\n"; usage(); return 2; }
  }
  if (const char* t = std::getenv("VAULTOS_TEST_ROOT")) P = t;
  const char* lib = std::getenv("VAULTOS_LIB");
  LIB = (lib && *lib) ? lib : "/usr/lib/vaultos";
  if (!in_test() && !g_dry && geteuid() != 0) {
    std::cerr << "vaultos-firstuser needs root (or --dry-run, or VAULTOS_TEST_ROOT for a fake root)\n";
    return 1;
  }
  STAMP = P + "/var/lib/vaultos/firstboot-done";
  USER_STAMP = P + "/var/lib/vaultos/firstuser-done";
  LOG = P + "/var/log/vaultos-firstboot.log";
  CONF_DEFAULT = P + "/etc/vaultos/firstboot.conf";
  signal(SIGPIPE, SIG_IGN);
  g_umask = umask(0);
  umask(g_umask);
  init_colors();
  mkdirs(P + "/var/lib/vaultos");
  mkdirs(P + "/var/log");
  mkdirs(P + "/etc/vaultos");

  int rc = 0;
  try {
    rc = wizard();
  } catch (const Abort& a) {
    rc = a.rc;
  } catch (const std::exception& e) {
    std::cerr << "vaultos-firstboot: " << e.what() << "\n";
    log(string("error: ") + e.what());
    rc = 1;
  }
  return on_exit_rc(rc);
}

// vaultos — Vault.OS distro CLI (Arch derivative), native C++.
// Same commands and output as the old bash CLI. Theme/session tools stay in
// `vault-os` (hyphen). Never touches hostname, bootloader, kernel or disks
// unless you ask for `firstboot --run`.
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <array>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <regex>
#include <sstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;
using std::string;

namespace {

string g_root, g_lib, g_checkout, g_version, g_ident, g_pkgsh;

bool is_exec(const fs::path& p) { return access(p.c_str(), X_OK) == 0 && fs::is_regular_file(p); }
bool present(const fs::path& p) { std::error_code ec; return fs::exists(p, ec); }

string slurp(const fs::path& p) {
  std::ifstream f(p);
  std::stringstream ss;
  ss << f.rdbuf();
  return ss.str();
}
string first_line(const fs::path& p) {
  std::ifstream f(p);
  string s;
  std::getline(f, s);
  return s;
}
string trim(string s) {
  while (!s.empty() && (s.back() == '\n' || s.back() == ' ' || s.back() == '\r')) s.pop_back();
  return s;
}

// Run a shell-free argv, capture stdout (stderr discarded). rc via *rc.
string run(const std::vector<string>& argv, int* rc = nullptr) {
  int pipefd[2];
  if (pipe(pipefd) != 0) { if (rc) *rc = 127; return ""; }
  pid_t pid = fork();
  if (pid == 0) {
    dup2(pipefd[1], 1);
    int devnull = open("/dev/null", O_WRONLY);
    if (devnull >= 0) dup2(devnull, 2);
    close(pipefd[0]); close(pipefd[1]);
    std::vector<char*> a;
    for (auto& s : argv) a.push_back(const_cast<char*>(s.c_str()));
    a.push_back(nullptr);
    execvp(a[0], a.data());
    _exit(127);
  }
  close(pipefd[1]);
  string out;
  std::array<char, 4096> buf;
  ssize_t n;
  while ((n = read(pipefd[0], buf.data(), buf.size())) > 0) out.append(buf.data(), n);
  close(pipefd[0]);
  int st = 0;
  waitpid(pid, &st, 0);
  if (rc) *rc = WIFEXITED(st) ? WEXITSTATUS(st) : 1;
  return out;
}
// Run with inherited stdio, return exit code.
int sys(const std::vector<string>& argv) {
  pid_t pid = fork();
  if (pid == 0) {
    std::vector<char*> a;
    for (auto& s : argv) a.push_back(const_cast<char*>(s.c_str()));
    a.push_back(nullptr);
    execvp(a[0], a.data());
    _exit(127);
  }
  int st = 0;
  waitpid(pid, &st, 0);
  return WIFEXITED(st) ? WEXITSTATUS(st) : 1;
}
[[noreturn]] void exec(const std::vector<string>& argv) {
  std::vector<char*> a;
  for (auto& s : argv) a.push_back(const_cast<char*>(s.c_str()));
  a.push_back(nullptr);
  std::cout.flush();
  execvp(a[0], a.data());
  std::perror(a[0]);
  _exit(127);
}
bool have(const string& cmd) {
  const char* path = std::getenv("PATH");
  std::stringstream ss(path ? path : "/usr/bin:/bin");
  string d;
  while (std::getline(ss, d, ':')) if (is_exec(fs::path(d) / cmd)) return true;
  return false;
}
bool root() { return geteuid() == 0; }

string os_release_id() {
  std::ifstream f("/etc/os-release");
  string l;
  while (std::getline(f, l)) if (l.rfind("ID=", 0) == 0) return l.substr(3);
  return "";
}
bool os_release_has(const string& line) {
  std::ifstream f("/etc/os-release");
  string l;
  while (std::getline(f, l)) if (l == line) return true;
  return false;
}
string now_iso() {
  char b[40];
  time_t t = time(nullptr);
  struct tm lt{};
  localtime_r(&t, &lt);
  strftime(b, sizeof b, "%Y-%m-%dT%H:%M:%S%z", &lt);
  string s = b;  // match `date -Iseconds` (+hh:mm)
  if (s.size() > 2) s.insert(s.size() - 2, ":");
  return s;
}

void resolve_paths(const char* argv0) {
  std::error_code ec;
  fs::path self = fs::canonical("/proc/self/exe", ec);
  if (ec) self = fs::absolute(argv0);
  fs::path dir = self.parent_path();
  if (fs::is_directory(dir / ".." / "overlay" / "identity", ec)) g_root = fs::canonical(dir / "..", ec);
  else if (fs::is_directory("/usr/lib/vaultos/overlay/identity", ec)) g_root = "/usr/lib/vaultos";
  else g_root = fs::weakly_canonical(dir / "..", ec);
  // Built in src/vaultos/: the checkout is two levels up.
  if (!present(fs::path(g_root) / ".git") && present(dir / ".." / ".." / ".git")) g_root = fs::canonical(dir / ".." / "..", ec);
#ifdef VAULTOS_SRC_ROOT
  // Installed to ~/.local/bin: fall back to the checkout it was built from.
  // The system copy under /usr keeps /usr/lib/vaultos; a user copy follows its checkout.
  if (dir.string().rfind("/usr/", 0) != 0 && present(fs::path(VAULTOS_SRC_ROOT) / ".git"))
    g_root = VAULTOS_SRC_ROOT;
#endif

  const char* lib = std::getenv("VAULTOS_LIB");
  g_lib = lib && *lib ? lib : g_root;
  const char* co = std::getenv("VAULTOS_CHECKOUT");
  if (co && *co) g_checkout = co;
  else if (present(fs::path(g_root) / ".git")) g_checkout = g_root;
  string v = trim(slurp(fs::path(g_lib) / "overlay" / "VERSION"));
  g_version = v.empty() ? "1.5.19" : v;
  g_ident = (fs::path(g_lib) / "overlay" / "identity-apply.sh").string();
  g_pkgsh = (fs::path(g_lib) / "libexec" / "vaultos-packages.sh").string();
  if (!is_exec(g_pkgsh)) g_pkgsh = (fs::path(g_lib) / "overlay" / "libexec" / "vaultos-packages.sh").string();
}

void usage() {
  std::cout << "vaultos " << g_version << " — Vault.OS distro CLI (Arch derivative)\n\n"
            << "  status     Identity, units, network, first-boot stamp\n"
            << "  version    Print overlay version\n"
            << "  doctor     Check identity + units (does not repair XFCE; use vault-os doctor)\n"
            << "  overlay    status|apply|rollback  (Phase 1 identity files)\n"
            << "  packages   Show packages.base / packages.desktop vs installed\n"
            << "  update     git pull + re-apply identity + restart units\n"
            << "             add --syu for pacman -Syu (kernel upgrade; not implied)\n"
            << "  iso        Print ISO path (build with iso/build.sh; does not touch disks)\n"
            << "  firstboot  status | --reset | --run\n"
            << "             --reset removes stamps (next boot runs the wizard).\n"
            << "             --run starts the wizard now (needs a TTY; not for this desktop).\n"
            << "  core       Boot-time state check (what vaultos-core.service runs)\n\n"
            << "Does not change hostname, bootloader, kernel, or partitions unless you\n"
            << "pass firstboot --run (hostname/locale/user on a fresh machine).\n";
}

int cmd_version() {
  std::cout << "vaultos " << g_version << "\nlib " << g_lib << "\n";
  if (!g_checkout.empty() && present(fs::path(g_checkout) / ".git"))
    std::cout << "checkout " << trim(run({"git", "-C", g_checkout, "log", "-1", "--format=%h %s"})) << "\n";
  return 0;
}

int cmd_status() {
  int ec = 0;
  cmd_version();
  std::cout << "───────────────\n";
  if (os_release_has("ID=vaultos") && os_release_has("ID_LIKE=arch"))
    std::cout << "os-release  Vault.OS (ID_LIKE=arch) OK\n";
  else { std::cout << "os-release  NOT vaultos\n"; ec = 1; }
  std::cout << "hostname    " << trim(slurp("/etc/hostname")) << "\n";
  if (present("/var/lib/vaultos/firstboot-done"))
    std::cout << "firstboot   done (" << first_line("/var/lib/vaultos/firstboot-done") << ")\n";
  else std::cout << "firstboot   pending\n";
  if (present("/var/lib/vaultos/firstuser-done")) {
    string s = slurp("/var/lib/vaultos/firstuser-done");
    for (auto& c : s) if (c == '\n') c = ' ';
    std::cout << "firstuser   done (" << s << ")\n";
  } else std::cout << "firstuser   pending (create account on first boot of a fresh install)\n";
  for (const char* u : {"vaultos-core.service", "vaultos-firstboot.service", "vaultos-firstuser.service"}) {
    string en = trim(run({"systemctl", "is-enabled", u}));
    string ac = trim(run({"systemctl", "is-active", u}));
    std::cout << "unit        " << u << " enabled=" << (en.empty() ? "missing" : en)
              << " active=" << (ac.empty() ? "inactive" : ac) << "\n";
  }
  string nm = trim(run({"systemctl", "is-active", "NetworkManager.service"}));
  std::cout << "network     NetworkManager " << (nm.empty() ? "inactive" : nm) << "\n";
  std::cout << "boot        default vaultos-linux.efi; recovery arch-linux-recovery.efi\n";
  return ec;
}

int cmd_doctor() {
  int ec = cmd_status() ? 1 : 0;
  std::cout << "───────────────\n";
  if (!have("pacman")) { std::cout << "pacman      MISSING\n"; ec = 1; }
  int rc = 0;
  run({"pacman-conf"}, &rc);
  if (rc == 0) std::cout << "pacman.conf OK\n";
  else { std::cout << "pacman.conf PARSE_FAIL\n"; ec = 1; }
  std::cout << (is_exec("/usr/lib/vaultos/libexec/vaultos-core.sh") || is_exec("/usr/lib/vaultos/bin/vaultos")
                    ? "core script OK\n" : "core script not installed under /usr/lib/vaultos\n");
  if (present("/usr/lib/os-release")) std::cout << "arch stock  /usr/lib/os-release present (rollback target)\n";
  if (have("vault-os")) {
    std::istringstream v(run({"vault-os", "version"}));
    string a, b;
    v >> a >> b;
    std::cout << "theme CLI   vault-os " << b << "\n";
  }
  std::vector<string> miss;
  if (is_exec(g_pkgsh)) {
    std::istringstream m(run({g_pkgsh, "missing"}));
    string p;
    while (m >> p) miss.push_back(p);
  }
  if (miss.empty()) std::cout << "packages    base+desktop OK\n";
  else {
    std::cout << "packages    missing:\n";
    for (auto& p : miss) std::cout << "            " << p << "\n";
  }
  static const std::regex bad(R"(^\[chaotic|^\[[^\]#].*SigLevel = Optional TrustAll)");
  std::ifstream pc("/etc/pacman.conf");
  string l;
  bool unsigned_repo = false;
  while (std::getline(pc, l)) if (std::regex_search(l, bad)) unsigned_repo = true;
  if (unsigned_repo) { std::cout << "repos       unsigned/chaotic present (unexpected)\n"; ec = 1; }
  else std::cout << "repos       official Arch only OK\n";
  return ec;
}

int cmd_update(const string& arg) {
  bool syu = arg == "--syu" || arg == "--packages";
  if (!g_checkout.empty() && present(fs::path(g_checkout) / ".git")) {
    if (root()) std::cout << "skip git pull as root; run as the checkout owner\n";
    else if (sys({"git", "-C", g_checkout, "pull", "--ff-only"}) != 0) std::cout << "git pull skipped/failed\n";
  }
  if (is_exec(g_ident)) sys({g_ident, "apply"});
  int rc = 0;
  run({"systemctl", "list-unit-files", "vaultos-core.service"}, &rc);
  if (rc == 0) {
    if (root()) sys({"systemctl", "restart", "vaultos-core.service"});
    else if (have("pkexec")) sys({"pkexec", "systemctl", "restart", "vaultos-core.service"});
  }
  std::cout << "package gaps:\n" << std::flush;
  if (is_exec(g_pkgsh)) sys({g_pkgsh, "missing"});
  if (syu) {
    std::cout << "running pacman -Syu (needs root; may upgrade kernel/UKI)\n" << std::flush;
    return root() ? sys({"pacman", "-Syu", "--noconfirm"}) : sys({"pkexec", "pacman", "-Syu", "--noconfirm"});
  }
  std::cout << "skipped pacman -Syu (pass --syu to upgrade all packages)\n";
  return 0;
}

int cmd_iso() {
  fs::path iso = fs::path(g_checkout) / "iso" / "out" / ("vaultos-" + g_version + "-x86_64.iso");
  if (!g_checkout.empty() && present(iso)) {
    std::cout << iso.string() << "\n" << std::flush;
    sys({"ls", "-lh", iso.string()});
    return 0;
  }
  std::cout << "No ISO yet. From the checkout (does not touch host disks):\n  " << g_checkout << "/iso/build.sh\n";
  return 2;
}

int cmd_firstboot(const string& a) {
  const char* stamp = "/var/lib/vaultos/firstboot-done";
  if (a.empty() || a == "status") {
    if (present(stamp)) std::cout << "firstboot-done:\n" << slurp(stamp);
    else std::cout << "firstboot pending (no " << stamp << ")\n";
    return 0;
  }
  if (a == "--reset") {
    if (!root()) { std::cerr << "firstboot --reset needs root\n"; return 1; }
    std::error_code ec;
    fs::remove("/var/lib/vaultos/firstboot-done", ec);
    fs::remove("/var/lib/vaultos/firstuser-done", ec);
    std::cout << "stamps removed; reboot to run the wizard\n";
    return 0;
  }
  if (a == "--run") {
    if (!root()) { std::cerr << "firstboot --run needs root\n"; return 1; }
    std::cerr << "wizard prompts on tty1 (Ctrl-Alt-F1)\n";
    exec({"/usr/lib/vaultos/libexec/vaultos-firstuser.sh"});
  }
  std::cerr << "usage: vaultos firstboot [status|--reset|--run]\n";
  return 2;
}

// What vaultos-core.service runs at boot. Never fails the boot.
int cmd_core() {
  std::error_code ec;
  fs::create_directories("/var/lib/vaultos", ec);
  {
    std::ofstream st("/var/lib/vaultos/core-state");
    if (st) st << "version=" << g_version << "\nchecked=" << now_iso() << "\nid=" << os_release_id() << "\n";
  }
  if (is_exec(g_ident) && os_release_id() != "vaultos") {
    pid_t pid = fork();
    if (pid == 0) {
      int fd = open("/var/log/vaultos-core-identity.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
      if (fd >= 0) { dup2(fd, 1); dup2(fd, 2); }
      execl(g_ident.c_str(), g_ident.c_str(), "apply", nullptr);
      _exit(127);
    }
    int s;
    waitpid(pid, &s, 0);
  }
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
  resolve_paths(argv[0]);
  string cmd = argc > 1 ? argv[1] : "status";
  string arg = argc > 2 ? argv[2] : "";
  if (cmd == "status" || cmd == "st") return cmd_status();
  if (cmd == "version" || cmd == "-V" || cmd == "--version") return cmd_version();
  if (cmd == "doctor") return cmd_doctor();
  if (cmd == "overlay") {
    if (!is_exec(g_ident)) { std::cerr << "missing " << g_ident << "\n"; return 2; }
    exec({g_ident, arg.empty() ? "status" : arg});
  }
  if (cmd == "packages") {
    if (!is_exec(g_pkgsh)) { std::cerr << "missing vaultos-packages.sh\n"; return 2; }
    exec({g_pkgsh, arg.empty() ? "status" : arg});
  }
  if (cmd == "update") return cmd_update(arg);
  if (cmd == "iso") return cmd_iso();
  if (cmd == "firstboot") return cmd_firstboot(arg);
  if (cmd == "core") return cmd_core();
  if (cmd == "-h" || cmd == "--help" || cmd == "help") { usage(); return 0; }
  usage();
  return 2;
}

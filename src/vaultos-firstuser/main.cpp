// vaultos-firstuser — first boot on a fresh install: create the login account.
// Runs on the console before LightDM. Never on the live ISO, never when a
// normal user already exists. Doesn't touch disks, bootloader or hostname.
// Passwords go through passwd(1) so PAM handles hashing.
//
//   --dry-run   show the screen and validate input, change nothing
#include <grp.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <unistd.h>
#include <cctype>
#include <cstdio>
#include <ctime>
#include <fstream>
#include <iostream>
#include <regex>
#include <string>
#include <thread>
#include <vector>

using std::string;

namespace {

const char* kStamp = "/var/lib/vaultos/firstuser-done";
const char* kLog = "/var/log/vaultos-firstuser.log";
bool g_dry = false;

const char* G = "\033[38;2;26;255;107m";   // phosphor #1AFF6B
const char* D = "\033[38;2;20;150;70m";    // dim phosphor
const char* S = "\033[38;2;138;143;134m";  // steel
const char* R = "\033[0m";

string now_iso() {
  char b[40];
  time_t t = time(nullptr);
  struct tm lt{};
  localtime_r(&t, &lt);
  strftime(b, sizeof b, "%Y-%m-%dT%H:%M:%S%z", &lt);
  string s = b;
  if (s.size() > 2) s.insert(s.size() - 2, ":");
  return s;
}

void log(const string& m) {
  if (g_dry) return;
  std::ofstream f(kLog, std::ios::app);
  f << "vaultos-firstuser " << now_iso() << " " << m << "\n";
}

[[noreturn]] void stamp_and_exit(const string& reason, const string& user = "") {
  if (!g_dry) {
    mkdir("/var/lib/vaultos", 0755);
    std::ofstream f(kStamp);
    f << "done=" << now_iso() << "\nreason=" << reason << "\nuser=" << user << "\n";
    f.close();
    chmod(kStamp, 0644);
    log("stamped " + string(kStamp) + " (" + reason + ")");
  } else {
    std::cout << D << "[dry-run] would stamp " << kStamp << " reason=" << reason << " user=" << user << R << "\n";
  }
  std::exit(0);
}

bool exists(const char* p) { struct stat st; return stat(p, &st) == 0; }

string first_login_user() {
  setpwent();
  string found;
  while (passwd* pw = getpwent()) {
    if (pw->pw_uid >= 1000 && pw->pw_uid < 65534) { found = pw->pw_name; break; }
  }
  endpwent();
  return found;
}

bool reserved(const string& u) {
  static const char* names[] = {"root", "daemon", "bin", "sys", "sync", "games", "man", "lp", "mail", "news",
                                "uucp", "proxy", "www-data", "backup", "nobody", "nfsnobody", "nobody4",
                                "nogroup", "vaultos-live", "guest"};
  for (auto n : names) if (u == n) return true;
  return u.rfind("systemd-", 0) == 0;
}

bool valid_name(const string& u) {
  static const std::regex re("^[a-z_][a-z0-9_-]{0,31}$");
  return std::regex_match(u, re) && !reserved(u) && getpwnam(u.c_str()) == nullptr;
}

int run(const std::vector<string>& argv) {
  if (g_dry) {
    std::cout << D << "[dry-run]";
    for (auto& a : argv) std::cout << " " << a;
    std::cout << R << "\n";
    return 0;
  }
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

void type(const string& s, int ms = 14) {
  for (char c : s) {
    std::cout << c << std::flush;
    if (c != ' ') std::this_thread::sleep_for(std::chrono::milliseconds(ms));
  }
}

void banner() {
  std::cout << "\033[2J\033[H" << G;
  type("\n  VAULT-TEC INDUSTRIES (TM) TERMLINK PROTOCOL\n", 10);
  std::cout << D;
  type("  ENTERING OVERSEER REGISTRATION . . .\n\n", 18);
  std::cout << S << "  ──────────────────────────────────────────\n" << R;
  std::cout << G << "  Vault.OS" << R << S << "  first boot\n" << R << "\n";
  std::cout << "  Create the account you'll log in with.\n"
            << S << "  Lowercase letters, digits, _ or -  (not root).\n\n" << R;
}

}  // namespace

int main(int argc, char** argv) {
  for (int i = 1; i < argc; ++i) if (string(argv[i]) == "--dry-run") g_dry = true;
  if (!g_dry) { mkdir("/var/lib/vaultos", 0755); mkdir("/var/log", 0755); }

  if (!g_dry) {
    if (exists("/run/archiso")) stamp_and_exit("live");
    if (exists(kStamp)) { log("already stamped"); return 0; }
    string existing = first_login_user();
    if (!existing.empty()) stamp_and_exit("existing-user", existing);
    // Take the console so LightDM waits (Before=display-manager).
    int fd = open("/dev/console", O_RDWR);
    if (fd >= 0) { dup2(fd, 0); dup2(fd, 1); dup2(fd, 2); if (fd > 2) close(fd); }
    run({"plymouth", "quit"});
  }

  banner();
  string user;
  for (;;) {
    std::cout << G << "  OVERSEER NAME > " << R << std::flush;
    if (!std::getline(std::cin, user)) { std::cout << "\n"; return 1; }
    string clean;
    for (char c : user) if (c != ' ') clean += char(std::tolower(static_cast<unsigned char>(c)));
    user = clean;
    if (valid_name(user)) break;
    std::cout << "  \033[38;2;255;176;0mThat name isn't available. Try another.\033[0m\n";
  }

  string groups = "wheel";
  for (const char* g : {"audio", "video", "storage", "lp", "network", "optical", "input"})
    if (getgrnam(g)) groups += string(",") + g;

  if (run({"useradd", "-m", "-G", groups, "-s", "/bin/bash", user}) != 0) {
    std::cout << "  useradd failed, see " << kLog << "\n";
    log("useradd failed for " + user);
    return 1;
  }
  if (!g_dry) {
    std::ofstream w("/etc/sudoers.d/wheel");
    w << "%wheel ALL=(ALL:ALL) ALL\n";
    w.close();
    chmod("/etc/sudoers.d/wheel", 0440);
  }

  std::cout << "\n  Set a password for " << G << user << R << " (you'll type it twice).\n";
  while (run({"passwd", user}) != 0) std::cout << "  Password not set, try again.\n";

  std::cout << "\n" << G;
  type("  WELCOME TO VAULT.OS, OVERSEER " + [&] { string u = user; for (auto& c : u) c = char(std::toupper(c)); return u; }() + ".\n", 22);
  std::cout << D << "  Continuing to login . . .\n" << R;
  std::this_thread::sleep_for(std::chrono::seconds(1));
  stamp_and_exit("created", user);
}

// vaultos-firstuser — first boot on a fresh install: create the login account.
// Runs on the console before LightDM. Never on the live ISO, never when a
// normal user already exists. Doesn't touch disks, bootloader or hostname.
// Passwords go through passwd(1) so PAM handles hashing.
//
//   --dry-run   show the screen and validate input, change nothing
//
// Any failure or signal after useradd removes the half-made account again
// (userdel -r), so the next boot prompts instead of treating it as an
// existing user. Typeahead is flushed before every prompt so keys pressed
// during the banner or a slow step never land in the name or password.
//
// Test hook (only with --dry-run): VAULTOS_FIRSTUSER_TEST_FAIL=useradd|passwd
// makes that dry-run step fail, to exercise the rollback path.
#include <grp.h>
#include <signal.h>
#include <termios.h>
#include <pwd.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <unistd.h>
#include <cctype>
#include <cstdio>
#include <cstdlib>
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
const char* g_test_fail = nullptr;  // dry-run only, see header

// Rollback state. Plain C buffers so the signal handler can use them.
char g_created[33] = "";      // user made by useradd this run, "" if none
volatile sig_atomic_t g_stamped = 0;
bool g_tty_saved = false;
struct termios g_tty{};

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
  g_stamped = 1;  // commit point: never roll back after this
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
    if (g_test_fail && !argv.empty() && argv[0] == g_test_fail) return 1;
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

// Throw away anything typed ahead (during the banner, useradd, ...) so it is
// never taken as the next answer, and put echo back if passwd left it off.
void drain_input() {
  if (!isatty(0)) return;
  tcflush(0, TCIFLUSH);
  if (g_tty_saved) tcsetattr(0, TCSANOW, &g_tty);
}

// Remove the account this run created. Async-signal-safe (fork/execv/waitpid
// and write only), so the signal handler can call it too.
void rollback_user() {
  if (g_stamped || g_created[0] == '\0') return;
  if (g_dry) {
    const char m[] = "[dry-run] rollback: userdel -r ";
    ssize_t r = write(1, m, sizeof m - 1);
    r = write(1, g_created, strlen(g_created));
    r = write(1, "\n", 1);
    (void)r;
    g_created[0] = '\0';
    return;
  }
  pid_t pid = fork();
  if (pid == 0) {
    char* const a[] = {const_cast<char*>("userdel"), const_cast<char*>("-r"), g_created, nullptr};
    execv("/usr/sbin/userdel", a);
    execv("/usr/bin/userdel", a);
    _exit(127);
  }
  if (pid > 0) { int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {} }
  g_created[0] = '\0';
}

void on_signal(int sig) {
  if (g_tty_saved) tcsetattr(0, TCSANOW, &g_tty);
  bool had = g_created[0] != '\0' && !g_stamped;
  rollback_user();
  const char m[] = "\n  Setup cancelled. Reboot to try again.\n";
  ssize_t r = write(1, m, sizeof m - 1);
  (void)r;
  if (had && !g_dry) {
    int fd = open(kLog, O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (fd >= 0) { const char l[] = "vaultos-firstuser interrupted; new user rolled back\n"; r = write(fd, l, sizeof l - 1); close(fd); }
  }
  _exit(128 + sig);
}

[[noreturn]] void fail_exit(const string& why) {
  log("fail: " + why);
  std::cout << std::flush;
  rollback_user();
  if (!why.empty()) std::cout << "  " << why << ", see " << kLog << "\n";
  std::cout << "  Setup failed. Reboot to try again.\n";
  std::exit(1);
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
  if (g_dry) g_test_fail = std::getenv("VAULTOS_FIRSTUSER_TEST_FAIL");
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
  if (isatty(0) && tcgetattr(0, &g_tty) == 0) g_tty_saved = true;
  struct sigaction sa{};
  sa.sa_handler = on_signal;
  sigemptyset(&sa.sa_mask);
  for (int sig : {SIGINT, SIGTERM, SIGHUP, SIGQUIT}) sigaction(sig, &sa, nullptr);

  banner();
  string user;
  for (;;) {
    drain_input();
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

  // Block the cancel signals across useradd so we always know whether the
  // account exists by the time a handler can run.
  sigset_t block, old;
  sigemptyset(&block);
  for (int sig : {SIGINT, SIGTERM, SIGHUP, SIGQUIT}) sigaddset(&block, sig);
  sigprocmask(SIG_BLOCK, &block, &old);
  int rc = run({"useradd", "-m", "-G", groups, "-s", "/bin/bash", user});
  // useradd may have made the account even if it then failed (e.g. home copy).
  if (rc == 0 || (!g_dry && getpwnam(user.c_str()) != nullptr))
    snprintf(g_created, sizeof g_created, "%s", user.c_str());
  sigprocmask(SIG_SETMASK, &old, nullptr);
  if (rc != 0) fail_exit("useradd failed for " + user);
  log("created " + user);

  if (!g_dry) {
    std::ofstream w("/etc/sudoers.d/wheel");
    w << "%wheel ALL=(ALL:ALL) ALL\n";
    w.close();
    if (!w || chmod("/etc/sudoers.d/wheel", 0440) != 0) fail_exit("could not write /etc/sudoers.d/wheel");
  }

  std::cout << "\n  Set a password for " << G << user << R << " (you'll type it twice).\n";
  for (int tries = 1;; ++tries) {
    drain_input();
    if (run({"passwd", user}) == 0) break;
    if (tries >= 5) fail_exit("password not set after 5 tries");
    std::cout << "  Password not set, try again.\n";
  }

  std::cout << "\n" << G;
  type("  WELCOME TO VAULT.OS, OVERSEER " + [&] { string u = user; for (auto& c : u) c = char(std::toupper(c)); return u; }() + ".\n", 22);
  std::cout << D << "  Continuing to login . . .\n" << R;
  std::this_thread::sleep_for(std::chrono::seconds(1));
  stamp_and_exit("created", user);
}

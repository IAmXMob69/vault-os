// vaultos-boot — native ports of two boot-time helpers:
//   vaultos-boot core       == overlay/libexec/vaultos-core.sh
//   vaultos-boot identity   == overlay/libexec/vaultos-firstboot.sh
// Same files, same contents, same log lines. Neither ever fails the boot:
// both exit 0 whatever happens. VAULTOS_TEST_ROOT prefixes every path and
// skips systemctl and identity-apply, exactly like the scripts.
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

#include "proc.hpp"
#include "text.hpp"

namespace {

using namespace vaultos;

std::string env(const char* k, const char* def = "") {
  const char* v = getenv(k);
  return v ? std::string(v) : std::string(def);
}
// ${VAR:-def}
std::string env_or(const char* k, const char* def) {
  const char* v = getenv(k);
  return (v && *v) ? std::string(v) : std::string(def);
}

// mkdir -p (errors ignored, like set +e).
void mkdir_p(const std::string& path) {
  if (path.empty()) return;
  std::string cur;
  size_t i = 0;
  if (path[0] == '/') { cur = "/"; i = 1; }
  while (i <= path.size()) {
    size_t j = path.find('/', i);
    if (j == std::string::npos) j = path.size();
    if (j > i) {
      if (!cur.empty() && cur.back() != '/') cur += '/';
      cur += path.substr(i, j - i);
      mkdir(cur.c_str(), 0777);
    }
    i = j + 1;
  }
}

// `>file`: O_TRUNC, new files get 0666 & ~umask, existing keep their mode.
bool put(const std::string& path, const std::string& data, const char* who) {
  int fd = open(path.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0666);
  if (fd < 0) {
    fprintf(stderr, "%s: %s: %s\n", who, path.c_str(), strerror(errno));
    return false;
  }
  const char* p = data.data();
  size_t left = data.size();
  while (left > 0) {
    ssize_t w = write(fd, p, left);
    if (w < 0 && errno == EINTR) continue;
    if (w <= 0) break;
    p += w;
    left -= size_t(w);
  }
  close(fd);
  return true;
}

// awk -F= '/^ID=/{print $2; exit}' FILE 2>/dev/null
std::string os_id(const std::string& file) {
  std::string s;
  if (!slurp(file, s)) return "";
  for (const auto& l : lines(s)) {
    if (!starts_with(l, "ID=")) continue;
    size_t e = l.find('=', 3);
    return l.substr(3, e == std::string::npos ? std::string::npos : e - 3);
  }
  return "";
}

// grep -q '^ID=vaultos$' FILE 2>/dev/null
bool is_vaultos(const std::string& file) {
  std::string s;
  if (!slurp(file, s)) return false;
  for (const auto& l : lines(s))
    if (l == "ID=vaultos") return true;
  return false;
}

// [[ -x PATH ]]
bool is_exec(const std::string& p) { return access(p.c_str(), X_OK) == 0; }

// tr -d '\n' <FILE
std::string version_of(const std::string& lib) {
  std::string ver = "unknown", s;
  for (const char* f : {"/overlay/VERSION", "/VERSION"}) {
    std::string p = lib + f;
    if (is_reg(p) && slurp(p, s)) {
      ver.clear();
      for (char c : s) if (c != '\n') ver += c;
    }
  }
  return ver;
}

// Run argv with stdout+stderr sent to fd (inherited when fd < 0).
int run_to(const std::vector<std::string>& argv, int fd) {
  if (fd < 0) return run(argv);
  fflush(stdout);
  fflush(stderr);
  int so = dup(1), se = dup(2);
  dup2(fd, 1);
  dup2(fd, 2);
  int rc = run(argv);
  dup2(so, 1);
  dup2(se, 2);
  close(so);
  close(se);
  return rc;
}

int cmd_core() {
  const std::string P = env("VAULTOS_TEST_ROOT");
  const std::string lib = env_or("VAULTOS_LIB", "/usr/lib/vaultos");
  mkdir_p(P + "/var/lib/vaultos");
  const std::string osr = P + "/etc/os-release";
  std::string st = "version=" + version_of(lib) + "\n";
  st += "checked=" + now_iso() + "\n";
  st += "id=" + os_id(osr) + "\n";
  put(P + "/var/lib/vaultos/core-state", st, "vaultos-core");

  const std::string ia = lib + "/overlay/identity-apply.sh";
  if (is_exec(ia) && !is_vaultos(osr)) {
    if (!P.empty()) {
      printf("test: skip identity-apply\n");
    } else {
      const std::string log = "/var/log/vaultos-core-identity.log";
      int fd = open(log.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0666);
      if (fd < 0) fprintf(stderr, "vaultos-core: %s: %s\n", log.c_str(), strerror(errno));
      else { run_to({ia, "apply"}, fd); close(fd); }
    }
  }
  fflush(stdout);
  return 0;
}

int cmd_identity() {
  const std::string P = env("VAULTOS_TEST_ROOT");
  const std::string lib = env_or("VAULTOS_LIB", "/usr/lib/vaultos");
  const std::string stamp = P + "/var/lib/vaultos/identity-applied";
  mkdir_p(P + "/var/lib/vaultos");
  mkdir_p(P + "/var/log");
  const std::string log = P + "/var/log/vaultos-firstboot.log";
  int fd = open(log.c_str(), O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0666);
  if (fd >= 0) {  // exec >>LOG 2>&1
    dup2(fd, 1);
    dup2(fd, 2);
    close(fd);
  } else {
    fprintf(stderr, "vaultos-firstboot: %s: %s\n", log.c_str(), strerror(errno));
  }
  setvbuf(stdout, nullptr, _IOLBF, 0);
  printf("vaultos-firstboot-identity %s\n", now_iso().c_str());

  struct stat sb;
  if (stat(stamp.c_str(), &sb) == 0 && S_ISREG(sb.st_mode)) {
    printf("already stamped: %s\n", stamp.c_str());
    return 0;
  }

  if (P.empty()) {
    RunOpts q;
    q.quiet_out = q.quiet_err = true;
    if (run({"systemctl", "list-unit-files", "NetworkManager.service"}, q) == 0) {
      run({"systemctl", "enable", "NetworkManager.service"}, q);
      run({"systemctl", "start", "NetworkManager.service"}, q);
    }
  }

  const std::string osr = P + "/etc/os-release";
  const std::string ia = lib + "/overlay/identity-apply.sh";
  if (is_exec(ia) && !is_vaultos(osr)) {
    if (!P.empty()) printf("test: skip identity-apply\n");
    else { fflush(stdout); run({ia, "apply"}); }
  }

  std::string st = "done=" + now_iso() + "\n";
  st += "id=" + os_id(osr) + "\n";
  put(stamp, st, "vaultos-firstboot");
  chmod(stamp.c_str(), 0644);  // unconditional, like the script
  printf("stamped %s\n", stamp.c_str());
  return 0;
}

void usage(FILE* f) {
  fputs("usage: vaultos-boot core|identity\n"
        "  core       record /var/lib/vaultos/core-state; apply identity if missing\n"
        "  identity   first-boot identity stamp (vaultos-firstboot.service)\n"
        "Both always exit 0. VAULTOS_TEST_ROOT=DIR runs against a fake root.\n", f);
}

}  // namespace

int main(int argc, char** argv) {
  std::string cmd = argc > 1 ? argv[1] : "";
  if (cmd == "core") return cmd_core();
  if (cmd == "identity" || cmd == "firstboot") return cmd_identity();
  if (cmd == "-h" || cmd == "--help" || cmd == "help") { usage(stdout); return 0; }
  usage(stderr);
  return 2;
}

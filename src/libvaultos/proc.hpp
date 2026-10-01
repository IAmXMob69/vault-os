// libvaultos/proc.hpp — run helpers without a shell. Header-only, no deps.
//
//   find_in_path("visudo")          "" when not on $PATH (like command -v)
//   run({"nmcli", "-t", ...}, opt)  exit status; 127 not found, 128+N on signal
//
// A signal that interrupts waitpid() does not abandon the child: we keep
// waiting, so the caller always knows the child is gone before it decides
// what to do (roll back, retry, ...). The child gets default SIGPIPE.
#pragma once
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cerrno>
#include <cstdlib>
#include <string>
#include <vector>

namespace vaultos {

inline bool is_exec_file(const std::string& p) {
  struct stat st;
  return stat(p.c_str(), &st) == 0 && S_ISREG(st.st_mode) && access(p.c_str(), X_OK) == 0;
}

inline std::string find_in_path(const std::string& name) {
  if (name.empty()) return "";
  if (name.find('/') != std::string::npos) return is_exec_file(name) ? name : "";
  const char* env = std::getenv("PATH");
  std::string path = env ? env : "/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin";
  size_t start = 0;
  for (;;) {
    size_t end = path.find(':', start);
    std::string dir = path.substr(start, end == std::string::npos ? std::string::npos : end - start);
    if (dir.empty()) dir = ".";
    std::string cand = dir + "/" + name;
    if (is_exec_file(cand)) return cand;
    if (end == std::string::npos) break;
    start = end + 1;
  }
  return "";
}

inline bool have(const std::string& name) { return !find_in_path(name).empty(); }

struct RunOpts {
  const std::string* input = nullptr;  // fed on stdin (then closed); else stdin is inherited
  std::string* output = nullptr;       // capture stdout here
  bool quiet_out = false;              // stdout -> /dev/null (ignored if output is set)
  bool quiet_err = false;              // stderr -> /dev/null
  bool null_in = false;                // stdin <- /dev/null
};

inline int run(const std::vector<std::string>& argv, const RunOpts& o = RunOpts()) {
  if (argv.empty()) return 127;
  int in_p[2] = {-1, -1}, out_p[2] = {-1, -1};
  if (o.input && pipe2(in_p, O_CLOEXEC) != 0) return 127;
  if (o.output && pipe2(out_p, O_CLOEXEC) != 0) return 127;
  pid_t pid = fork();
  if (pid < 0) return 127;
  if (pid == 0) {
    signal(SIGPIPE, SIG_DFL);
    if (o.input) dup2(in_p[0], 0);
    else if (o.null_in) { int n = open("/dev/null", O_RDONLY); if (n >= 0) dup2(n, 0); }
    if (o.output) dup2(out_p[1], 1);
    else if (o.quiet_out) { int n = open("/dev/null", O_WRONLY); if (n >= 0) dup2(n, 1); }
    if (o.quiet_err) { int n = open("/dev/null", O_WRONLY); if (n >= 0) dup2(n, 2); }
    std::vector<char*> a;
    for (const auto& s : argv) a.push_back(const_cast<char*>(s.c_str()));
    a.push_back(nullptr);
    execvp(a[0], a.data());
    _exit(127);
  }
  if (o.input) {
    close(in_p[0]);
    const char* p = o.input->data();
    size_t left = o.input->size();
    while (left > 0) {
      ssize_t w = write(in_p[1], p, left);
      if (w < 0 && errno == EINTR) continue;
      if (w <= 0) break;  // EPIPE: child did not want it all
      p += w;
      left -= size_t(w);
    }
    close(in_p[1]);
  }
  if (o.output) {
    close(out_p[1]);
    char buf[4096];
    for (;;) {
      ssize_t r = read(out_p[0], buf, sizeof buf);
      if (r < 0 && errno == EINTR) continue;
      if (r <= 0) break;
      o.output->append(buf, size_t(r));
    }
    close(out_p[0]);
  }
  int st = 0;
  while (waitpid(pid, &st, 0) < 0) {
    if (errno != EINTR) return 127;
  }
  if (WIFEXITED(st)) return WEXITSTATUS(st);
  if (WIFSIGNALED(st)) return 128 + WTERMSIG(st);
  return 1;
}

// stdout of a command ("" on failure), like $(cmd 2>/dev/null).
inline std::string capture(const std::vector<std::string>& argv, int* rc = nullptr) {
  std::string out;
  RunOpts o;
  o.output = &out;
  o.quiet_err = true;
  o.null_in = true;
  int r = run(argv, o);
  if (rc) *rc = r;
  return out;
}

}  // namespace vaultos

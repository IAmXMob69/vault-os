// libvaultos/instance_lock.hpp — single-instance guard via flock(2).
// The kernel drops the lock when the process dies, so no stale pid files.
#pragma once
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cctype>
#include <string>
#include "paths.hpp"

namespace vaultos {

class InstanceLock {
 public:
  // name "vaultos-mark-desktop" -> $XDG_CACHE_HOME/vaultos-mark-desktop.lock
  explicit InstanceLock(const std::string& name) {
    std::string dir = cache_home();
    mkdir(dir.c_str(), 0700);
    path_ = dir + "/" + sanitize(name) + ".lock";
    fd_ = open(path_.c_str(), O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (fd_ >= 0 && flock(fd_, LOCK_EX | LOCK_NB) != 0) {
      close(fd_);
      fd_ = -1;
    }
  }
  ~InstanceLock() {
    if (fd_ >= 0) close(fd_);
  }
  InstanceLock(const InstanceLock&) = delete;
  InstanceLock& operator=(const InstanceLock&) = delete;

  bool held() const { return fd_ >= 0; }
  const std::string& path() const { return path_; }

  static std::string sanitize(const std::string& s) {
    std::string out;
    for (char c : s)
      out += (std::isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_') ? c : '-';
    return out.empty() ? "default" : out;
  }

 private:
  int fd_ = -1;
  std::string path_;
};

}  // namespace vaultos

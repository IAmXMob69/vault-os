// libvaultos/paths.hpp — where Vault.OS keeps things. Header-only, no deps.
#pragma once
#include <pwd.h>
#include <unistd.h>
#include <cstdlib>
#include <fstream>
#include <string>

namespace vaultos {

inline std::string home() {
  if (const char* h = std::getenv("HOME"); h && *h) return h;
  if (const passwd* pw = getpwuid(getuid()); pw && pw->pw_dir) return pw->pw_dir;
  return ".";
}

inline std::string xdg(const char* var, const char* fallback_rel) {
  if (const char* v = std::getenv(var); v && *v == '/') return v;
  return home() + "/" + fallback_rel;
}

inline std::string config_home() { return xdg("XDG_CONFIG_HOME", ".config"); }
inline std::string data_home() { return xdg("XDG_DATA_HOME", ".local/share"); }
inline std::string cache_home() { return xdg("XDG_CACHE_HOME", ".cache"); }

// ~/.config/Vault.OS holds desktop-spin, overseer, terminal-phosphor, ...
// Fixed under $HOME to match the existing scripts (not XDG_CONFIG_HOME).
inline std::string vault_config_dir() { return home() + "/.config/Vault.OS"; }
inline std::string backgrounds_dir() { return home() + "/.local/share/backgrounds/Vault.OS"; }
inline std::string local_bin() { return home() + "/.local/bin"; }

// First line of a small state file, trailing whitespace trimmed.
inline std::string read_line(const std::string& path, const std::string& fallback = "") {
  std::ifstream f(path);
  std::string s;
  if (f && std::getline(f, s)) {
    while (!s.empty() && (s.back() == ' ' || s.back() == '\r' || s.back() == '\t')) s.pop_back();
    if (!s.empty()) return s;
  }
  return fallback;
}

inline bool is_file(const std::string& p) { return access(p.c_str(), R_OK) == 0; }

}  // namespace vaultos

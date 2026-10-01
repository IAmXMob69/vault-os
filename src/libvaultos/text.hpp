// libvaultos/text.hpp — small string and file helpers. Header-only, no deps.
#pragma once
#include <sys/stat.h>
#include <unistd.h>
#include <cctype>
#include <cstdio>
#include <ctime>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace vaultos {

inline std::string lower(std::string s) {
  for (auto& c : s) c = char(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

inline std::string upper(std::string s) {
  for (auto& c : s) c = char(std::toupper(static_cast<unsigned char>(c)));
  return s;
}

inline bool starts_with(const std::string& s, const std::string& p) { return s.compare(0, p.size(), p) == 0; }
inline bool ends_with(const std::string& s, const std::string& p) {
  return s.size() >= p.size() && s.compare(s.size() - p.size(), p.size(), p) == 0;
}
inline bool contains(const std::string& s, const std::string& n) { return s.find(n) != std::string::npos; }

// Like "$(cat f)": all trailing newlines removed.
inline std::string chomp(std::string s) {
  while (!s.empty() && s.back() == '\n') s.pop_back();
  return s;
}

inline std::string trim(const std::string& s) {
  size_t b = 0, e = s.size();
  while (b < e && std::isspace(static_cast<unsigned char>(s[b]))) ++b;
  while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1]))) --e;
  return s.substr(b, e - b);
}

inline std::vector<std::string> split(const std::string& s, char sep) {
  std::vector<std::string> out;
  size_t start = 0;
  for (;;) {
    size_t e = s.find(sep, start);
    out.push_back(s.substr(start, e == std::string::npos ? std::string::npos : e - start));
    if (e == std::string::npos) break;
    start = e + 1;
  }
  return out;
}

// Lines of a text blob; a trailing newline does not add an empty line.
inline std::vector<std::string> lines(const std::string& s) {
  std::vector<std::string> out = split(s, '\n');
  if (!out.empty() && out.back().empty()) out.pop_back();
  return out;
}

inline std::vector<std::string> words(const std::string& s) {
  std::vector<std::string> out;
  std::istringstream in(s);
  std::string w;
  while (in >> w) out.push_back(w);
  return out;
}

inline bool slurp(const std::string& path, std::string& out) {
  std::ifstream f(path, std::ios::binary);
  if (!f) return false;
  std::ostringstream ss;
  ss << f.rdbuf();
  out = ss.str();
  return true;
}

inline std::string slurp(const std::string& path) {
  std::string s;
  slurp(path, s);
  return s;
}

inline bool path_exists(const std::string& p) { struct stat st; return lstat(p.c_str(), &st) == 0; }
inline bool is_dir(const std::string& p) { struct stat st; return stat(p.c_str(), &st) == 0 && S_ISDIR(st.st_mode); }
inline bool is_reg(const std::string& p) { struct stat st; return stat(p.c_str(), &st) == 0 && S_ISREG(st.st_mode); }
inline bool is_link(const std::string& p) { struct stat st; return lstat(p.c_str(), &st) == 0 && S_ISLNK(st.st_mode); }

inline std::string read_link(const std::string& p) {
  char b[4096];
  ssize_t n = readlink(p.c_str(), b, sizeof b - 1);
  if (n < 0) return "";
  return std::string(b, size_t(n));
}

// date -Iseconds: 2026-09-30T22:46:33-04:00
inline std::string now_iso() {
  char b[40];
  time_t t = time(nullptr);
  struct tm lt {};
  localtime_r(&t, &lt);
  strftime(b, sizeof b, "%Y-%m-%dT%H:%M:%S%z", &lt);
  std::string s = b;
  if (s.size() > 2) s.insert(s.size() - 2, ":");
  return s;
}

}  // namespace vaultos

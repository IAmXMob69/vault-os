// vaultos-hud — one-shot status readout for the xfce4-genmon panel plugin.
// Prints CPU and memory as a terse phosphor line plus a tooltip with uptime,
// load and kernel. Runs in well under a millisecond and exits, so genmon can
// poll it every couple of seconds without costing anything.
// CPU is a delta against the previous sample, kept in $XDG_RUNTIME_DIR.
#include <sys/utsname.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

namespace {

struct CpuSample { unsigned long long idle = 0, total = 0; };

CpuSample read_cpu() {
  CpuSample s;
  std::ifstream f("/proc/stat");
  std::string tag;
  unsigned long long v[10] = {};
  f >> tag;
  for (int i = 0; i < 10 && (f >> v[i]); ++i) s.total += v[i];
  s.idle = v[3] + v[4];  // idle + iowait
  return s;
}

std::string state_path() {
  const char* rt = std::getenv("XDG_RUNTIME_DIR");
  return std::string(rt && *rt ? rt : "/tmp") + "/vaultos-hud.stat";
}

int cpu_percent() {
  CpuSample now = read_cpu(), prev;
  const std::string path = state_path();
  bool have_prev = false;
  if (FILE* in = std::fopen(path.c_str(), "r")) {
    have_prev = std::fscanf(in, "%llu %llu", &prev.idle, &prev.total) == 2;
    std::fclose(in);
  }
  if (FILE* out = std::fopen(path.c_str(), "w")) {
    std::fprintf(out, "%llu %llu\n", now.idle, now.total);
    std::fclose(out);
  }
  if (!have_prev || now.total <= prev.total) return 0;
  const double dt = double(now.total - prev.total);
  const double di = double(now.idle - prev.idle);
  int p = int((1.0 - di / dt) * 100.0 + 0.5);
  return p < 0 ? 0 : (p > 99 ? 99 : p);
}

void read_mem(long& used_mb, long& total_mb) {
  std::ifstream f("/proc/meminfo");
  std::string key;
  long val = 0, total = 0, avail = 0;
  std::string unit;
  while (f >> key >> val) {
    std::getline(f, unit);
    if (key == "MemTotal:") total = val;
    else if (key == "MemAvailable:") { avail = val; break; }
  }
  total_mb = total / 1024;
  used_mb = (total - avail) / 1024;
}

std::string uptime_str() {
  double up = 0;
  if (FILE* f = std::fopen("/proc/uptime", "r")) {
    if (std::fscanf(f, "%lf", &up) != 1) up = 0;
    std::fclose(f);
  }
  long m = long(up) / 60, d = m / 1440, h = (m / 60) % 24;
  m %= 60;
  char buf[48];
  if (d) std::snprintf(buf, sizeof buf, "%ldd %02ldh %02ldm", d, h, m);
  else std::snprintf(buf, sizeof buf, "%02ldh %02ldm", h, m);
  return buf;
}

std::string overseer() {
  std::string name = "VAULT DWELLER";
  if (const char* home = std::getenv("HOME")) {
    std::ifstream f(std::string(home) + "/.config/Vault.OS/overseer");
    std::string line;
    if (std::getline(f, line) && !line.empty()) name = line;
  }
  // genmon parses Pango markup, so keep the name markup-safe.
  std::string safe;
  for (char c : name) {
    if (c == '&') safe += "&amp;";
    else if (c == '<') safe += "&lt;";
    else if (c == '>') safe += "&gt;";
    else safe += c;
  }
  return safe;
}

}  // namespace

int main(int argc, char** argv) {
  const bool plain = argc > 1 && std::strcmp(argv[1], "--plain") == 0;
  const int cpu = cpu_percent();
  long used = 0, total = 0;
  read_mem(used, total);
  const int mem = total ? int(used * 100 / total) : 0;

  // Amber only when something is actually under load; phosphor otherwise.
  const char* cpu_col = cpu >= 85 ? "#FFB000" : "#66FF9C";
  const char* mem_col = mem >= 85 ? "#FFB000" : "#66FF9C";

  if (plain) {
    std::printf("CPU %02d  MEM %02d\n", cpu, mem);
    return 0;
  }

  double l1 = 0, l5 = 0, l15 = 0;
  if (FILE* f = std::fopen("/proc/loadavg", "r")) {
    if (std::fscanf(f, "%lf %lf %lf", &l1, &l5, &l15) != 3) l1 = l5 = l15 = 0;
    std::fclose(f);
  }
  struct utsname u {};
  uname(&u);

  std::printf(
      "<txt><span font_family='Share Tech Mono' foreground='#0E8A3A'>CPU </span>"
      "<span font_family='Share Tech Mono' foreground='%s'>%02d</span>"
      "<span font_family='Share Tech Mono' foreground='#0E8A3A'>  MEM </span>"
      "<span font_family='Share Tech Mono' foreground='%s'>%02d</span></txt>\n",
      cpu_col, cpu, mem_col, mem);
  std::printf(
      "<tool><span font_family='Share Tech Mono'>OVERSEER %s\n"
      "UPTIME   %s\nLOAD     %.2f  %.2f  %.2f\nMEMORY   %ld / %ld MB\nKERNEL   %s</span></tool>\n",
      overseer().c_str(), uptime_str().c_str(), l1, l5, l15, used, total, u.release);
  std::printf("<txtclick>xfce4-taskmanager</txtclick>\n");
  return 0;
}

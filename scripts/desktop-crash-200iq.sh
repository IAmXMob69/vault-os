#!/usr/bin/env bash
# Desktop 200-IQ Crash Log — exhaustive XFCE/Xorg/session audit
# Writes a timestamped case file + latest.md under the Vault-OS log dir.
set -uo pipefail

HOST_NAME="$(cat /etc/hostname 2>/dev/null || uname -n 2>/dev/null || echo unknown)"
REPORT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fallout-nv/logs/crash"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/crash-${STAMP}.md"
CASE="$REPORT_DIR/DESKTOP-CRASH-LOG.md"

ok=0; warn=0; fail=0; info=0
findings=()

log() {
  local level="$1"; shift
  local msg="$*"
  case "$level" in
    OK)   ok=$((ok+1));   tag="OK  " ;;
    WARN) warn=$((warn+1)); tag="WARN" ;;
    FAIL) fail=$((fail+1)); tag="FAIL" ;;
    INFO) info=$((info+1)); tag="INFO" ;;
  esac
  findings+=("[$tag] $msg")
  printf '[%s] %s\n' "$tag" "$msg"
}

section() { printf '\n### %s\n' "$1"; findings+=(""); findings+=("### $1"); }

have() { command -v "$1" >/dev/null 2>&1; }

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  DESKTOP 200-IQ CRASH LOG — full systems audit           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo "Stamp: $STAMP"
echo

# ── 1. Machine / boot ───────────────────────────────────────
section "1. Machine / boot"
kernel_run="$(uname -r 2>/dev/null || echo unknown)"
kernel_pkg="$(pacman -Q linux 2>/dev/null | awk '{print $2}' || true)"
boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"
uptime_s="$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)"
log INFO "Host $HOST_NAME · $(uname -snr)"
log INFO "Hardware: $(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
log INFO "Running kernel $kernel_run"
if [[ -n "$kernel_pkg" ]]; then
  log INFO "Installed linux package $kernel_pkg"
  run_short="${kernel_run%%-*}"
  pkg_short="${kernel_pkg%%.arch*}"
  pkg_short="${pkg_short%%-*}"
  if [[ "$kernel_run" != *"${pkg_short}"* && "$kernel_pkg" != *"${run_short}"* ]]; then
    log WARN "Kernel package ahead of running kernel — reboot to load $kernel_pkg"
  else
    log OK "Running kernel matches installed linux package"
  fi
fi
log INFO "Boot ID $boot_id · uptime ${uptime_s}s"
if have journalctl; then
  this_boot="$(journalctl --list-boots --no-pager 2>/dev/null | awk 'END{print $1, $3, $4, $5, $6}')"
  log INFO "This boot index: $this_boot"
fi

# ── 2. Real crashes (coredumps) ──────────────────────────────
section "2. Real crashes (coredumps)"
if have coredumpctl; then
  dump_tbl="$(coredumpctl --no-pager 2>/dev/null || true)"
  dump_n="$(printf '%s\n' "$dump_tbl" | awk 'NF && $1!="TIME"{c++} END{print c+0}')"
  log INFO "systemd-coredump entries: $dump_n"
  this_boot_dumps="$(coredumpctl -b --no-pager 2>/dev/null | awk 'NF && $1!="TIME"{c++} END{print c+0}')"
  if (( this_boot_dumps == 0 )); then
    log OK "No coredumps this boot"
  else
    log FAIL "Coredumps this boot: $this_boot_dumps"
    while IFS= read -r line; do
      [[ "$line" == TIME* || -z "$line" ]] && continue
      log FAIL "  $line"
    done < <(coredumpctl -b --no-pager 2>/dev/null || true)
  fi
  while IFS= read -r d; do
    [[ -z "$d" || "$d" == TIME* ]] && continue
    exe="$(awk '{print $(NF-1)}' <<<"$d")"
    sig="$(awk '{for(i=1;i<=NF;i++) if($i ~ /^SIG/) print $i}' <<<"$d")"
    when="$(awk '{print $1,$2,$3,$4,$5}' <<<"$d")"
    if grep -qi picom <<<"$exe"; then
      log WARN "Historical: picom ${sig:-dump} @ $when"
    elif grep -Eqi 'xfce4-panel|xfwm4|xfdesktop' <<<"$exe"; then
      log WARN "Historical desktop: $exe ${sig:-dump} @ $when"
    else
      log INFO "Historical: $exe ${sig:-dump} @ $when"
    fi
  done < <(printf '%s\n' "$dump_tbl" | awk 'NF && $1!="TIME"' | tail -8)
else
  log WARN "coredumpctl not available"
fi

# ── 3. Desktop compositor stack ──────────────────────────────
section "3. Desktop compositor stack"
picom_pid="$(pgrep -n picom 2>/dev/null || true)"
if [[ -n "$picom_pid" ]]; then
  picom_cmd="$(ps -o cmd= -p "$picom_pid" 2>/dev/null | tr -s ' ')"
  picom_rss="$(ps -o rss= -p "$picom_pid" 2>/dev/null | tr -d ' ')"
  log OK "picom running pid=$picom_pid rss=${picom_rss}kB"
  log INFO "picom cmd: $picom_cmd"
else
  log FAIL "picom is NOT running"
fi

backend="unknown"
if [[ -f "$HOME/.config/picom.conf" ]]; then
  backend="$(awk -F'"' '/^backend/{print $2; exit}' "$HOME/.config/picom.conf")"
  log INFO "picom.conf backend=$backend"
  if [[ "$backend" == "xrender" ]]; then
    log OK "picom backend xrender (HD 630 stable — avoids Mesa GLX abort)"
  elif [[ "$backend" == "glx" || "$backend" == "egl" ]]; then
    log WARN "picom backend $backend — GLX/EGL on Intel HD 630 previously SIGABRT in libgallium"
  fi
else
  log WARN "missing ~/.config/picom.conf"
fi

xfwm_comp="$(xfconf-query -c xfwm4 -p /general/use_compositing 2>/dev/null || echo '?')"
if [[ "$xfwm_comp" == "false" ]]; then
  log OK "xfwm4 compositing OFF (picom owns compositing — no double compositor)"
elif [[ "$xfwm_comp" == "true" ]]; then
  log WARN "xfwm4 compositing ON while picom may also be running (double compositor)"
else
  log INFO "xfwm4 use_compositing=$xfwm_comp"
fi

for proc in xfwm4 xfce4-panel xfdesktop xfce4-session; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    log OK "$proc running pid=$(pgrep -n "$proc")"
  else
    log FAIL "$proc NOT running"
  fi
done

# ── 4. Xorg client budget ────────────────────────────────────
section "4. Xorg client budget"
xorg_log=""
for p in /var/log/Xorg.0.log "$HOME/.local/share/xorg/Xorg.0.log"; do
  [[ -f "$p" ]] && xorg_log="$p" && break
done
if [[ -n "$xorg_log" ]]; then
  maxc="$(rg -o 'Max clients allowed: [0-9]+' "$xorg_log" 2>/dev/null | tail -1 | awk '{print $4}')"
  if [[ "$maxc" == "2048" ]]; then
    log OK "Xorg Max clients = 2048 (was 256 — that cap made apps fail after hours)"
  elif [[ -n "$maxc" ]]; then
    log WARN "Xorg Max clients = $maxc (want 2048)"
  else
    log WARN "Could not read Max clients from $xorg_log"
  fi
  if rg -q 'Maximum number of clients reached|client already in use' "$xorg_log" 2>/dev/null; then
    log FAIL "Xorg log shows client-limit exhaustion this session"
  else
    log OK "No X client-exhaustion messages this session"
  fi
  ee_n="$(rg -c '\(EE\)' "$xorg_log" 2>/dev/null || echo 0)"
  log INFO "Xorg (EE) lines this session: $ee_n"
else
  log WARN "Xorg.0.log not found"
fi
if [[ -f /etc/X11/xorg.conf.d/30-maxclients.conf ]]; then
  log OK "Persistent /etc/X11/xorg.conf.d/30-maxclients.conf present"
else
  log FAIL "Missing /etc/X11/xorg.conf.d/30-maxclients.conf — 256 cap will return on next X restart"
fi

# ── 5. Session / log residue ─────────────────────────────────
section "5. Session / log residue"
xs="$HOME/.xsession-errors"
if [[ -f "$xs" ]]; then
  xs_sz="$(stat -c%s "$xs" 2>/dev/null || echo 0)"
  log INFO ".xsession-errors size $((xs_sz/1024)) KB"
  glib_n="$(rg -c 'GLib-CRITICAL' "$xs" 2>/dev/null || echo 0)"
  gdk_n="$(rg -c 'Gdk-CRITICAL' "$xs" 2>/dev/null || echo 0)"
  gtk_n="$(rg -c 'Gtk-CRITICAL' "$xs" 2>/dev/null || echo 0)"
  abort_n="$(rg -c -i 'Aborted|SIGABRT|segfault|SIGSEGV' "$xs" 2>/dev/null || echo 0)"
  maxc_n="$(rg -c 'Maximum number of clients' "$xs" 2>/dev/null || echo 0)"
  log INFO "xsession GLib-CRITICAL=$glib_n Gdk-CRITICAL=$gdk_n Gtk-CRITICAL=$gtk_n"
  if (( abort_n > 0 )); then
    log WARN "xsession abort/segfault mentions: $abort_n"
  else
    log OK "No abort/segfault strings in current .xsession-errors"
  fi
  if (( maxc_n > 0 )); then
    log FAIL "xsession shows Maximum number of clients ($maxc_n)"
  fi
  if (( glib_n > 500 )); then
    log WARN "xfwm4 GLib-CRITICAL spam is filling .xsession-errors ($glib_n hits) — not a crash, but it hides real errors"
  fi
else
  log INFO ".xsession-errors not present yet"
fi

vos_log="$HOME/.local/share/fallout-nv/logs/vault-os.log"
if [[ -f "$vos_log" ]]; then
  vos_n="$(wc -l < "$vos_log" 2>/dev/null | tr -d ' ')"
  vos_sz="$(stat -c%s "$vos_log" 2>/dev/null || echo 0)"
  log INFO "vault-os.log $vos_n lines / $((vos_sz/1024)) KB"
  if (( vos_n > 50000 )); then
    log WARN "vault-os.log is bloated ($vos_n lines) — 30s watch used to spam 'panels OK'"
  fi
  err_n="$(rg -c ' ERROR ' "$vos_log" 2>/dev/null || echo 0)"
  (( err_n > 0 )) && log INFO "vault-os.log ERROR lines (all time): $err_n"
fi

# ── 6. Failed units / services ───────────────────────────────
section "6. Failed units / services"
sys_fail="$(systemctl --failed --no-legend --plain --no-pager 2>/dev/null | awk '{print $1}' | paste -sd, -)"
usr_fail="$(systemctl --user --failed --no-legend --plain --no-pager 2>/dev/null | awk '{print $1}' | paste -sd, -)"
if [[ -z "$sys_fail" ]]; then
  log OK "No failed system units"
else
  log WARN "Failed system units: $sys_fail"
fi
if [[ -z "$usr_fail" ]]; then
  log OK "No failed user units"
else
  log FAIL "Failed user units: $usr_fail"
fi

if systemctl is-failed --quiet proton.VPN.service 2>/dev/null; then
  log WARN "proton.VPN.service failed (often BPF/kheaders vs running kernel — reboot after linux upgrade)"
fi

if have journalctl; then
  oom="$(journalctl -b -q --no-pager -g 'oom-kill|Killed process|Out of memory' 2>/dev/null | wc -l | tr -d ' ')"
  oom="${oom:-0}"
  if (( oom > 0 )); then
    log FAIL "OOM killer activity this boot: $oom hits"
  else
    log OK "No OOM killer this boot"
  fi
  if journalctl -b -k -q --no-pager -g 'Call Trace:|kernel BUG|Oops:|general protection fault' 2>/dev/null | grep -q .; then
    log FAIL "Kernel oops / call trace this boot"
  else
    log OK "No kernel oops this boot"
  fi
fi

# ── 7. GPU / firmware leftovers ──────────────────────────────
section "7. GPU / firmware leftovers"
if pacman -Qq nvidia-open-dkms nvidia-utils lib32-nvidia-utils 2>/dev/null | rg . >/dev/null 2>&1; then
  log WARN "NVIDIA driver packages still installed on an Intel-only box"
else
  log OK "No NVIDIA driver packages (Intel HD 630 only)"
fi
if lsmod | rg '^nvidia' >/dev/null 2>&1; then
  log WARN "nvidia kernel module is loaded"
else
  log OK "nvidia module not loaded"
fi
if journalctl -b -k -q --no-pager -g 'NVRM: No NVIDIA GPU found' 2>/dev/null | grep -q .; then
  log INFO "NVRM 'No NVIDIA GPU found' this boot (harmless if packages already removed — gone after reboot)"
fi
if journalctl -b -k -q --no-pager -g 'failed to load regulatory.db' 2>/dev/null | grep -q .; then
  if pacman -Qq wireless-regdb >/dev/null 2>&1; then
    log INFO "regulatory.db failed at boot; wireless-regdb is now installed — reboot to clear"
  else
    log WARN "regulatory.db failed and wireless-regdb is not installed"
  fi
else
  log OK "Wi-Fi regulatory.db loaded (or not logged this boot)"
fi
if journalctl -b -k -q --no-pager -g 'Volume was not properly unmounted' 2>/dev/null | grep -q .; then
  log WARN "/boot FAT was dirty at mount this boot — fsck was run later; confirm clean after reboot"
else
  log OK "No dirty /boot FAT warning this boot"
fi
gpu="$(lspci -nn 2>/dev/null | rg -i 'vga|3d' | head -3)"
[[ -n "$gpu" ]] && log INFO "GPU: $gpu"

# ── 8. Memory / disk ─────────────────────────────────────────
section "8. Memory / disk"
mem_avail="$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo)"
mem_total="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"
log INFO "RAM ${mem_avail}MB available / ${mem_total}MB total"
(( mem_avail < 400 )) && log WARN "Very low available RAM" || log OK "RAM headroom OK"
swap_used="$(awk '/SwapTotal/{t=$2} /SwapFree/{f=$2} END{printf "%d", (t-f)/1024}' /proc/meminfo)"
log INFO "Swap used ${swap_used}MB"
root_pct="$(df -P / | awk 'END{gsub(/%/,"",$5); print $5}')"
boot_pct="$(df -P /boot 2>/dev/null | awk 'END{gsub(/%/,"",$5); print $5}')"
home_pct="$(df -P /home | awk 'END{gsub(/%/,"",$5); print $5}')"
log INFO "Disk / ${root_pct}% · /boot ${boot_pct}% · /home ${home_pct}%"
(( root_pct > 90 )) && log FAIL "Root filesystem >90% full" || { (( root_pct > 85 )) && log WARN "Root filesystem ${root_pct}% full" || log OK "Root disk headroom OK"; }

# ── 9. Autostart / watchdogs ─────────────────────────────────
section "9. Autostart / watchdogs"
if [[ -f "$HOME/.config/autostart/picom.desktop" ]]; then
  log OK "picom autostart present"
else
  log WARN "picom autostart missing"
fi
if systemctl --user is-enabled --quiet vault-os-watch.timer 2>/dev/null; then
  interval="$(rg -n '^OnUnitActiveSec=' "$HOME/.config/systemd/user/vault-os-watch.timer" 2>/dev/null | tail -1 | cut -d= -f2)"
  log OK "vault-os-watch.timer enabled (interval ${interval:-unknown})"
else
  log INFO "vault-os-watch.timer not enabled"
fi
if [[ -f "$HOME/.config/autostart/bloodlink-server.desktop" ]]; then
  if rg -q 'X-GNOME-Autostart-enabled=false|Hidden=true' "$HOME/.config/autostart/bloodlink-server.desktop"; then
    log OK "BloodLink autostart is disabled"
  else
    log WARN "BloodLink autostart file is enabled"
  fi
fi

# ── 10. Browser crash pads ───────────────────────────────────
section "10. Browser crash pads"
ff_pending="$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" -path '*/crashes/pending/*' -type f 2>/dev/null | wc -l | tr -d ' ')"
ff_dmp="$(find "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" -name '*.dmp' 2>/dev/null | wc -l | tr -d ' ')"
ch_pending="$(find "$HOME/.config/chromium/Crash Reports/pending" -type f 2>/dev/null | wc -l | tr -d ' ')"
if (( ff_pending + ff_dmp == 0 )); then
  log OK "No Firefox minidumps / pending crash reports"
else
  log WARN "Firefox crash artifacts: pending=$ff_pending dmp=$ff_dmp"
fi
if (( ch_pending == 0 )); then
  log OK "No Chromium pending crash reports"
else
  log WARN "Chromium pending crash reports: $ch_pending"
fi

# ── 11. Risk heuristics ──────────────────────────────────────
section "11. Risk heuristics"
if [[ "$kernel_run" == 7.1.* ]] && [[ "$kernel_pkg" == 7.2.* || "$kernel_pkg" == 7.3.* ]]; then
  log WARN "Reboot required: linux $kernel_pkg is installed, still running $kernel_run"
fi
nproc_n="$(nproc)"
log INFO "CPU threads: $nproc_n"
load="$(cut -d' ' -f1 /proc/loadavg)"
log INFO "Load average (1m): $load"
if pgrep -x picom >/dev/null && [[ "$backend" == "xrender" ]] && [[ "$xfwm_comp" == "false" ]] && [[ "${maxc:-}" == "2048" ]]; then
  log OK "Core desktop crash mitigations are in place (xrender + no xfwm compositing + 2048 X clients)"
fi

# ── Summary ──────────────────────────────────────────────────
echo
echo "══════════════════════════════════════════════════════════"
echo " SUMMARY: $ok OK · $warn WARN · $fail FAIL · $info INFO"
echo "══════════════════════════════════════════════════════════"
if (( fail > 0 )); then
  echo " Verdict: NEEDS ATTENTION ($fail failures)"
  verdict="NEEDS ATTENTION"
elif (( warn > 0 )); then
  echo " Verdict: STABLE WITH NOTES ($warn warnings)"
  verdict="STABLE WITH NOTES"
else
  echo " Verdict: CLEAN"
  verdict="CLEAN"
fi
echo " Snapshot: $REPORT"
echo " Case file: $CASE"
echo

host_line="$(uname -snr)"
hw_line="$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
cpu_line="$(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ //')"
{
  echo "# Desktop 200-IQ Crash Snapshot"
  echo
  echo "- **Stamp:** $STAMP"
  echo "- **Host:** $host_line"
  echo "- **Machine:** $hw_line · $cpu_line"
  echo "- **Verdict:** $verdict"
  echo "- **Counts:** $ok OK · $warn WARN · $fail FAIL · $info INFO"
  echo "- **Kernel:** running \`$kernel_run\` · package \`$kernel_pkg\`"
  echo "- **Boot ID:** \`$boot_id\`"
  echo
  echo "## Findings"
  echo
  for f in "${findings[@]}"; do
    if [[ "$f" == '### '* ]]; then
      echo
      echo "$f"
      echo
    elif [[ -z "$f" ]]; then
      :
    else
      echo "- $f"
    fi
  done
  echo
  echo "## How to read this"
  echo
  echo "- **FAIL** = live crash or a mitigation is missing."
  echo "- **WARN** = real issue that is not dropping the session right now (pending reboot, historical dump, log spam)."
  echo "- **OK / INFO** = confirmed healthy or context."
  echo
  echo "The standing case file (root causes, timeline, what was already fixed) is:"
  echo
  echo "\`$CASE\`"
  echo
  echo "## Re-run"
  echo
  echo '```bash'
  echo "$HOME/.local/bin/desktop-crash-200iq"
  echo '# or'
  echo "/home/xmob/Projects/vault-os/scripts/desktop-crash-200iq.sh"
  echo '```'
} > "$REPORT"

ln -sfn "$REPORT" "$REPORT_DIR/latest.md"
echo "$REPORT"
if (( fail > 0 )); then
  exit 1
fi
exit 0

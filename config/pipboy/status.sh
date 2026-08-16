#!/usr/bin/env bash
# Pip-Boy STAT screen with real system info (ASCII-safe for Share Tech Mono)

G=$'\033[38;2;51;255;102m'
D=$'\033[38;2;26;90;40m'
B=$'\033[1m'
R=$'\033[0m'

bar() {
  local pct=$1 width=${2:-20}
  (( pct > 100 )) && pct=100
  (( pct < 0 )) && pct=0
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf '%s' "$G"
  printf '%*s' "$filled" '' | tr ' ' '#'
  printf '%s' "$D"
  printf '%*s' "$empty" '' | tr ' ' '-'
  printf '%s' "$R"
}

load=$(awk '{printf "%d", $1*25}' /proc/loadavg 2>/dev/null || echo 10)
(( load > 100 )) && load=100

mem_total=$(free -m | awk '/^Mem:/{print $2}')
mem_used=$(free -m | awk '/^Mem:/{print $3}')
mem_pct=0
if (( mem_total > 0 )); then
  mem_pct=$(( mem_used * 100 / mem_total ))
fi
hp=$(( 100 - mem_pct / 2 ))

disk_pct=$(df -P "$HOME" | awk 'END{gsub(/%/,"",$5); print $5}')
ammo=$(( 100 - disk_pct ))

up=$(uptime -p 2>/dev/null | sed 's/up //')
host=${HOSTNAME:-$(uname -n 2>/dev/null || echo vault-terminal)}

bat=""
if [[ -f /sys/class/power_supply/BAT0/capacity ]]; then
  bat_pct=$(cat /sys/class/power_supply/BAT0/capacity)
  bat=$(printf '  CHARGE   [%s] %s%%\n' "$(bar "$bat_pct")" "$bat_pct")
fi

printf '%s\n' \
  "${D}+------------------------------------------+${R}" \
  "|${G}${B}  PIP-BOY 3000  .  STAT                   ${R}${D}|${R}" \
  "${D}+------------------------------------------+${R}" \
  "  ${G}DWELLER${R}  ${USER}" \
  "  ${G}HOST   ${R}  ${host}" \
  "  ${G}OS     ${R}  $(uname -sr)" \
  "  ${G}UPTIME ${R}  ${up}" \
  "" \
  "  ${G}HP     ${R}  [$(bar "$hp")] ${hp}%" \
  "  ${G}RADS   ${R}  [$(bar "$load")] ${load}%" \
  "  ${G}SUPPLY ${R}  [$(bar "$ammo")] free disk ${ammo}%" \
  ${bat:+"$bat"} \
  "${D}+------------------------------------------+${R}" \
  "|${G}  SPECIAL                                 ${R}${D}|${R}" \
  "${D}+------------------------------------------+${R}" \
  "  ${G}S${R}tr  $(nproc 2>/dev/null || echo 1) cores" \
  "  ${G}P${R}er  load $(cut -d' ' -f1-3 /proc/loadavg)" \
  "  ${G}E${R}nd  ${mem_used}M / ${mem_total}M RAM" \
  "  ${G}C${R}ha  $(df -h "$HOME" | awk 'END{print $4}') free home" \
  "  ${G}I${R}nt  bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" \
  "  ${G}A${R}gi  $(date +%H:%M:%S)" \
  "  ${G}L${R}ck  vault-tec online" \
  "${D}+------------------------------------------+${R}"

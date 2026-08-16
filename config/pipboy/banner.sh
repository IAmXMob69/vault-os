#!/usr/bin/env bash
# ROBCO Industries (TM) Termlink boot banner — Pip-Boy style

# Only for interactive terminals with color
[[ -t 1 ]] || return 0 2>/dev/null || exit 0

# Soft green
G=$'\033[38;2;51;255;102m'
D=$'\033[38;2;20;120;50m'
B=$'\033[1m'
R=$'\033[0m'
DIM=$'\033[2m'

cols=$(tput cols 2>/dev/null || echo 80)
(( cols < 48 )) && cols=48

line() {
  local ch="${1:-=}"
  printf '%s' "$D"
  printf '%*s' "$cols" '' | tr ' ' "$ch"
  printf '%s\n' "$R"
}

clear 2>/dev/null || true

line '='
printf '%s%sROBCO INDUSTRIES (TM) TERMLINK PROTOCOL%s\n' "$G" "$B" "$R"
printf '%sCOPYRIGHT 2075-2077 ROBCO INDUSTRIES%s\n' "$D" "$R"
printf '%s-Server 1-%s\n' "$D" "$R"
line '-'

# Fake boot sequence (fast)
for msg in \
  "Initializing ROBCO OS kernel modules..." \
  "Loading Pip-Boy 3000 firmware v1.4.0.525..." \
  "Establishing secure vault uplink..." \
  "Radiation shield: ONLINE" \
  "Geiger counter: ONLINE" \
  "Welcome, Vault Dweller."
do
  printf '%s> %s%s\n' "$G" "$msg" "$R"
  sleep 0.04 2>/dev/null || true
done

line '='
printf '%s%sHOST%s  %s\n' "$D" "$B" "$R" "${HOSTNAME:-$(uname -n 2>/dev/null || echo terminal)}"
printf '%s%sUSER%s  %s\n' "$D" "$B" "$R" "${USER:-dweller}"
printf '%s%sDATE%s  %s\n' "$D" "$B" "$R" "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
printf '%s%sCWD %s  %s\n' "$D" "$B" "$R" "${PWD/#$HOME/~}"
line '='
printf '%s%sType %shelp-pipboy%s%s for theme commands. Happy trails.%s\n\n' \
  "$D" "$DIM" "$G" "$D" "$DIM" "$R"

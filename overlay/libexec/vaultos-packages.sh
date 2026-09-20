#!/usr/bin/env bash
# Check / sync package lists. Never runs pacman -Syu.
set -euo pipefail

BASE="${VAULTOS_PACKAGES_BASE:-/etc/vaultos/packages.base}"
DESKTOP="${VAULTOS_PACKAGES_DESKTOP:-/etc/vaultos/packages.desktop}"
[[ -f "$BASE" ]] || BASE="$(dirname "$(readlink -f "$0")")/../packages/packages.base"
[[ -f "$DESKTOP" ]] || DESKTOP="$(dirname "$(readlink -f "$0")")/../packages/packages.desktop"

list_pkgs() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  awk '/^[[:space:]]*#/ {next} NF {print $1}' "$f"
}

missing_in() {
  local f="$1" p
  while read -r p; do
    [[ -n "$p" ]] || continue
    pacman -Q "$p" >/dev/null 2>&1 || echo "$p"
  done < <(list_pkgs "$f")
}

cmd="${1:-status}"
case "$cmd" in
  status)
    echo "base     $BASE"
    echo "desktop  $DESKTOP"
    echo "───────────────"
    echo "base installed:"
    while read -r p; do
      if pacman -Q "$p" >/dev/null 2>&1; then
        printf '  OK    %s\n' "$p"
      else
        printf '  MISS  %s\n' "$p"
      fi
    done < <(list_pkgs "$BASE")
    echo "desktop installed:"
    while read -r p; do
      if pacman -Q "$p" >/dev/null 2>&1; then
        printf '  OK    %s\n' "$p"
      else
        printf '  MISS  %s\n' "$p"
      fi
    done < <(list_pkgs "$DESKTOP")
    ;;
  missing)
    { missing_in "$BASE"; missing_in "$DESKTOP"; } | sort -u
    ;;
  *)
    echo "usage: vaultos-packages.sh status|missing" >&2
    exit 2
    ;;
esac

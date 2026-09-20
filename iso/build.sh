#!/usr/bin/env bash
# Build vaultos-<version>-x86_64.iso. Does not touch the host bootloader or disks.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VER="$(tr -d '\n' <"$ROOT/overlay/VERSION")"
WORK="$ROOT/iso/work"
OUT="$ROOT/iso/out"
"$ROOT/iso/prepare-profile.sh"
mkdir -p "$OUT"
echo "mkarchiso work=$WORK out=$OUT (needs root)"
if [[ "$(id -u)" -eq 0 ]]; then
  "$ROOT/iso/mkarchiso-root.sh" "$ROOT"
else
  pkexec env DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}" \
    SUDO_USER="${USER:-}" \
    "$ROOT/iso/mkarchiso-root.sh" "$ROOT"
fi

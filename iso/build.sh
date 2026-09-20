#!/usr/bin/env bash
# Build vaultos-<version>-x86_64.iso. Does not touch the host bootloader or disks.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VER="$(tr -d '\n' <"$ROOT/overlay/VERSION")"
WORK="$ROOT/iso/work"
OUT="$ROOT/iso/out"
"$ROOT/iso/prepare-profile.sh"
mkdir -p "$OUT"
rm -rf "$WORK"
echo "mkarchiso work=$WORK out=$OUT (needs root)"
mkdir -p "$OUT"
if [[ "$(id -u)" -ne 0 ]]; then
  pkexec mkarchiso -v -w "$WORK" -o "$OUT" "$ROOT/iso/profile"
else
  mkarchiso -v -w "$WORK" -o "$OUT" "$ROOT/iso/profile"
fi
# rename to spec name if mkarchiso used iso_name-iso_version
shopt -s nullglob
for f in "$OUT"/vaultos-*.iso; do
  dest="$OUT/vaultos-${VER}-x86_64.iso"
  if [[ "$f" != "$dest" ]]; then
    mv -f "$f" "$dest" 2>/dev/null || pkexec mv -f "$f" "$dest"
  fi
  echo "ISO $dest"
  ls -lh "$dest"
done

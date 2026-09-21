#!/usr/bin/env bash
# Root half of iso/build.sh: wipe work dir and run mkarchiso. Do not call from a login shell.
set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "mkarchiso-root: need root" >&2; exit 1; }
ROOT="${1:?repo root}"
VER="$(tr -d '\n' <"$ROOT/overlay/VERSION")"
WORK="$ROOT/iso/work"
OUT="$ROOT/iso/out"
PROFILE="$ROOT/iso/profile"
[[ -d "$PROFILE" ]] || { echo "missing $PROFILE (run prepare-profile.sh)" >&2; exit 1; }
mkdir -p "$OUT"
if [[ -d "$WORK" ]]; then
  awk -v p="$WORK" '$2 ~ p {print $2}' /proc/mounts | sort -r | while read -r m; do
    umount -lf "$m" || true
  done
fi
rm -rf "$WORK"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"
shopt -s nullglob
for f in "$OUT"/vaultos-*.iso; do
  dest="$OUT/vaultos-${VER}-x86_64.iso"
  if [[ "$f" != "$dest" ]]; then
    mv -f "$f" "$dest"
  fi
  echo "ISO $dest"
  ls -lh "$dest"
done
if [[ -n "${SUDO_USER:-}" && -d "$OUT" ]]; then
  chown -R "$SUDO_USER:$SUDO_USER" "$OUT" || true
fi

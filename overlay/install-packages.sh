#!/usr/bin/env bash
# Install /etc/vaultos package lists and refresh /usr/lib/vaultos copies.
# Optional: pacman -S --needed for missing list entries. Never pacman -Syu.
set -euo pipefail
SCRIPT="$(readlink -f "$0")"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
fi
SYNC="${2:-}"
[[ -d "$SRC/overlay/packages" ]] || { echo "install-packages: bad src" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  exec pkexec "$SCRIPT" "$SRC" "$SYNC"
fi

install -d /etc/vaultos /usr/lib/vaultos/libexec /usr/lib/vaultos/bin \
  /usr/lib/vaultos/overlay/packages
install -m 0644 "$SRC/overlay/packages/packages.base" /etc/vaultos/packages.base
install -m 0644 "$SRC/overlay/packages/packages.desktop" /etc/vaultos/packages.desktop
install -m 0644 "$SRC/overlay/packages/packages.base" /usr/lib/vaultos/overlay/packages/packages.base
install -m 0644 "$SRC/overlay/packages/packages.desktop" /usr/lib/vaultos/overlay/packages/packages.desktop
install -m 0755 "$SRC/overlay/libexec/vaultos-packages.sh" /usr/lib/vaultos/libexec/vaultos-packages.sh
install -m 0755 "$SRC/bin/vaultos" /usr/lib/vaultos/bin/vaultos
ln -sfn /usr/lib/vaultos/bin/vaultos /usr/bin/vaultos

if [[ "$SYNC" == "--needed" ]]; then
  mapfile -t miss < <(VAULTOS_PACKAGES_BASE=/etc/vaultos/packages.base \
    VAULTOS_PACKAGES_DESKTOP=/etc/vaultos/packages.desktop \
    /usr/lib/vaultos/libexec/vaultos-packages.sh missing)
  if ((${#miss[@]})); then
    echo "pacman -S --needed ${miss[*]}"
    pacman -S --needed --noconfirm "${miss[@]}"
  else
    echo "no missing packages"
  fi
fi
echo "installed /etc/vaultos/packages.base and packages.desktop"

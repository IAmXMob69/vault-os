#!/usr/bin/env bash
# Needs sudo. Installs stock-shaped screensaver entry + wrapper.
# The wrapper is installed as-is: it finds the user's runner at run time,
# so nothing about the installing user's home is baked into /usr.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
if [[ $EUID -ne 0 ]]; then
  echo "install-system.sh: run with sudo" >&2
  exit 1
fi
install -d /usr/lib/xfce4-screensaver /usr/share/applications/screensavers
install -m 755 "$SRC/vaultos-arch-spin.wrapper" /usr/lib/xfce4-screensaver/vaultos-arch-spin
install -m 644 "$SRC/vaultos-arch-spin.desktop" /usr/share/applications/screensavers/vaultos-arch-spin.desktop
sed -i '/^Hidden=/d' /usr/share/applications/screensavers/vaultos-arch-spin.desktop
echo "Installed vaultos-arch-spin. It runs ~/.local/bin/vaultos-spin-lock-run (or one on PATH)."

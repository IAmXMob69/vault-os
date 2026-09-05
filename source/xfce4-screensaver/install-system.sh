#!/usr/bin/env bash
# Needs sudo. Installs stock-shaped screensaver entry + wrapper.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
install -d /usr/lib/xfce4-screensaver /usr/share/applications/screensavers
install -m 755 "$SRC/vaultos-arch-spin.wrapper" /usr/lib/xfce4-screensaver/vaultos-arch-spin
install -m 644 "$SRC/vaultos-arch-spin.desktop" /usr/share/applications/screensavers/vaultos-arch-spin.desktop
echo "Installed vaultos-arch-spin. Ensure vaultos-spin-lock-run is on PATH (~/.local/bin)."

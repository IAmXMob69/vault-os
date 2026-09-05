#!/bin/bash
set -euo pipefail
install -m 755 $HOME/Vault.OS/source/xfce4-screensaver/vaultos-arch-spin.wrapper /usr/lib/xfce4-screensaver/vaultos-arch-spin
install -m 644 $HOME/Vault.OS/source/xfce4-screensaver/vaultos-arch-spin.desktop /usr/share/applications/screensavers/vaultos-arch-spin.desktop
# ensure no Hidden=
sed -i '/^Hidden=/d' /usr/share/applications/screensavers/vaultos-arch-spin.desktop

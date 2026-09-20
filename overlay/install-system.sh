#!/usr/bin/env bash
# Install Vault.OS Phase 2 files under /usr/lib/vaultos and enable units.
# Does not change hostname, bootloader, kernel, or partitions.
set -euo pipefail

SCRIPT="$(readlink -f "$0")"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
fi
[[ -d "$SRC/overlay/identity" ]] || { echo "install-system: bad src $SRC" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  exec pkexec "$SCRIPT" "$SRC"
fi

LIB=/usr/lib/vaultos
install -d "$LIB/bin" "$LIB/libexec" "$LIB/overlay/identity" "$LIB/overlay/systemd" \
  /usr/lib/systemd/system /var/lib/vaultos /var/log

install -m 0755 "$SRC/bin/vaultos" "$LIB/bin/vaultos"
install -m 0755 "$SRC/overlay/identity-apply.sh" "$LIB/overlay/identity-apply.sh"
install -m 0644 "$SRC/overlay/VERSION" "$LIB/overlay/VERSION"
install -m 0644 "$SRC/overlay/README.md" "$LIB/overlay/README.md"
install -m 0644 "$SRC/overlay/identity/"* "$LIB/overlay/identity/"
install -m 0755 "$SRC/overlay/libexec/vaultos-core.sh" "$LIB/libexec/vaultos-core.sh"
install -m 0755 "$SRC/overlay/libexec/vaultos-firstboot.sh" "$LIB/libexec/vaultos-firstboot.sh"
install -m 0644 "$SRC/overlay/systemd/vaultos-core.service" /usr/lib/systemd/system/vaultos-core.service
install -m 0644 "$SRC/overlay/systemd/vaultos-firstboot.service" /usr/lib/systemd/system/vaultos-firstboot.service
ln -sfn "$LIB/bin/vaultos" /usr/bin/vaultos

systemctl daemon-reload
systemctl enable vaultos-firstboot.service vaultos-core.service
# Run now so we do not need a reboot to verify. Units cannot block LightDM.
systemctl start vaultos-firstboot.service
systemctl start vaultos-core.service

echo "installed $LIB"
echo "enabled vaultos-firstboot.service vaultos-core.service"
systemctl is-active vaultos-core.service
systemctl is-enabled vaultos-core.service

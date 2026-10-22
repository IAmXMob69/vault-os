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
install -m 0755 "$SRC/overlay/libexec/vaultos-firstuser.sh" "$LIB/libexec/vaultos-firstuser.sh"
install -m 0755 "$SRC/overlay/libexec/vaultos-run.sh" "$LIB/libexec/vaultos-run.sh"
# Native boot helper and wizard, when they build. The shell scripts stay the fallback.
install_native() {
  local name="$1" built="$SRC/src/$name/$name"
  if [[ ! -x "$built" ]] && command -v g++ >/dev/null && command -v make >/dev/null; then
    make -C "$SRC/src/$name" || echo "vaultos: $name did not build; shell fallback stays" >&2
  fi
  if [[ -x "$built" ]]; then
    install -m 0755 "$built" "$LIB/libexec/$name"
  fi
}
install_native vaultos-boot
install_native vaultos-firstuser
install -m 0644 "$SRC/overlay/systemd/vaultos-core.service" /usr/lib/systemd/system/vaultos-core.service
install -m 0644 "$SRC/overlay/systemd/vaultos-firstboot.service" /usr/lib/systemd/system/vaultos-firstboot.service
install -m 0644 "$SRC/overlay/systemd/vaultos-firstuser.service" /usr/lib/systemd/system/vaultos-firstuser.service
ln -sfn "$LIB/bin/vaultos" /usr/bin/vaultos

systemctl daemon-reload
systemctl enable vaultos-firstboot.service vaultos-core.service
# Do NOT enable or start vaultos-firstuser.service on an existing desktop.
# Fresh installs enable it from vaultos-install so first boot can create
# an account. Enabling it here would grab tty1 on the next reboot.
# Run identity/core now so we do not need a reboot to verify. They cannot
# block LightDM.
systemctl start vaultos-firstboot.service
systemctl start vaultos-core.service

echo "installed $LIB"
echo "enabled vaultos-firstboot.service vaultos-core.service"
systemctl is-active vaultos-core.service
systemctl is-enabled vaultos-core.service

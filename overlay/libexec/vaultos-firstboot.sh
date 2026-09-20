#!/usr/bin/env bash
# Vault.OS first boot — identity + network, never block graphical login.
# Hostname, bootloader, kernel, and disks are not changed.
set +e
exec 1>/var/log/vaultos-firstboot.log 2>&1
echo "vaultos-firstboot $(date -Iseconds)"

LIB="${VAULTOS_LIB:-/usr/lib/vaultos}"
STAMP=/var/lib/vaultos/firstboot-done

mkdir -p /var/lib/vaultos /var/log

if [[ -f "$STAMP" ]]; then
  echo "already stamped: $STAMP"
  exit 0
fi

# Locale only if unset
if [[ -z "$(localectl status 2>/dev/null | awk -F= '/System Locale/{print $2; exit}')" ]]; then
  localectl set-locale LANG=en_US.UTF-8 || true
fi

# Timezone only if unset / UTC factory default with no NTP — skip if already set.
# This machine already has America/New_York; do not clobber.

# Network: keep existing NetworkManager. Do not enable iwd or systemd-networkd
# if NM is already the live stack.
if systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
  systemctl enable NetworkManager.service >/dev/null 2>&1 || true
  systemctl start NetworkManager.service >/dev/null 2>&1 || true
fi

if [[ -x "$LIB/overlay/identity-apply.sh" ]]; then
  if ! grep -q '^ID=vaultos$' /etc/os-release 2>/dev/null; then
    "$LIB/overlay/identity-apply.sh" apply || true
  fi
fi

{
  echo "done=$(date -Iseconds)"
  echo "hostname=$(cat /etc/hostname 2>/dev/null)"
  echo "id=$(awk -F= '/^ID=/{print $2; exit}' /etc/os-release)"
} >"$STAMP"
chmod 0644 "$STAMP"
echo "stamped $STAMP"
exit 0

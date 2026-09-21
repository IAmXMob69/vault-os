#!/usr/bin/env bash
# Vault.OS first boot — identity only. Does not stamp firstboot-done;
# the interactive wizard writes that after machine + account succeed.
# Hostname, bootloader, kernel, and disks are not changed here.
set +e
P="${VAULTOS_TEST_ROOT:-}"
LIB="${VAULTOS_LIB:-/usr/lib/vaultos}"
IDSTAMP="${P}/var/lib/vaultos/identity-applied"
mkdir -p "${P}/var/lib/vaultos" "${P}/var/log"
exec >>"${P}/var/log/vaultos-firstboot.log" 2>&1
echo "vaultos-firstboot-identity $(date -Iseconds)"

if [[ -f "$IDSTAMP" ]]; then
  echo "already stamped: $IDSTAMP"
  exit 0
fi

if [[ -z "$P" ]] && systemctl list-unit-files NetworkManager.service >/dev/null 2>&1; then
  systemctl enable NetworkManager.service >/dev/null 2>&1 || true
  systemctl start NetworkManager.service >/dev/null 2>&1 || true
fi

if [[ -x "$LIB/overlay/identity-apply.sh" ]]; then
  if ! grep -q '^ID=vaultos$' "${P}/etc/os-release" 2>/dev/null; then
    if [[ -n "$P" ]]; then
      echo "test: skip identity-apply"
    else
      "$LIB/overlay/identity-apply.sh" apply || true
    fi
  fi
fi

{
  echo "done=$(date -Iseconds)"
  echo "id=$(awk -F= '/^ID=/{print $2; exit}' "${P}/etc/os-release" 2>/dev/null)"
} >"$IDSTAMP"
chmod 0644 "$IDSTAMP"
echo "stamped $IDSTAMP"
exit 0

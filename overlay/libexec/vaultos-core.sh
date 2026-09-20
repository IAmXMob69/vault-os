#!/usr/bin/env bash
# Vault.OS system control plane. Not the kernel. Never fail the boot.
set +e
mkdir -p /var/lib/vaultos
LIB="${VAULTOS_LIB:-/usr/lib/vaultos}"
VER=unknown
[[ -f "$LIB/overlay/VERSION" ]] && VER=$(tr -d '\n' <"$LIB/overlay/VERSION")
[[ -f "$LIB/VERSION" ]] && VER=$(tr -d '\n' <"$LIB/VERSION")
{
  echo "version=$VER"
  echo "checked=$(date -Iseconds)"
  echo "id=$(awk -F= '/^ID=/{print $2; exit}' /etc/os-release 2>/dev/null)"
} >/var/lib/vaultos/core-state

if [[ -x "$LIB/overlay/identity-apply.sh" ]] && ! grep -q '^ID=vaultos$' /etc/os-release 2>/dev/null; then
  "$LIB/overlay/identity-apply.sh" apply >/var/log/vaultos-core-identity.log 2>&1 || true
fi

exit 0

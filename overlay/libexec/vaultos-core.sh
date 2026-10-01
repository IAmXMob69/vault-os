#!/usr/bin/env bash
# Vault.OS system control plane. Not the kernel. Never fail the boot.
set +e
P="${VAULTOS_TEST_ROOT:-}"   # fake root for tests; skips identity-apply
mkdir -p "${P}/var/lib/vaultos"
LIB="${VAULTOS_LIB:-/usr/lib/vaultos}"
VER=unknown
[[ -f "$LIB/overlay/VERSION" ]] && VER=$(tr -d '\n' <"$LIB/overlay/VERSION")
[[ -f "$LIB/VERSION" ]] && VER=$(tr -d '\n' <"$LIB/VERSION")
{
  echo "version=$VER"
  echo "checked=$(date -Iseconds)"
  echo "id=$(awk -F= '/^ID=/{print $2; exit}' "${P}/etc/os-release" 2>/dev/null)"
} >"${P}/var/lib/vaultos/core-state"

if [[ -x "$LIB/overlay/identity-apply.sh" ]] && ! grep -q '^ID=vaultos$' "${P}/etc/os-release" 2>/dev/null; then
  if [[ -n "$P" ]]; then
    echo "test: skip identity-apply"
  else
    "$LIB/overlay/identity-apply.sh" apply >/var/log/vaultos-core-identity.log 2>&1 || true
  fi
fi

exit 0

#!/bin/bash
# After pacstrap. Early airootfs cannot ship /etc/os-release or /etc/lsb-release
# (filesystem and lsb-release packages own those paths).
set -euo pipefail
ID=/usr/lib/vaultos/overlay/identity
[[ -f "$ID/os-release" ]] || exit 0
install -m 0644 "$ID/os-release" /etc/os-release
install -m 0644 "$ID/lsb-release" /etc/lsb-release
grep -q '^ID=vaultos$' /etc/os-release
grep -q '^ID_LIKE=arch$' /etc/os-release

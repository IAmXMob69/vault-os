#!/usr/bin/env bash
# Prefer a native helper, then its shell script.
#   vaultos-run.sh NATIVE SCRIPT [args...]
# VAULTOS_FORCE_SHELL=1 always runs the script. A missing or non-executable
# native is the same fallback. systemd units and `vaultos firstboot --run`
# go through here so a built C++ tool takes over without a unit edit.
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo "usage: vaultos-run.sh NATIVE SCRIPT [args...]" >&2
  exit 2
fi
native=$1
script=$2
shift 2
if [[ -z "${VAULTOS_FORCE_SHELL:-}" && -x "$native" && -f "$native" ]]; then
  exec "$native" "$@"
fi
if [[ ! -x "$script" ]]; then
  echo "vaultos-run: missing $script" >&2
  exit 127
fi
exec "$script" "$@"

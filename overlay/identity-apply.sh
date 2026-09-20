#!/usr/bin/env bash
# Apply or roll back Vault.OS Phase 1 identity files.
# Does not change hostname, bootloader, kernel, or partitions.
set -euo pipefail

SCRIPT="$(readlink -f "$0")"
ROOT="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
IDIR="$ROOT/overlay/identity"
MARKER="# Vault.OS — commented repo stub"
BACKUP_ROOT="${VAULTOS_BACKUP_ROOT:-/var/lib/vaultos/backups}"
ETC_BACKUP_LINK="${XDG_DATA_HOME:-$HOME/.local/share}/vaultos/last-phase1-backup"

die() { echo "identity-apply: $*" >&2; exit 1; }

need_identity() {
  [[ -f "$IDIR/os-release" ]] || die "missing $IDIR/os-release"
  grep -q '^ID=vaultos$' "$IDIR/os-release" || die "os-release ID is not vaultos"
  grep -q '^ID_LIKE=arch$' "$IDIR/os-release" || die "os-release must keep ID_LIKE=arch"
}

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi
  if command -v pkexec >/dev/null 2>&1; then
    pkexec "$SCRIPT" "$@"
    return
  fi
  die "need root (pkexec or sudo) to change /etc"
}

cmd_status() {
  echo "repo:     $ROOT"
  echo "identity: $IDIR"
  echo
  echo "--- /etc/os-release ---"
  cat /etc/os-release
  echo
  echo -n "hostname: "; cat /etc/hostname
  echo -n "os-release path: "; ls -l /etc/os-release | awk '{print $9,$10,$11}'
  if grep -q '^ID=vaultos$' /etc/os-release && grep -q '^ID_LIKE=arch$' /etc/os-release; then
    echo "identity: Vault.OS overlay is active"
    return 0
  fi
  echo "identity: Arch stock (overlay not applied)"
  return 1
}

latest_backup() {
  if [[ -L "$ETC_BACKUP_LINK" || -f "$ETC_BACKUP_LINK" ]]; then
    readlink -f "$ETC_BACKUP_LINK" 2>/dev/null || true
  fi
  ls -1dt "$BACKUP_ROOT"/phase1-* 2>/dev/null | head -1 || true
}

cmd_apply() {
  need_identity
  if [[ "$(id -u)" -ne 0 ]]; then
    as_root apply
    return
  fi

  local ts dest
  ts="$(date +%Y%m%dT%H%M%S)"
  dest="$BACKUP_ROOT/phase1-$ts"
  mkdir -p "$dest" /var/lib/vaultos
  cp -a /etc/os-release "$dest/os-release" 2>/dev/null || true
  cp -a /usr/lib/os-release "$dest/usr-lib-os-release"
  cp -a /etc/issue "$dest/issue"
  [[ -e /etc/motd ]] && cp -a /etc/motd "$dest/motd" || true
  [[ -e /etc/lsb-release ]] && cp -a /etc/lsb-release "$dest/lsb-release" || true
  cp -a /etc/pacman.conf "$dest/pacman.conf"
  cp -a /etc/hostname "$dest/hostname"
  printf '%s\n' "$dest" >"$dest/README.txt"
  echo "backup: $dest"

  # /etc/os-release must be a real file so pacman updates to filesystem
  # do not revert identity. Leave /usr/lib/os-release as Arch stock.
  install -m 0644 "$IDIR/os-release" /etc/os-release
  install -m 0644 "$IDIR/lsb-release" /etc/lsb-release
  install -m 0644 "$IDIR/issue" /etc/issue
  install -m 0644 "$IDIR/motd" /etc/motd

  if grep -qF "$MARKER" /etc/pacman.conf; then
    echo "pacman.conf: Vault.OS stub already present"
  else
    cat "$IDIR/pacman-vaultos.conf.fragment" >>/etc/pacman.conf
    echo "pacman.conf: appended commented [vaultos] stub"
  fi

  # Hostname intentionally unchanged (still archlinux unless you ask).
  pacman-conf >/dev/null || die "pacman.conf failed to parse — restore from $dest"
  grep -q '^ID=vaultos$' /etc/os-release || die "apply did not stick"
  grep -q '^ID_LIKE=arch$' /etc/os-release || die "ID_LIKE=arch missing"
  echo "applied Vault.OS identity. hostname left as $(cat /etc/hostname)"
  echo "rollback: $SCRIPT rollback"
}

cmd_rollback() {
  if [[ "$(id -u)" -ne 0 ]]; then
    as_root rollback
    return
  fi
  local dest
  dest="$(ls -1dt "$BACKUP_ROOT"/phase1-* 2>/dev/null | head -1 || true)"
  [[ -n "$dest" && -d "$dest" ]] || die "no phase1 backup under $BACKUP_ROOT"
  echo "restoring from $dest"

  if [[ -L "$dest/os-release" ]] || [[ -f "$dest/os-release" ]]; then
    rm -f /etc/os-release
    cp -a "$dest/os-release" /etc/os-release
  else
    ln -sfr /usr/lib/os-release /etc/os-release
  fi
  [[ -f "$dest/issue" ]] && cp -a "$dest/issue" /etc/issue
  if [[ -f "$dest/motd" ]]; then
    cp -a "$dest/motd" /etc/motd
  else
    rm -f /etc/motd
  fi
  if [[ -f "$dest/lsb-release" ]]; then
    cp -a "$dest/lsb-release" /etc/lsb-release
  else
    rm -f /etc/lsb-release
  fi
  [[ -f "$dest/pacman.conf" ]] && cp -a "$dest/pacman.conf" /etc/pacman.conf
  pacman-conf >/dev/null || die "rolled-back pacman.conf does not parse"
  echo "rolled back identity. hostname untouched: $(cat /etc/hostname)"
}

usage() {
  printf '%s\n' \
    'vaultos identity overlay (Phase 1)' \
    '' \
    '  status     Show /etc/os-release vs overlay' \
    '  apply      Write identity files (needs pkexec/sudo). Keeps hostname.' \
    '  rollback   Restore last phase1 backup' \
    '' \
    'Never touches: hostname, bootloader, kernel, partitions, /usr/lib/os-release'
}

case "${1:-status}" in
  status) cmd_status ;;
  apply) cmd_apply ;;
  rollback) cmd_rollback ;;
  -h|--help|help) usage ;;
  *) usage; exit 2 ;;
esac

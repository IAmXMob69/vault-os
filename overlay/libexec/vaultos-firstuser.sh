#!/usr/bin/env bash
# First boot on a freshly installed system: create the first login account.
# Never runs on the live ISO. Never runs if a normal user already exists.
# Does not touch disks, bootloader, or hostname.
set -euo pipefail

STAMP=/var/lib/vaultos/firstuser-done
LOG=/var/log/vaultos-firstuser.log
mkdir -p /var/lib/vaultos /var/log

log() { echo "vaultos-firstuser $(date -Iseconds) $*" >>"$LOG"; }

stamp_and_exit() {
  {
    echo "done=$(date -Iseconds)"
    echo "reason=${1:-ok}"
    echo "user=${2:-}"
  } >"$STAMP"
  chmod 0644 "$STAMP"
  log "stamped $STAMP ($1)"
  exit 0
}

# Live medium: autologin root, no account wizard.
if [[ -d /run/archiso || -f /run/archiso/bootmnt ]]; then
  stamp_and_exit live
fi

if [[ -f "$STAMP" ]]; then
  log "already stamped"
  exit 0
fi

has_login_user() {
  local name uid
  while IFS=: read -r name _ uid _; do
    if [[ "$uid" =~ ^[0-9]+$ ]] && (( uid >= 1000 && uid < 65534 )); then
      echo "$name"
      return 0
    fi
  done < /etc/passwd
  return 1
}

if existing=$(has_login_user); then
  stamp_and_exit existing-user "$existing"
fi

# Take the console so LightDM waits (Before=display-manager).
if [[ -c /dev/console ]]; then
  exec </dev/console >/dev/console 2>/dev/console || true
fi
command -v plymouth >/dev/null 2>&1 && plymouth quit 2>/dev/null || true

reserved() {
  case "$1" in
    root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|nobody|nfsnobody|nobody4|nogroup|systemd-*|vaultos-live|guest)
      return 0 ;;
  esac
  return 1
}

valid_name() {
  local u="$1"
  [[ "$u" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
  reserved "$u" && return 1
  getent passwd "$u" >/dev/null 2>&1 && return 1
  return 0
}

clear 2>/dev/null || true
cat <<'EOF'

  Vault.OS
  ────────
  First boot. Create the account you will log in with.
  Username: lowercase letters, digits, _ or -  (not root).

EOF

user=""
while true; do
  printf 'Username: '
  IFS= read -r user || true
  user="${user,,}"
  user="${user// /}"
  if valid_name "$user"; then
    break
  fi
  echo "That username is not available. Try another."
done

groups="wheel"
for g in audio video storage lp network optical input; do
  getent group "$g" >/dev/null 2>&1 && groups="$groups,$g"
done

useradd -m -G "$groups" -s /bin/bash "$user"
echo '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

echo
echo "Set a password for $user (you will type it twice)."
until passwd "$user"; do
  echo "Password not set — try again."
done

echo
echo "Account $user is ready. Continuing to login…"
sleep 1
stamp_and_exit created "$user"

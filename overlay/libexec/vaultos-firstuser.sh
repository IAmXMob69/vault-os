#!/usr/bin/env bash
# Vault.OS first-boot wizard: machine + first login account.
# Never partitions disks or writes the bootloader.
#
# VAULTOS_TEST_ROOT  prefix all /etc /var /home paths (harness only)
# VAULTOS_FIRSTBOOT_CONF  answers file (also kernel vaultos.firstboot=PATH)
# VAULTOS_TEST_CMDLINE  stands in for /proc/cmdline (only with VAULTOS_TEST_ROOT)
# The C++ port (src/vaultos-firstuser) does the same; this script is its fallback.
set -euo pipefail

P="${VAULTOS_TEST_ROOT:-}"
LIB="${VAULTOS_LIB:-/usr/lib/vaultos}"
if [[ -z "$P" && "$(id -u)" -ne 0 ]]; then
  echo "vaultos-firstuser needs root (or VAULTOS_TEST_ROOT for a fake root)" >&2
  exit 1
fi
STAMP="${P}/var/lib/vaultos/firstboot-done"
USER_STAMP="${P}/var/lib/vaultos/firstuser-done"
LOG="${P}/var/log/vaultos-firstboot.log"
CONF_DEFAULT="${P}/etc/vaultos/firstboot.conf"

mkdir -p "${P}/var/lib/vaultos" "${P}/var/log" "${P}/etc/vaultos"

log() { echo "vaultos-firstboot $(date -Iseconds) $*" >>"$LOG"; }

in_test() { [[ -n "$P" ]]; }

host_cmd() {
  if in_test; then
    return 0
  fi
  "$@"
}

stamp_ok() {
  {
    echo "done=$(date -Iseconds)"
    echo "reason=${1:-ok}"
    echo "user=${2:-}"
    echo "hostname=$(cat "${P}/etc/hostname" 2>/dev/null || true)"
    echo "timezone=$(cat "${P}/etc/timezone" 2>/dev/null || readlink "${P}/etc/localtime" 2>/dev/null || true)"
  } >"$STAMP"
  chmod 0644 "$STAMP"
  cp -f "$STAMP" "$USER_STAMP" 2>/dev/null || true
  log "stamped $STAMP ($1)"
}

# --- skip / live / unattended ----------------------------------------------

SKIP=0
ANSWER_FILE=""
declare -A ANSWERS=()

parse_cmdline() {
  local t cl
  if in_test && [[ -n "${VAULTOS_TEST_CMDLINE+x}" ]]; then
    cl="$VAULTOS_TEST_CMDLINE"
  else
    [[ -r /proc/cmdline ]] || return 0
    cl="$(cat /proc/cmdline)"
  fi
  for t in $cl; do
    case "$t" in
      vaultos.firstboot=skip) SKIP=1 ;;
      vaultos.firstboot=*) ANSWER_FILE="${t#vaultos.firstboot=}" ;;
    esac
  done
}

# --- answers file hygiene ----------------------------------------------------
# The answers file can hold password= and wifi_psk= in clear text. Only read
# it when it is a regular file owned by root:root with mode 0600 (tightened
# with a warning if loose; refused if not root-owned or a symlink). After a
# successful run it is shredded; after a failed run it stays, still 0600, so
# the next boot can retry.
ANSWER_PATH=""
STAMPED=0

warn() { echo "vaultos-firstboot: $*" >&2; log "warn: $*"; }

answers_owner() {
  # root:root on a real system; the harness user under VAULTOS_TEST_ROOT.
  if in_test; then echo "$(id -u) $(id -g)"; else echo "0 0"; fi
}

answers_file_secure() {
  local f="$1" uid gid mode want_u want_g
  read -r want_u want_g < <(answers_owner)
  if [[ -L "$f" || ! -f "$f" ]]; then
    warn "answers file $f is not a regular file; ignoring it"
    return 1
  fi
  read -r uid gid mode < <(stat -c '%u %g %a' "$f")
  if [[ "$uid" != "$want_u" ]]; then
    warn "answers file $f is owned by uid $uid, not root; ignoring it"
    return 1
  fi
  if [[ "$gid" != "$want_g" ]] || (( 8#$mode & 8#7177 )); then
    warn "answers file $f was mode $mode group $gid; setting 0600 root:root. A password in it may already have been readable."
    if ! { chown "$want_u:$want_g" "$f" && chmod 0600 "$f"; }; then
      warn "could not secure $f; ignoring it"
      return 1
    fi
  fi
  return 0
}

remove_answers() {
  local f="$ANSWER_PATH"
  [[ -n "$f" && -f "$f" && ! -L "$f" ]] || return 0
  if command -v shred >/dev/null 2>&1 && shred -u -z "$f" 2>/dev/null; then
    log "answers file $f shredded"
  elif rm -f "$f" 2>/dev/null; then
    log "answers file $f removed (shred unavailable or failed)"
  else
    # Read-only media or similar: at least drop the secrets.
    sed -i -E '/^[[:space:]]*(password|wifi_psk)[[:space:]]*=/d' "$f" 2>/dev/null \
      && warn "could not delete $f; removed password keys from it" \
      || warn "could not delete or scrub $f; remove it by hand"
  fi
  ANSWER_PATH=""
}

keep_answers_for_retry() {
  local f="$ANSWER_PATH" want_u want_g
  [[ -n "$f" && -f "$f" && ! -L "$f" ]] || return 0
  read -r want_u want_g < <(answers_owner)
  chown "$want_u:$want_g" "$f" 2>/dev/null || true
  chmod 0600 "$f" 2>/dev/null || true
  log "answers file $f kept (0600) for the next attempt"
}

finish_ok() {
  # The stamp is the commit point: after it, never roll back.
  stamp_ok "$@"
  STAMPED=1
  remove_answers || true
}

load_answers() {
  local f="${VAULTOS_FIRSTBOOT_CONF:-$ANSWER_FILE}"
  [[ -z "$f" && -f "$CONF_DEFAULT" ]] && f="$CONF_DEFAULT"
  [[ -n "$f" ]] || return 0
  [[ -e "$f" || -L "$f" ]] || return 0
  answers_file_secure "$f" || return 0
  ANSWER_PATH="$f"
  log "answers $f"
  local line k v
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    k="${line%%=*}"
    v="${line#*=}"
    ANSWERS["$k"]="$v"
  done <"$f"
}

if [[ -d /run/archiso || -f /run/archiso/bootmnt ]] && ! in_test; then
  stamp_ok live
  exit 0
fi

parse_cmdline
load_answers
[[ "${ANSWERS[skip]:-}" == "1" ]] && SKIP=1

if [[ "$SKIP" -eq 1 ]]; then
  finish_ok skip
  exit 0
fi

if [[ -f "$STAMP" ]]; then
  log "already stamped"
  exit 0
fi

# --- passwd / shadow helpers -----------------------------------------------

shadow_hash_for() {
  local name="$1" line hash
  [[ -f "${P}/etc/shadow" ]] || return 1
  line=$(awk -F: -v n="$name" '$1==n{print $2; exit}' "${P}/etc/shadow" 2>/dev/null || true)
  printf '%s' "$line"
}

hash_usable() {
  local h="$1"
  [[ -n "$h" && "$h" != '!' && "$h" != '*' && "$h" != '!!' && "$h" == \$* ]]
}

first_login_user() {
  local name uid
  while IFS=: read -r name _ uid _; do
    if [[ "${uid:-}" =~ ^[0-9]+$ ]] && (( uid >= 1000 && uid < 65534 )); then
      echo "$name"
      return 0
    fi
  done < "${P}/etc/passwd"
  return 1
}

RESET_ONLY=""
if existing=$(first_login_user); then
  h=$(shadow_hash_for "$existing" || true)
  if hash_usable "$h"; then
    finish_ok existing-user "$existing"
    exit 0
  fi
  RESET_ONLY="$existing"
  log "user $existing has no usable password; reset-only"
fi

# --- console (real boot only) ----------------------------------------------

if ! in_test; then
  if [[ -c /dev/tty1 ]]; then
    exec </dev/tty1 >/dev/tty1 2>/dev/tty1 || true
  fi
  command -v plymouth >/dev/null 2>&1 && plymouth quit 2>/dev/null || true
fi

trap 'log "interrupted"; echo; echo "Setup cancelled. Reboot to try again."; exit 1' INT

# --- typeahead -------------------------------------------------------------
# Keys typed while a slow step runs (locale-gen, localectl) used to land in the
# NEXT prompt: on a real console a password typed early became the username
# and was echoed in clear. Stop echo during slow steps and throw away anything
# pending before every interactive prompt. Only acts when stdin is a TTY.
TTY_SAVED=""
hold_input() {
  [[ -t 0 ]] || return 0
  [[ -n "$TTY_SAVED" ]] || TTY_SAVED="$(stty -g 2>/dev/null || true)"
  stty -echo 2>/dev/null || true
}
restore_tty() {
  if [[ -n "$TTY_SAVED" ]]; then
    stty "$TTY_SAVED" 2>/dev/null || true
    TTY_SAVED=""
  fi
}
drain_input() {
  [[ -t 0 ]] || return 0
  local junk
  # read -n 1 runs non-canonical, so half-typed lines (no Enter) are drained too.
  while IFS= read -r -s -n 1 -t 0.05 junk; do :; done
  restore_tty
}

ask() {
  # ask KEY DEFAULT PROMPT
  local key="$1" def="$2" prompt="$3"
  if [[ -n "${ANSWERS[$key]:-}" ]]; then
    REPLY="${ANSWERS[$key]}"
    echo "$prompt [$def]: $REPLY"
    return 0
  fi
  drain_input
  printf '%s [%s]: ' "$prompt" "$def"
  IFS= read -r REPLY || return 1
  REPLY="${REPLY:-$def}"
}

# --- 1. machine ------------------------------------------------------------

valid_hostname() {
  local h="${1,,}"
  [[ "$h" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

apply_hostname() {
  local h="$1"
  echo "$h" >"${P}/etc/hostname"
  if ! in_test && command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl set-hostname "$h" || true
  fi
  if [[ -f "${P}/etc/hosts" ]]; then
    if grep -qE '^127\.0\.1\.1[[:space:]]' "${P}/etc/hosts"; then
      sed -i "s/^127\\.0\\.1\\.1.*/127.0.1.1\\t${h}/" "${P}/etc/hosts"
    else
      printf '127.0.1.1\t%s\n' "$h" >>"${P}/etc/hosts"
    fi
  else
    printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n' "$h" >"${P}/etc/hosts"
  fi
  log "hostname $h"
}

list_timezones() {
  if command -v timedatectl >/dev/null 2>&1 && ! in_test; then
    timedatectl list-timezones 2>/dev/null && return 0
  fi
  if [[ -d "${P}/usr/share/zoneinfo" || -d /usr/share/zoneinfo ]]; then
    local z="${P}/usr/share/zoneinfo"
    [[ -d "$z" ]] || z=/usr/share/zoneinfo
    find "$z" -type f ! -path '*/posix/*' ! -path '*/right/*' \
      | sed "s|^$z/||" | grep -E '^[A-Z]' | sort
  fi
}

valid_timezone() {
  local tz="$1"
  # A zone is a file under zoneinfo. Reject directories ("America"), absolute
  # paths, and ".." so /etc/localtime never points outside zoneinfo.
  [[ -n "$tz" && "$tz" != /* && "$tz" != *..* ]] || return 1
  [[ -f "${P}/usr/share/zoneinfo/$tz" || -f "/usr/share/zoneinfo/$tz" ]]
}

apply_timezone() {
  local tz="$1"
  echo "$tz" >"${P}/etc/timezone"
  mkdir -p "${P}/etc"
  local src="/usr/share/zoneinfo/$tz"
  [[ -e "${P}/usr/share/zoneinfo/$tz" ]] && src="${P}/usr/share/zoneinfo/$tz"
  ln -sfn "$src" "${P}/etc/localtime"
  if ! in_test && command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone "$tz" || true
  fi
  log "timezone $tz"
}

apply_locale() {
  local loc="$1"
  local gen="${P}/etc/locale.gen"
  mkdir -p "${P}/etc"
  touch "$gen"
  if grep -qE "^#\\s*${loc}[[:space:]]" "$gen"; then
    sed -i "s/^#\\s*${loc}[[:space:]]/${loc} /" "$gen"
  elif ! grep -qE "^${loc}[[:space:]]" "$gen"; then
    echo "${loc} UTF-8" >>"$gen"
  fi
  echo "LANG=${loc}" >"${P}/etc/locale.conf"
  if ! in_test && command -v locale-gen >/dev/null 2>&1; then
    locale-gen >/dev/null || locale-gen || true
  fi
  if ! in_test && command -v localectl >/dev/null 2>&1; then
    localectl set-locale "LANG=${loc}" || true
  fi
  log "locale $loc"
}

apply_keymap() {
  local km="$1"
  mkdir -p "${P}/etc/vconsole.d" "${P}/etc/X11/xorg.conf.d" "${P}/etc"
  echo "KEYMAP=${km}" >"${P}/etc/vconsole.conf"
  cat >"${P}/etc/X11/xorg.conf.d/00-keyboard.conf" <<EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "${km}"
EndSection
EOF
  if ! in_test && command -v localectl >/dev/null 2>&1; then
    localectl set-keymap "$km" || true
    localectl set-x11-keymap "$km" || true
  fi
  log "keymap $km"
}

net_online() {
  in_test && [[ "${ANSWERS[online]:-0}" == "1" ]] && return 0
  in_test && return 1
  ping -c1 -W2 9.9.9.9 >/dev/null 2>&1 && return 0
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && return 0
  return 1
}

wifi_device() {
  in_test && { echo "${ANSWERS[wifi_dev]:-}"; [[ -n "${ANSWERS[wifi_dev]:-}" ]]; return; }
  command -v nmcli >/dev/null 2>&1 || return 1
  # Fail when there is no Wi-Fi device (awk alone always exited 0).
  nmcli -t -f TYPE,DEVICE device status 2>/dev/null \
    | awk -F: '$1=="wifi"{print $2; f=1; exit} END{exit !f}'
}

apply_wifi() {
  local ssid="$1" psk="$2"
  log "wifi ssid=$ssid"
  in_test && return 0
  if command -v nmcli >/dev/null 2>&1; then
    nmcli device wifi connect "$ssid" password "$psk" && return 0
  fi
  if command -v iwctl >/dev/null 2>&1; then
    local dev
    dev=$(wifi_device || true)
    [[ -n "$dev" ]] || return 1
    iwctl --passphrase "$psk" station "$dev" connect "$ssid" || return 1
  fi
}

prompt_machine() {
  local h tz loc km ssid psk q
  echo
  echo "  Vault.OS setup"
  echo "  ──────────────"
  echo "  Enter accepts the value in [brackets]."
  echo

  while true; do
    ask hostname vaultos "Hostname"
    h="${REPLY,,}"
    valid_hostname "$h" && break
    echo "Use letters, digits, and hyphen (RFC 1123). Try again."
    # Without this a bad hostname= in the answers file looped forever.
    ANSWERS[hostname]=""
  done
  apply_hostname "$h"

  while true; do
    ask timezone UTC "Timezone (type a zone, or a search like 'New_York')"
    tz="$REPLY"
    if valid_timezone "$tz"; then
      break
    fi
    echo "Matches:"
    list_timezones | grep -i -- "$tz" | head -20 || true
    echo "Type a full zone from the list (example: America/New_York)."
    ANSWERS[timezone]=""
  done
  apply_timezone "$tz"

  while true; do
    ask locale en_US.UTF-8 "Locale"
    loc="$REPLY"
    [[ "$loc" =~ ^[A-Za-z0-9_@.-]+$ ]] && break
    echo "Example: en_US.UTF-8"
    ANSWERS[locale]=""
  done
  echo "Applying locale ${loc}… (this can take a few seconds; please wait)"
  hold_input
  apply_locale "$loc"

  while true; do
    ask keymap us "Keyboard layout"
    km="${REPLY,,}"
    [[ "$km" =~ ^[a-z0-9_-]+$ ]] && break
    echo "Example: us, uk, de, fr"
    ANSWERS[keymap]=""
  done
  echo "Applying keyboard layout ${km}… (please wait)"
  hold_input
  apply_keymap "$km"

  if net_online; then
    echo "Network: online."
  else
    echo "Network: offline."
    if wifi_device >/dev/null; then
      # skip_wifi=1 in the answers file means "skip". It used to be fed in as
      # the answer to "Connect?", so skip_wifi=yes connected instead.
      q="${ANSWERS[skip_wifi]:-}"
      case "${q,,}" in
        1|y|yes|true) q=n ;;
        0|n|no|false) q=y ;;
        *) ask connect_wifi n "Connect Wi-Fi now? (y/n)"; q="${REPLY,,}" ;;
      esac
      if [[ "$q" == y || "$q" == yes ]]; then
        ask wifi_ssid "" "Wi-Fi SSID"
        ssid="$REPLY"
        if [[ -n "$ssid" ]]; then
          if [[ -n "${ANSWERS[wifi_psk]:-}" ]]; then
            psk="${ANSWERS[wifi_psk]}"
          else
            drain_input
            printf 'Wi-Fi password: '
            IFS= read -rs psk || true
            echo
          fi
          apply_wifi "$ssid" "$psk" || echo "Wi-Fi connect failed; you can set it up after login."
        fi
      else
        echo "Skipping Wi-Fi."
      fi
    else
      echo "No Wi-Fi device detected. Plug in Ethernet or configure after login."
    fi
  fi
}

# --- 2. account ------------------------------------------------------------

reserved() {
  case "$1" in
    root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|nobody|nfsnobody|nobody4|nogroup|guest|vaultos-live)
      return 0 ;;
  esac
  [[ "$1" == systemd-* ]] && return 0
  return 1
}

valid_name() {
  local u="$1"
  [[ "$u" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
  reserved "$u" && return 1
  return 0
}

ensure_wheel_sudo() {
  local drop="${P}/etc/sudoers.d/wheel"
  local tmp
  mkdir -p "${P}/etc/sudoers.d"
  mkdir -p "${P}/tmp" "${P}/etc/sudoers.d"
  tmp="$(mktemp "${P}/tmp/vaultos-sudoers.XXXXXX" 2>/dev/null || mktemp)"
  printf '%%wheel ALL=(ALL:ALL) ALL\n' >"$tmp"
  if command -v visudo >/dev/null 2>&1; then
    visudo -c -f "$tmp" >/dev/null || { rm -f "$tmp"; echo "sudoers drop-in failed visudo -c"; return 1; }
  fi
  install -m 0440 "$tmp" "$drop"
  rm -f "$tmp"
  log "sudoers $drop"
}

read_password() {
  local p1 p2
  if [[ -n "${ANSWERS[password]+x}" ]]; then
    PW="${ANSWERS[password]}"
    [[ -n "$PW" ]] || { echo "Password cannot be empty."; return 1; }
    return 0
  fi
  while true; do
    drain_input
    printf 'Password: '
    IFS= read -rs p1 || return 1
    echo
    drain_input
    printf 'Password (again): '
    IFS= read -rs p2 || return 1
    echo
    if [[ -z "$p1" ]]; then
      echo "Password cannot be empty."
      continue
    fi
    if [[ "$p1" != "$p2" ]]; then
      echo "Passwords do not match."
      continue
    fi
    PW="$p1"
    return 0
  done
}

set_password() {
  local user="$1" pw="$2"
  if in_test; then
    local hash
    hash=$(openssl passwd -6 "$pw" 2>/dev/null || printf '$6$testsalt$testhash')
    if grep -qE "^${user}:" "${P}/etc/shadow" 2>/dev/null; then
      sed -i "s|^${user}:[^:]*:|${user}:${hash}:|" "${P}/etc/shadow"
    else
      echo "${user}:${hash}:1:0:99999:7:::" >>"${P}/etc/shadow"
    fi
    return 0
  fi
  printf '%s:%s\n' "$user" "$pw" | chpasswd
}

test_useradd() {
  local user="$1" groups="$2"
  echo "${user}:x:1000:1000::${P}/home/${user}:/bin/bash" >>"${P}/etc/passwd"
  echo "${user}:x:1000:" >>"${P}/etc/group"
  mkdir -p "${P}/home/${user}"
  local g
  IFS=',' read -ra _gs <<<"$groups"
  for g in "${_gs[@]}"; do
    [[ -z "$g" ]] && continue
    if grep -qE "^${g}:" "${P}/etc/group"; then
      awk -F: -v OFS=: -v g="$g" -v u="$user" \
        '$1==g{$4 = ($4=="" ? u : $4 "," u)} {print}' \
        "${P}/etc/group" >"${P}/etc/group.tmp" && mv "${P}/etc/group.tmp" "${P}/etc/group"
    fi
  done
}

existing_groups() {
  local want=("$@") g out=()
  for g in "${want[@]}"; do
    if in_test; then
      grep -qE "^${g}:" "${P}/etc/group" 2>/dev/null && out+=("$g")
    else
      getent group "$g" >/dev/null 2>&1 && out+=("$g")
    fi
  done
  (IFS=','; echo "${out[*]}")
}

seed_skel_home() {
  local home="$1" who="$2"
  local skel="${LIB}/overlay/skel"
  [[ -d "$skel" ]] || skel="$(cd "$(dirname "$0")/../overlay/skel" 2>/dev/null && pwd)" || true
  if [[ -d "$skel" ]]; then
    mkdir -p "$home"
    cp -a "$skel"/. "$home"/ 2>/dev/null || true
  fi
  if [[ -x "${LIB}/../bin/vault-os" ]]; then
    in_test && return 0
    sudo -u "$who" -H env HOME="$home" \
      "${LIB}/../bin/vault-os" install >/dev/null 2>&1 || true
  fi
}

set_lightdm_session() {
  local d="${P}/etc/lightdm/lightdm.conf.d"
  mkdir -p "$d" "${P}/usr/share/xsessions"
  cat >"$d/50-vaultos.conf" <<'LD'
[Seat:*]
user-session=vaultos
greeter-session=lightdm-gtk-greeter
greeter-hide-users=false
greeter-show-manual-login=true
LD
  local xs="${LIB}/overlay/xsessions/vaultos.desktop"
  if [[ -f "$xs" ]]; then
    install -m 0644 "$xs" "${P}/usr/share/xsessions/vaultos.desktop"
  fi
  log "lightdm user-session=vaultos"
}

prompt_account() {
  local user groups home
  echo
  if [[ -n "$RESET_ONLY" ]]; then
    echo "Account $RESET_ONLY exists but has no password. Set one now."
    user="$RESET_ONLY"
    read_password || return 1
    set_password "$user" "$PW"
    PW=""
    ensure_wheel_sudo
    set_lightdm_session
    echo "Password updated for $user."
    return 0
  fi

  echo "  Create the account you will log in with."
  echo "  Username: lowercase letters, digits, _ or -  (not root)."
  echo
  while true; do
    ask username "" "Username"
    user="${REPLY,,}"
    user="${user// /}"
    if ! valid_name "$user"; then
      echo "That username is not allowed. Try another."
      ANSWERS[username]=""
      continue
    fi
    if grep -qE "^${user}:" "${P}/etc/passwd" 2>/dev/null; then
      echo "That username is taken."
      ANSWERS[username]=""
      continue
    fi
    break
  done

  read_password || return 1

  groups=$(existing_groups wheel video audio input network)
  home="${P}/home/${user}"
  if in_test; then
    test_useradd "$user" "$groups"
  else
    # shellcheck disable=SC2086
    if [[ -n "$groups" ]]; then
      useradd -m -G "$groups" -s /bin/bash "$user"
    else
      useradd -m -s /bin/bash "$user"
    fi
  fi
  CREATED_USER="$user"

  if ! set_password "$user" "$PW"; then
    echo "Could not set password."
    return 1
  fi
  PW=""

  ensure_wheel_sudo
  seed_skel_home "$home" "$user"
  if ! in_test; then
    chown -R "${user}:${user}" "$home" 2>/dev/null || true
  fi
  set_lightdm_session
  echo
  echo "Account $user is ready."
}

rollback_user() {
  local u="${CREATED_USER:-}"
  [[ -n "$u" ]] || return 0
  log "rollback $u"
  if in_test; then
    # cat > keeps each file's mode (mv would leave the fake shadow 0644).
    grep -vE "^${u}:" "${P}/etc/passwd" >"${P}/etc/passwd.tmp" 2>/dev/null || true
    cat "${P}/etc/passwd.tmp" >"${P}/etc/passwd" 2>/dev/null || true
    grep -vE "^${u}:" "${P}/etc/shadow" >"${P}/etc/shadow.tmp" 2>/dev/null || true
    cat "${P}/etc/shadow.tmp" >"${P}/etc/shadow" 2>/dev/null || true
    awk -F: -v OFS=: -v u="$u" '$1==u{next} {
        n=split($4, m, ","); s=""
        for (i=1; i<=n; i++) if (m[i]!=u && m[i]!="") s = (s=="" ? m[i] : s "," m[i])
        $4=s; print }' "${P}/etc/group" >"${P}/etc/group.tmp" 2>/dev/null \
      && cat "${P}/etc/group.tmp" >"${P}/etc/group" 2>/dev/null || true
    rm -f "${P}/etc/passwd.tmp" "${P}/etc/shadow.tmp" "${P}/etc/group.tmp"
    rm -rf "${P}/home/${u}"
  else
    userdel -r "$u" 2>/dev/null || true
  fi
  CREATED_USER=""
}

CREATED_USER=""
# Roll back on ANY non-zero exit. An ERR trap alone is not enough: without
# errtrace, set -e exits from inside a function (ensure_wheel_sudo,
# set_lightdm_session, ...) without firing it, leaving a half-made user that
# the next boot treats as an existing account and skips.
CANCELLED=0
on_exit() {
  local rc=$?
  trap - EXIT
  restore_tty
  if (( rc != 0 && STAMPED )); then
    # Account and stamp are in place; a late error (e.g. a hung-up tty on
    # the final echo) must not delete the user or block LightDM.
    log "error rc=$rc after stamp; keeping account"
    exit 0
  fi
  if (( rc != 0 )); then
    log "fail rc=$rc"
    rollback_user || true
    keep_answers_for_retry || true
    echo
    if (( CANCELLED )); then
      echo "Setup cancelled. Reboot to try again."
    else
      echo "Setup failed. Reboot to try again."
    fi
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'log "interrupted"; CANCELLED=1; exit 130' INT
trap 'log "terminated"; CANCELLED=1; exit 143' TERM HUP

clear 2>/dev/null || true
prompt_machine
prompt_account
finish_ok created "${CREATED_USER:-$RESET_ONLY}"
echo "Continuing to login…"
sleep 1
exit 0

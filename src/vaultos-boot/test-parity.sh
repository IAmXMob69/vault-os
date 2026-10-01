#!/usr/bin/env bash
# Parity test: overlay/libexec/vaultos-core.sh and vaultos-firstboot.sh vs
# the native `vaultos-boot core|identity`. Every case runs both against its
# own fake root and diffs exit codes, stdout/stderr, file trees, modes and
# contents (timestamps masked). The "real" cases run with no test root
# inside a private user+mount namespace (unshare -rm) with /var/lib, /var/log
# and /etc/os-release bind-mounted from a temp dir and stub systemctl and
# identity-apply.sh, so the host is never written. KEEP=1 keeps the temp dir.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BIN="${VAULTOS_BOOT_BIN:-$HERE/vaultos-boot}"
[[ -x "$BIN" ]] || { echo "build first: make -C src/vaultos-boot" >&2; exit 2; }
T="$(mktemp -d)"
[[ -n "${KEEP:-}" ]] && echo "temp: $T" || trap 'rm -rf "$T"' EXIT
umask 022
pass=0 fail=0
ok() { echo "PASS $*"; pass=$((pass + 1)); }
bad() { echo "FAIL $*"; fail=$((fail + 1)); }
TSRE='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[-+][0-9]{2}:[0-9]{2}'

impl_cmd() {  # impl tool
  case "$1:$2" in
    sh:core) echo "$REPO/overlay/libexec/vaultos-core.sh" ;;
    sh:identity) echo "$REPO/overlay/libexec/vaultos-firstboot.sh" ;;
    cxx:*) echo "$BIN $2" ;;
  esac
}

# snapshot DIR -> tree listing + masked contents
snap() {
  (cd "$1" && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r f; do
    if [[ -L "$f" ]]; then echo "L $f -> $(readlink "$f")"
    elif [[ -d "$f" ]]; then echo "D $f $(stat -c %a "$f")"
    else echo "F $f $(stat -c %a "$f")"; sed -E "s/$TSRE/TS/g" "$f" | sed 's/^/  | /'; fi
  done)
}

# setup ROOT LIB variant...
mklib() {  # dir overlay_ver lib_ver ia(0/1)
  mkdir -p "$1/overlay"
  [[ -n "$2" ]] && printf '%b' "$2" >"$1/overlay/VERSION"
  [[ -n "$3" ]] && printf '%b' "$3" >"$1/VERSION"
  if [[ "$4" == 1 ]]; then
    printf '#!/bin/sh\necho "identity-apply stub: $*"\necho "stub stderr" >&2\n' >"$1/overlay/identity-apply.sh"
    chmod +x "$1/overlay/identity-apply.sh"
  fi
}

# case NAME TOOL OSREL(content or "-" for none) OVER_VER LIB_VER IA PREP(cmd run in root)
fake_case() {
  local name=$1 tool=$2 osr=$3 ov=$4 lv=$5 ia=$6 prep=${7:-true} runs=${8:-1}
  local i
  for impl in sh cxx; do
    local d="$T/$name/$impl"
    mkdir -p "$d/root/etc"
    mklib "$d/lib" "$ov" "$lv" "$ia"
    [[ "$osr" != - ]] && printf '%b' "$osr" >"$d/root/etc/os-release"
    (cd "$d/root" && eval "$prep")
    : >"$d/out"
    for ((i = 0; i < runs; i++)); do
      VAULTOS_TEST_ROOT="$d/root" VAULTOS_LIB="$d/lib" $(impl_cmd $impl $tool) >>"$d/out" 2>"$d/err"
      echo "rc=$?" >>"$d/out"
    done
    snap "$d/root" >"$d/tree"
    # mask timestamps and the per-impl temp path; drop error-message lines
    # (bash prints "SCRIPT: line N: ..." where the binary names itself)
    sed -E -e "s/$TSRE/TS/g" -e "s|$d/|D/|g" -e '/: (Is a directory|Not a directory|No such file)/d' \
      -i "$d/out" "$d/tree" "$d/err"
  done
  local a="$T/$name/sh" b="$T/$name/cxx"
  if diff -u "$a/tree" "$b/tree" >"$T/$name/d.tree" && diff -u "$a/out" "$b/out" >"$T/$name/d.out"; then
    if [[ "${STDERR_SAME:-1}" == 1 ]] && ! diff -u "$a/err" "$b/err" >"$T/$name/d.err"; then
      bad "$name: stderr differs"; cat "$T/$name/d.err"
    else ok "$name"; fi
  else
    bad "$name"; cat "$T/$name/d.tree" "$T/$name/d.out" 2>/dev/null
  fi
}

ARCH='NAME="Arch Linux"\nID=arch\nBUILD_ID=rolling\n'
VOS='NAME="Vault.OS"\nID=vaultos\nID_LIKE=arch\n'
for tool in core identity; do
  fake_case $tool-arch $tool "$ARCH" '1.5.21\n' '' 1
  fake_case $tool-vaultos $tool "$VOS" '1.5.21\n' '' 1
  fake_case $tool-no-osrel $tool - '1.5.21\n' '' 1
  fake_case $tool-quoted-id $tool 'ID="arch"\nID=second\n' '1.5.21\n' '' 1
  fake_case $tool-id-eq $tool 'NAME=x\nID=a=b' '' '' 1
  fake_case $tool-no-ia $tool "$ARCH" '1.5.21\n' '' 0
  fake_case $tool-ver-both $tool "$ARCH" '1.0\n' '2.0\nextra\n' 1
  fake_case $tool-ver-nonl $tool "$ARCH" '' '3.1' 0
  fake_case $tool-no-ver $tool "$ARCH" '' '' 0
  fake_case $tool-keep-mode $tool "$ARCH" '1\n' '' 0 \
    'mkdir -p var/lib/vaultos && : >var/lib/vaultos/core-state && chmod 600 var/lib/vaultos/core-state && : >var/lib/vaultos/x'
  STDERR_SAME=0 fake_case $tool-unwritable $tool "$ARCH" '1\n' '' 1 'echo file >var'
done
fake_case identity-twice identity "$ARCH" '1\n' '' 1 true 2
fake_case identity-prestamped identity "$ARCH" '1\n' '' 1 \
  'mkdir -p var/lib/vaultos var/log && echo old >var/lib/vaultos/identity-applied && echo prev >var/log/vaultos-firstboot.log'
fake_case identity-stamp-dir identity "$ARCH" '1\n' '' 1 'mkdir -p var/lib/vaultos/identity-applied' 
fake_case identity-log-mode identity "$ARCH" '1\n' '' 0 \
  'mkdir -p var/log && : >var/log/vaultos-firstboot.log && chmod 640 var/log/vaultos-firstboot.log'

# Real mode (no test root) in a private namespace with bind mounts.
if unshare -rm true 2>/dev/null; then
  real_case() {  # name tool osrel nm(0/1)
    local name=$1 tool=$2 osr=$3 nm=$4
    for impl in sh cxx; do
      local d="$T/$name/$impl"
      mkdir -p "$d/varlib" "$d/varlog" "$d/stub"
      mklib "$d/lib" '9.9\n' '' 1
      printf '%b' "$osr" >"$d/osrel"
      cat >"$d/stub/systemctl" <<STUB
#!/bin/sh
echo "systemctl \$*" >>"$d/calls"
[ "\$1" = list-unit-files ] && { [ "$nm" = 1 ] && echo "NetworkManager.service enabled" || exit 1; }
exit 0
STUB
      chmod +x "$d/stub/systemctl"
      : >"$d/calls"
      unshare -rm bash -c '
        mount --bind "$1/varlib" /var/lib && mount --bind "$1/varlog" /var/log &&
        mount --bind "$1/osrel" /etc/os-release || exit 99
        PATH="$1/stub:$PATH" VAULTOS_LIB="$1/lib" '"$(impl_cmd $impl $tool)"'
        echo "rc=$?"' _ "$d" >"$d/out" 2>"$d/err"
      { snap "$d/varlib"; snap "$d/varlog"; echo "calls:"; cat "$d/calls"; } >"$d/tree"
      sed -E "s/$TSRE/TS/g" -i "$d/out" "$d/tree"
    done
    local a="$T/$name/sh" b="$T/$name/cxx"
    if diff -u "$a/tree" "$b/tree" && diff -u "$a/out" "$b/out" && diff -u "$a/err" "$b/err"; then
      ok "$name"
    else bad "$name"; fi
  }
  real_case real-core-arch core "$ARCH" 1
  real_case real-core-vaultos core "$VOS" 1
  real_case real-identity-arch identity "$ARCH" 1
  real_case real-identity-no-nm identity "$ARCH" 0
  real_case real-identity-vaultos identity "$VOS" 1
  # sanity: the stubs really ran in the real cases
  grep -q 'identity-apply stub: apply' "$T/real-core-arch/cxx/varlog/vaultos-core-identity.log" &&
    grep -q 'systemctl start NetworkManager.service' "$T/real-identity-arch/cxx/calls" &&
    ! grep -q 'enable' "$T/real-identity-no-nm/cxx/calls" &&
    grep -q 'identity-apply stub: apply' "$T/real-identity-arch/cxx/varlog/vaultos-firstboot.log" &&
    ok "real-mode stubs exercised" || bad "real-mode stubs not exercised"
else
  echo "SKIP real-mode cases: unshare -rm not permitted"
fi

# usage / bad args
"$BIN" --help >/dev/null && ok "--help exits 0" || bad "--help"
"$BIN" bogus >/dev/null 2>&1; [[ $? == 2 ]] && ok "bad subcommand exits 2" || bad "bad subcommand"

echo "== $pass passed, $fail failed"
[[ $fail == 0 ]]

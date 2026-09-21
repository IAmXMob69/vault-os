#!/usr/bin/env bash
# First-boot wizard tests. Does not touch the host /etc, /boot, or LightDM.
# Primary path: fake rootfs + VAULTOS_TEST_ROOT (no QEMU required).
# Optional: if vaultos-*.iso exists, remind that qemu-smoke is live-ISO only
# (the wizard is skipped on /run/archiso).
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
WIZ="$ROOT/overlay/libexec/vaultos-firstuser.sh"
IDEN="$ROOT/overlay/libexec/vaultos-firstboot.sh"
UNIT="$ROOT/overlay/systemd/vaultos-firstuser.service"
FAIL=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }

bash -n "$WIZ" && pass "bash -n firstuser" || fail "bash -n firstuser"
bash -n "$IDEN" && pass "bash -n firstboot" || fail "bash -n firstboot"
bash -n "$ROOT/iso/airootfs/usr/local/bin/vaultos-install" && pass "bash -n vaultos-install" || fail "bash -n install"

# --- unit ordering (issue 3) ---
for needle in \
  'Before=display-manager.service lightdm.service' \
  'After=local-fs.target systemd-user-sessions.service plymouth-quit-wait.service' \
  'Conflicts=getty@tty1.service' \
  'TTYPath=/dev/tty1' \
  'TTYReset=yes' \
  'RemainAfterExit=yes' \
  'Type=oneshot'
 do
  grep -qF "$needle" "$UNIT" && pass "unit $needle" || fail "unit missing $needle"
done

grep -n 'useradd.*vaultos' "$ROOT/iso/airootfs/usr/local/bin/vaultos-install" \
  && fail "installer still pre-creates user vaultos" \
  || pass "installer does not pre-create vaultos user"
grep -q 'vaultos-firstuser.service' "$ROOT/iso/airootfs/usr/local/bin/vaultos-install" \
  && pass "installer enables firstuser" || fail "installer missing firstuser enable"
grep -q 'Do NOT enable or start vaultos-firstuser' "$ROOT/overlay/install-system.sh" \
  && pass "install-system.sh does not enable wizard" || fail "install-system enables wizard"

# --- fake root ---
work=$(mktemp -d /tmp/vaultos-firstboot-test.XXXXXX)
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

prep_root() {
  local r="$1"
  rm -rf "$r"
  mkdir -p "$r/etc" "$r/var/lib/vaultos" "$r/var/log" "$r/home" "$r/tmp" \
    "$r/etc/sudoers.d" "$r/usr/share/xsessions" "$r/etc/lightdm/lightdm.conf.d"
  printf 'root:x:0:0:root:/root:/bin/bash\nnobody:x:65534:65534:nobody:/:/usr/bin/nologin\n' >"$r/etc/passwd"
  printf 'root:*:1:0:99999:7:::\nnobody:*:1:0:99999:7:::\n' >"$r/etc/shadow"
  printf 'root:x:0:\nwheel:x:998:\nvideo:x:986:\naudio:x:995:\ninput:x:997:\nnetwork:x:996:\n' >"$r/etc/group"
  : >"$r/etc/hostname"
  ln -sfn /usr/share/zoneinfo/UTC "$r/etc/localtime"
  echo 'en_US.UTF-8 UTF-8' >"$r/etc/locale.gen"
  chmod 0640 "$r/etc/shadow"
}

run_wiz() {
  local r="$1" conf="$2"
  export VAULTOS_TEST_ROOT="$r"
  export VAULTOS_LIB="$ROOT"
  export VAULTOS_FIRSTBOOT_CONF="$conf"
  "$WIZ"
}

# Happy path
prep_root "$work/ok"
cat >"$work/ok.conf" <<'EOF'
hostname=testhost
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=alice
password=s3cret-ok
skip_wifi=1
online=1
EOF
if run_wiz "$work/ok" "$work/ok.conf"; then
  pass "happy path exit 0"
else
  fail "happy path exit $?"
fi
grep -q '^alice:' "$work/ok/etc/passwd" && pass "user alice exists" || fail "no alice"
grep -q '^wheel:.*alice' "$work/ok/etc/group" && pass "alice in wheel" || fail "alice not in wheel"
[[ "$(cat "$work/ok/etc/hostname")" == testhost ]] && pass "hostname testhost" || fail "hostname $(cat "$work/ok/etc/hostname")"
grep -q UTC "$work/ok/etc/timezone" && pass "timezone UTC" || fail "timezone missing"
[[ -f "$work/ok/var/lib/vaultos/firstboot-done" ]] && pass "firstboot-done exists" || fail "no firstboot-done"
grep -q 'user-session=vaultos' "$work/ok/etc/lightdm/lightdm.conf.d/50-vaultos.conf" \
  && pass "lightdm session vaultos" || fail "lightdm session"
awk -F: '$1=="alice"{print $2}' "$work/ok/etc/shadow" | grep -q '^\$' \
  && pass "alice has password hash" || fail "alice shadow hash"
[[ -f "$work/ok/home/alice/.config/fallout-nv/vault-os.conf" ]] \
  && pass "skel theme seed" || fail "no skel seed"

# Identity script does not write firstboot-done
prep_root "$work/id"
VAULTOS_TEST_ROOT="$work/id" VAULTOS_LIB="$ROOT" "$IDEN" || true
[[ -f "$work/id/var/lib/vaultos/identity-applied" ]] && pass "identity-applied stamp" || fail "no identity stamp"
[[ -f "$work/id/var/lib/vaultos/firstboot-done" ]] && fail "identity wrote firstboot-done" || pass "identity does not stamp firstboot-done"

# Negative: invalid username
prep_root "$work/badname"
cat >"$work/badname.conf" <<'EOF'
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=root
password=x
skip_wifi=1
online=1
EOF
if run_wiz "$work/badname" "$work/badname.conf" >/dev/null 2>&1; then
  fail "root username was accepted"
else
  pass "root username rejected"
fi
[[ -f "$work/badname/var/lib/vaultos/firstboot-done" ]] && fail "stamp after bad username" || pass "no stamp after bad username"

# Negative: empty password
prep_root "$work/emptypw"
cat >"$work/emptypw.conf" <<'EOF'
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=bob
password=
skip_wifi=1
online=1
EOF
if run_wiz "$work/emptypw" "$work/emptypw.conf" >/dev/null 2>&1; then
  fail "empty password accepted"
else
  pass "empty password rejected"
fi
grep -q '^bob:' "$work/emptypw/etc/passwd" && fail "bob left after empty password" || pass "no half-created bob"

# Negative: interrupted (EOF after hostname)
prep_root "$work/eof"
export VAULTOS_TEST_ROOT="$work/eof" VAULTOS_LIB="$ROOT"
unset VAULTOS_FIRSTBOOT_CONF
if printf 'vaultos\n' | "$WIZ" >/dev/null 2>&1; then
  fail "EOF run succeeded"
else
  pass "EOF run failed"
fi
[[ -f "$work/eof/var/lib/vaultos/firstboot-done" ]] && fail "stamp after EOF" || pass "no stamp after EOF"
grep -qE '^alice:|^bob:|^vaultos:' "$work/eof/etc/passwd" && fail "user created after EOF" || pass "no user after EOF"

# Skip: existing user with usable hash
prep_root "$work/exists"
echo 'carol:x:1000:1000::/home/carol:/bin/bash' >>"$work/exists/etc/passwd"
echo 'carol:$6$abc$def:1:0:99999:7:::' >>"$work/exists/etc/shadow"
cat >"$work/exists.conf" <<'EOF'
hostname=nope
username=eve
password=x
online=1
EOF
run_wiz "$work/exists" "$work/exists.conf" >/dev/null 2>&1 || true
grep -q '^eve:' "$work/exists/etc/passwd" && fail "created eve despite existing hash" || pass "skip when usable hash exists"
grep -q 'existing-user' "$work/exists/var/lib/vaultos/firstboot-done" \
  && pass "stamp reason existing-user" || fail "missing existing-user stamp"

# Reset-only: user without hash
prep_root "$work/reset"
echo 'dave:x:1000:1000::/home/dave:/bin/bash' >>"$work/reset/etc/passwd"
echo 'dave:!:1:0:99999:7:::' >>"$work/reset/etc/shadow"
cat >"$work/reset.conf" <<'EOF'
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
password=newpass
skip_wifi=1
online=1
EOF
run_wiz "$work/reset" "$work/reset.conf" >/dev/null 2>&1 || fail "reset-only failed"
awk -F: '$1=="dave"{print $2}' "$work/reset/etc/shadow" | grep -q '^\$' \
  && pass "reset-only set dave password" || fail "dave still locked"
grep -q '^eve:\|^alice:' "$work/reset/etc/passwd" && fail "extra user on reset-only" || pass "reset-only did not add a user"

# Password mismatch via stdin (no answers password)
prep_root "$work/mismatch"
export VAULTOS_TEST_ROOT="$work/mismatch" VAULTOS_LIB="$ROOT"
unset VAULTOS_FIRSTBOOT_CONF
if printf 'vaultos\nUTC\nen_US.UTF-8\nus\nn\nalice\none\ntwo\none\ntwo\n' | "$WIZ" >/dev/null 2>&1; then
  fail "mismatch eventually succeeded unexpectedly"
else
  pass "mismatch/EOF did not finish"
fi
grep -q '^alice:' "$work/mismatch/etc/passwd" && fail "alice left after mismatch abort" || pass "mismatch rolled back / no user"

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "All first-boot tests passed."
  exit 0
fi
echo "$FAIL test(s) failed."
exit 1

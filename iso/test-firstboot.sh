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
  # Never inherit the caller's terminal: a rejected answer falls back to an
  # interactive prompt, which would hang the harness waiting on the keyboard.
  "$WIZ" </dev/null
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
[[ -e "$work/ok.conf" ]] && fail "answers file left after success" || pass "answers file deleted after success"
grep -qE 'answers file .*(shredded|removed)' "$work/ok/var/log/vaultos-firstboot.log" \
  && pass "answers deletion logged" || fail "answers deletion not logged"

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

# Rollback: a failure AFTER useradd (sudoers drop-in rejected) must remove
# the half-created user, or the next boot sees an "existing user" and skips.
prep_root "$work/rollback"
mkdir -p "$work/fakebin"
printf '#!/bin/sh\nexit 1\n' >"$work/fakebin/visudo"
chmod +x "$work/fakebin/visudo"
cat >"$work/rollback.conf" <<'EOF'
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=zed
password=pw-rollback
skip_wifi=1
online=1
EOF
chmod 0644 "$work/rollback.conf"
if PATH="$work/fakebin:$PATH" run_wiz "$work/rollback" "$work/rollback.conf" >/dev/null 2>&1; then
  fail "rollback: run succeeded despite visudo failure"
else
  pass "rollback: visudo failure exits non-zero"
fi
grep -q '^zed:' "$work/rollback/etc/passwd" && fail "rollback: zed left in passwd" || pass "rollback: zed removed from passwd"
grep -q '^zed:' "$work/rollback/etc/shadow" && fail "rollback: zed left in shadow" || pass "rollback: zed removed from shadow"
grep -qE '(^zed:|[:,]zed(,|$))' "$work/rollback/etc/group" && fail "rollback: zed left in group" || pass "rollback: zed removed from group"
[[ -e "$work/rollback/home/zed" ]] && fail "rollback: /home/zed left" || pass "rollback: /home/zed removed"
[[ -f "$work/rollback/var/lib/vaultos/firstboot-done" ]] && fail "rollback: stamp written" || pass "rollback: no stamp"
grep -q 'rollback zed' "$work/rollback/var/log/vaultos-firstboot.log" \
  && pass "rollback: logged" || fail "rollback: not logged"
[[ -f "$work/rollback.conf" ]] && pass "rollback: answers file kept for retry" || fail "rollback: answers file gone"
[[ "$(stat -c %a "$work/rollback.conf" 2>/dev/null)" == 600 ]] \
  && pass "rollback: answers file is 0600" || fail "rollback: answers mode $(stat -c %a "$work/rollback.conf" 2>/dev/null)"
grep -q '^password=pw-rollback$' "$work/rollback.conf" \
  && pass "rollback: answers still usable for retry" || fail "rollback: answers lost the password"
grep -q 'was mode 644' "$work/rollback/var/log/vaultos-firstboot.log" \
  && pass "rollback: loose answers mode warned" || fail "rollback: no warning for mode 644"

# Timezone must be a zone file, not a directory or a path escape.
prep_root "$work/tz"
export VAULTOS_TEST_ROOT="$work/tz" VAULTOS_LIB="$ROOT"
unset VAULTOS_FIRSTBOOT_CONF
printf 'vaultos\nAmerica\n../../../etc/passwd\nUTC\n' | "$WIZ" >/dev/null 2>&1 || true
[[ "$(readlink "$work/tz/etc/localtime")" == */zoneinfo/UTC ]] \
  && pass "timezone rejects directory and .. path" \
  || fail "timezone accepted $(readlink "$work/tz/etc/localtime")"

# skip_wifi=yes means skip (it used to be read as "yes, connect").
for sw in yes 0; do
  prep_root "$work/wifi$sw"
  cat >"$work/wifi$sw.conf" <<EOF
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=wendy
password=pw-wifi
online=0
wifi_dev=wlan0
skip_wifi=$sw
wifi_ssid=testnet
wifi_psk=testpsk
EOF
  run_wiz "$work/wifi$sw" "$work/wifi$sw.conf" >/dev/null 2>&1 || fail "wifi skip_wifi=$sw run failed"
done
grep -q 'wifi ssid=' "$work/wifiyes/var/log/vaultos-firstboot.log" \
  && fail "skip_wifi=yes still connected" || pass "skip_wifi=yes skips Wi-Fi"
grep -q 'wifi ssid=testnet' "$work/wifi0/var/log/vaultos-firstboot.log" \
  && pass "skip_wifi=0 connects Wi-Fi" || fail "skip_wifi=0 did not connect"

# Typeahead on a real TTY: keys typed while locale/keymap apply must be
# discarded, never read as the username, and never as the password
# confirmation. Needs a pty, so drive the wizard from python3's pty module.
if command -v python3 >/dev/null 2>&1; then
  prep_root "$work/tty"
  if python3 - "$WIZ" "$work/tty" "$ROOT" >"$work/tty.out" 2>&1 <<'PYTTY'
import os, pty, select, sys, time
wiz, root, lib = sys.argv[1:4]
env = dict(os.environ, VAULTOS_TEST_ROOT=root, VAULTOS_LIB=lib)
env.pop("VAULTOS_FIRSTBOOT_CONF", None)
pid, fd = pty.fork()
if pid == 0:
    os.execve(wiz, [wiz], env)
buf = b""
log = open(os.path.join(root, "pty-transcript.txt"), "wb")
def expect(pat, timeout=20):
    global buf
    end = time.time() + timeout
    while pat.encode() not in buf:
        r, _, _ = select.select([fd], [], [], max(0, end - time.time()))
        if not r:
            sys.exit(f"timeout waiting for {pat!r}; tail {buf[-200:]!r}")
        try:
            d = os.read(fd, 4096)
        except OSError:
            sys.exit(f"EOF waiting for {pat!r}; tail {buf[-200:]!r}")
        log.write(d); buf += d
    buf = buf[buf.index(pat.encode()) + len(pat):]
def send(s):
    os.write(fd, s.encode())
expect("Hostname [vaultos]: "); send("vaultos\n")
expect("[UTC]: "); send("UTC\n")
# Accept the locale, then type ahead a keymap and a password-like line.
expect("Locale [en_US.UTF-8]: "); send("\nde\nTypedAheadPw\n")
expect("Applying locale")
# Keymap typed normally, then a half-typed line with no Enter.
expect("Keyboard layout [us]: "); send("us\nPartialJunk")
expect("Applying keyboard layout")
expect("Username []: "); send("carl\n")
# Password plus a stray extra line before the confirmation prompt.
expect("Password: "); send("Carl-pw-1\nEXTRA\n")
expect("Password (again): "); send("Carl-pw-1\n")
expect("is ready")
_, st = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(st))
PYTTY
  then
    pass "tty typeahead: wizard finished"
  else
    fail "tty typeahead: wizard did not finish ($(tail -1 "$work/tty.out"))"
  fi
  grep -q '^carl:' "$work/tty/etc/passwd" && pass "tty typeahead: username is carl" || fail "tty typeahead: carl missing"
  grep -qiE '^(typedaheadpw|partialjunk|partialjunkcarl|de|extra|carl-pw-1):' "$work/tty/etc/passwd" \
    && fail "tty typeahead: typed-ahead text became a user" || pass "tty typeahead: no typed-ahead user"
  grep -qx 'KEYMAP=us' "$work/tty/etc/vconsole.conf" \
    && pass "tty typeahead: keymap us (typed-ahead 'de' discarded)" || fail "tty typeahead: keymap $(cat "$work/tty/etc/vconsole.conf")"
  grep -q 'Applying locale' "$work/tty/pty-transcript.txt" && grep -q 'Applying keyboard layout' "$work/tty/pty-transcript.txt" \
    && pass "tty: Applying… messages shown" || fail "tty: no Applying… message"
else
  echo "SKIP  tty typeahead (no python3)"
fi

# Answers file with loose mode: tightened with a warning, used, then deleted.
prep_root "$work/loose"
cat >"$work/loose.conf" <<'EOF'
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=lou
password=pw-loose
skip_wifi=1
online=1
EOF
chmod 0644 "$work/loose.conf"
run_wiz "$work/loose" "$work/loose.conf" >/dev/null 2>&1 && pass "loose answers: run ok" || fail "loose answers: run failed"
grep -q 'was mode 644' "$work/loose/var/log/vaultos-firstboot.log" \
  && pass "loose answers: warned" || fail "loose answers: no warning"
grep -q '^lou:' "$work/loose/etc/passwd" && pass "loose answers: still used" || fail "loose answers: not used"
[[ -e "$work/loose.conf" ]] && fail "loose answers: file left" || pass "loose answers: file deleted"

# Symlinked answers file: refused (not read, not deleted, target untouched).
prep_root "$work/symlink"
cat >"$work/symlink-target.conf" <<'EOF'
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=sym
password=pw-sym
skip_wifi=1
online=1
EOF
chmod 0600 "$work/symlink-target.conf"
ln -s "$work/symlink-target.conf" "$work/symlink.conf"
run_wiz "$work/symlink" "$work/symlink.conf" >/dev/null 2>&1 || true
grep -q '^sym:' "$work/symlink/etc/passwd" && fail "symlink answers: used" || pass "symlink answers: refused"
grep -q '^password=pw-sym$' "$work/symlink-target.conf" \
  && pass "symlink answers: target untouched" || fail "symlink answers: target changed"

# skip=1 path also removes the answers file.
prep_root "$work/skipconf"
printf 'skip=1\npassword=pw-skip\n' >"$work/skipconf.conf"
chmod 0600 "$work/skipconf.conf"
run_wiz "$work/skipconf" "$work/skipconf.conf" >/dev/null 2>&1 || fail "skip answers: run failed"
grep -q 'reason=skip' "$work/skipconf/var/lib/vaultos/firstboot-done" 2>/dev/null \
  && pass "skip answers: stamped skip" || fail "skip answers: no skip stamp"
[[ -e "$work/skipconf.conf" ]] && fail "skip answers: file left" || pass "skip answers: file deleted"

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

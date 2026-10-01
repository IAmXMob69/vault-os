#!/usr/bin/env bash
# First-boot wizard tests. Does not touch the host /etc, /boot, or LightDM.
# Fake rootfs + VAULTOS_TEST_ROOT (no QEMU, no useradd, no root needed).
#
# Every fake-root scenario runs twice: against the shell wizard
# (overlay/libexec/vaultos-firstuser.sh) and against the C++ port
# (src/vaultos-firstuser, built here into a temp dir). A parity check then
# runs both on the same answers and diffs the resulting trees.
#   VAULTOS_TEST_WIZARDS="sh"      shell only   ("cxx" for C++ only)
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SH_WIZ="$ROOT/overlay/libexec/vaultos-firstuser.sh"
IDEN="$ROOT/overlay/libexec/vaultos-firstboot.sh"
UNIT="$ROOT/overlay/systemd/vaultos-firstuser.service"
WIZARDS="${VAULTOS_TEST_WIZARDS:-sh cxx}"
FAIL=0
TAG=""
pass() { echo "PASS  ${TAG:+[$TAG] }$*"; }
fail() { echo "FAIL  ${TAG:+[$TAG] }$*"; FAIL=$((FAIL + 1)); }
# systemd runs the wizard with umask 0022; file modes are compared below.
umask 022

bash -n "$SH_WIZ" && pass "bash -n firstuser" || fail "bash -n firstuser"
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

work=$(mktemp -d /tmp/vaultos-firstboot-test.XXXXXX)
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# --- build the C++ wizard + CLI (warnings are errors) ---
CXX_WIZ=""
CXX_CLI=""
if [[ " $WIZARDS " == *" cxx "* ]]; then
  if command -v "${CXX:-g++}" >/dev/null 2>&1; then
    cxx_out="$work/build"
    mkdir -p "$cxx_out"
    crypt_libs="$(pkg-config --libs libxcrypt 2>/dev/null || echo -lcrypt)"
    # shellcheck disable=SC2086
    if "${CXX:-g++}" -O2 -std=c++17 -Wall -Wextra -Werror -I"$ROOT/src/libvaultos" \
         "$ROOT/src/vaultos-firstuser/main.cpp" -o "$cxx_out/vaultos-firstuser" $crypt_libs 2>"$cxx_out/build.log" \
       && "${CXX:-g++}" -O2 -std=c++17 -Wall -Wextra -Werror -DVAULTOS_SRC_ROOT="\"$ROOT\"" \
         "$ROOT/src/vaultos/main.cpp" -o "$cxx_out/vaultos" 2>>"$cxx_out/build.log"; then
      pass "C++ firstuser/vaultos build without warnings"
      CXX_WIZ="$cxx_out/vaultos-firstuser"
      CXX_CLI="$cxx_out/vaultos"
    else
      fail "C++ firstuser/vaultos build (see build log below)"
      cat "$cxx_out/build.log" >&2
    fi
  else
    echo "SKIP  C++ wizard tests (no g++)"
  fi
fi

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

# write_conf FILE [key=value ...]  (0600, like the docs say)
write_conf() {
  local f="$1"; shift
  printf '%s\n' "$@" >"$f"
  chmod 0600 "$f"
}
BASE=(hostname=vaultos timezone=UTC locale=en_US.UTF-8 keymap=us skip_wifi=1 online=1)

run_wiz() {
  local r="$1" conf="$2"
  # Never inherit the caller's terminal: a rejected answer falls back to an
  # interactive prompt, which would hang the harness waiting on the keyboard.
  # The timeout catches a wizard that loops on a bad answer.
  VAULTOS_TEST_ROOT="$r" VAULTOS_LIB="$ROOT" VAULTOS_FIRSTBOOT_CONF="$conf" VAULTOS_TEST_CMDLINE="" \
    timeout 60 "$WIZ" </dev/null
}

# run_stdin ROOT INPUT  (keyboard answers on stdin, no answers file)
run_stdin() {
  local r="$1" input="$2"
  printf "$input" | env -u VAULTOS_FIRSTBOOT_CONF VAULTOS_TEST_ROOT="$r" VAULTOS_LIB="$ROOT" \
    VAULTOS_TEST_CMDLINE="" timeout 60 "$WIZ"
}

suite() {
  TAG="$1"
  WIZ="$2"
  local w="$work/$TAG"
  mkdir -p "$w"

  # Happy path
  prep_root "$w/ok"
  echo '127.0.0.1	localhost' >"$w/ok/etc/hosts"
  write_conf "$w/ok.conf" hostname=testhost timezone=UTC locale=en_US.UTF-8 keymap=us \
    username=alice password=s3cret-ok skip_wifi=1 online=1
  if run_wiz "$w/ok" "$w/ok.conf"; then pass "happy path exit 0"; else fail "happy path exit $?"; fi
  grep -q '^alice:' "$w/ok/etc/passwd" && pass "user alice exists" || fail "no alice"
  grep -q '^wheel:.*alice' "$w/ok/etc/group" && pass "alice in wheel" || fail "alice not in wheel"
  grep -q '^video:.*alice' "$w/ok/etc/group" && pass "alice in video" || fail "alice not in video"
  [[ "$(cat "$w/ok/etc/hostname")" == testhost ]] && pass "hostname testhost" || fail "hostname $(cat "$w/ok/etc/hostname")"
  grep -qP '^127\.0\.1\.1\ttesthost$' "$w/ok/etc/hosts" && grep -q '^127.0.0.1' "$w/ok/etc/hosts" \
    && pass "hosts has 127.0.1.1 testhost" || fail "hosts: $(tr '\n' '|' <"$w/ok/etc/hosts")"
  grep -q UTC "$w/ok/etc/timezone" && pass "timezone UTC" || fail "timezone missing"
  [[ "$(readlink "$w/ok/etc/localtime")" == */zoneinfo/UTC ]] && pass "localtime -> UTC" || fail "localtime $(readlink "$w/ok/etc/localtime")"
  grep -qx 'LANG=en_US.UTF-8' "$w/ok/etc/locale.conf" && pass "locale.conf LANG" || fail "locale.conf"
  grep -qx 'KEYMAP=us' "$w/ok/etc/vconsole.conf" && pass "vconsole KEYMAP=us" || fail "vconsole.conf"
  grep -q 'Option "XkbLayout" "us"' "$w/ok/etc/X11/xorg.conf.d/00-keyboard.conf" \
    && pass "xorg XkbLayout us" || fail "xorg keyboard conf"
  [[ "$(stat -c %a "$w/ok/etc/sudoers.d/wheel" 2>/dev/null)" == 440 ]] && grep -qx '%wheel ALL=(ALL:ALL) ALL' "$w/ok/etc/sudoers.d/wheel" \
    && pass "sudoers wheel 0440" || fail "sudoers wheel"
  [[ -f "$w/ok/var/lib/vaultos/firstboot-done" ]] && pass "firstboot-done exists" || fail "no firstboot-done"
  [[ -f "$w/ok/var/lib/vaultos/firstuser-done" ]] && pass "firstuser-done exists" || fail "no firstuser-done"
  grep -qx 'reason=created' "$w/ok/var/lib/vaultos/firstboot-done" && grep -qx 'user=alice' "$w/ok/var/lib/vaultos/firstboot-done" \
    && grep -qx 'hostname=testhost' "$w/ok/var/lib/vaultos/firstboot-done" \
    && pass "stamp reason/user/hostname" || fail "stamp content"
  grep -q 'user-session=vaultos' "$w/ok/etc/lightdm/lightdm.conf.d/50-vaultos.conf" \
    && pass "lightdm session vaultos" || fail "lightdm session"
  [[ -f "$w/ok/usr/share/xsessions/vaultos.desktop" ]] && pass "xsession installed" || fail "no xsession"
  awk -F: '$1=="alice"{print $2}' "$w/ok/etc/shadow" | grep -q '^\$' \
    && pass "alice has password hash" || fail "alice shadow hash"
  [[ -f "$w/ok/home/alice/.config/fallout-nv/vault-os.conf" ]] && pass "skel theme seed" || fail "no skel seed"
  [[ -e "$w/ok.conf" ]] && fail "answers file left after success" || pass "answers file deleted after success"
  grep -qE 'answers file .*(shredded|removed)' "$w/ok/var/log/vaultos-firstboot.log" \
    && pass "answers deletion logged" || fail "answers deletion not logged"
  if run_wiz "$w/ok" "" >/dev/null 2>&1 && ! grep -q '^alice:.*\n.*^alice:' "$w/ok/etc/passwd" \
     && grep -q 'already stamped' "$w/ok/var/log/vaultos-firstboot.log"; then
    pass "second run: already stamped, no change"
  else
    fail "second run did not stop at the stamp"
  fi

  # Locale: a commented locale.gen line is enabled, not duplicated.
  prep_root "$w/loc"
  printf '#en_US.UTF-8 UTF-8\n#  de_DE.UTF-8 UTF-8\n' >"$w/loc/etc/locale.gen"
  write_conf "$w/loc.conf" hostname=vaultos timezone=Europe/Berlin locale=de_DE.UTF-8 keymap=DE \
    username=lena password=pw-loc skip_wifi=1 online=1
  run_wiz "$w/loc" "$w/loc.conf" >/dev/null 2>&1 || fail "locale run failed"
  [[ "$(grep -c 'de_DE.UTF-8' "$w/loc/etc/locale.gen")" == 1 ]] && grep -qx 'de_DE.UTF-8 UTF-8' "$w/loc/etc/locale.gen" \
    && grep -qx '#en_US.UTF-8 UTF-8' "$w/loc/etc/locale.gen" \
    && pass "locale.gen: de_DE uncommented once, en_US left" || fail "locale.gen: $(tr '\n' '|' <"$w/loc/etc/locale.gen")"
  grep -qx 'KEYMAP=de' "$w/loc/etc/vconsole.conf" && pass "keymap lowercased (DE -> de)" || fail "keymap DE"
  [[ "$(readlink "$w/loc/etc/localtime")" == */zoneinfo/Europe/Berlin ]] && pass "timezone Europe/Berlin" || fail "tz Berlin"
  prep_root "$w/loc2"
  write_conf "$w/loc2.conf" hostname=vaultos timezone=UTC locale=fr_FR.UTF-8 keymap=fr \
    username=lena password=pw-loc skip_wifi=1 online=1
  run_wiz "$w/loc2" "$w/loc2.conf" >/dev/null 2>&1 || fail "locale2 run failed"
  grep -qx 'fr_FR.UTF-8 UTF-8' "$w/loc2/etc/locale.gen" && grep -qx 'en_US.UTF-8 UTF-8' "$w/loc2/etc/locale.gen" \
    && pass "locale.gen: missing locale appended" || fail "locale.gen append"

  # Negative: invalid username
  prep_root "$w/badname"
  write_conf "$w/badname.conf" "${BASE[@]}" username=root password=x
  if run_wiz "$w/badname" "$w/badname.conf" >/dev/null 2>&1; then fail "root username was accepted"; else pass "root username rejected"; fi
  [[ -f "$w/badname/var/lib/vaultos/firstboot-done" ]] && fail "stamp after bad username" || pass "no stamp after bad username"

  # Negative: invalid hostname in the answers file fails (it used to loop forever).
  prep_root "$w/badhost"
  write_conf "$w/badhost.conf" hostname=bad_host! timezone=UTC locale=en_US.UTF-8 keymap=us \
    username=hal password=x skip_wifi=1 online=1
  run_wiz "$w/badhost" "$w/badhost.conf" >/dev/null 2>&1 && rc=0 || rc=$?
  [[ "$rc" -ne 0 && "$rc" -ne 124 ]] && pass "bad hostname answer fails (rc=$rc), no loop" \
    || fail "bad hostname answer: rc=$rc (124 = looped until timeout)"
  grep -q '^hal:' "$w/badhost/etc/passwd" && fail "user after bad hostname" || pass "no user after bad hostname"

  # Negative: empty password
  prep_root "$w/emptypw"
  write_conf "$w/emptypw.conf" "${BASE[@]}" username=bob password=
  if run_wiz "$w/emptypw" "$w/emptypw.conf" >/dev/null 2>&1; then fail "empty password accepted"; else pass "empty password rejected"; fi
  grep -q '^bob:' "$w/emptypw/etc/passwd" && fail "bob left after empty password" || pass "no half-created bob"

  # Negative: interrupted (EOF after hostname)
  prep_root "$w/eof"
  if run_stdin "$w/eof" 'vaultos\n' >/dev/null 2>&1; then fail "EOF run succeeded"; else pass "EOF run failed"; fi
  [[ -f "$w/eof/var/lib/vaultos/firstboot-done" ]] && fail "stamp after EOF" || pass "no stamp after EOF"
  grep -qE '^alice:|^bob:|^vaultos:' "$w/eof/etc/passwd" && fail "user created after EOF" || pass "no user after EOF"

  # Keyboard path, no answers file: every prompt, defaults on Enter.
  prep_root "$w/kbd"
  out=$(run_stdin "$w/kbd" '\n\n\n\nkim\npw-kbd\npw-kbd\n' 2>&1) && rc=0 || rc=$?
  [[ "$rc" -eq 0 && "$(cat "$w/kbd/etc/hostname")" == vaultos ]] && grep -q '^kim:' "$w/kbd/etc/passwd" \
    && grep -qx 'KEYMAP=us' "$w/kbd/etc/vconsole.conf" \
    && pass "keyboard run: defaults accepted, kim created" || fail "keyboard run (rc=$rc)"

  # Skip: existing user with usable hash
  prep_root "$w/exists"
  echo 'carol:x:1000:1000::/home/carol:/bin/bash' >>"$w/exists/etc/passwd"
  echo 'carol:$6$abc$def:1:0:99999:7:::' >>"$w/exists/etc/shadow"
  write_conf "$w/exists.conf" hostname=nope username=eve password=x online=1
  run_wiz "$w/exists" "$w/exists.conf" >/dev/null 2>&1 || true
  grep -q '^eve:' "$w/exists/etc/passwd" && fail "created eve despite existing hash" || pass "skip when usable hash exists"
  grep -q 'existing-user' "$w/exists/var/lib/vaultos/firstboot-done" \
    && pass "stamp reason existing-user" || fail "missing existing-user stamp"

  # Reset-only: user without hash
  prep_root "$w/reset"
  echo 'dave:x:1000:1000::/home/dave:/bin/bash' >>"$w/reset/etc/passwd"
  echo 'dave:!:1:0:99999:7:::' >>"$w/reset/etc/shadow"
  write_conf "$w/reset.conf" "${BASE[@]}" password=newpass
  run_wiz "$w/reset" "$w/reset.conf" >/dev/null 2>&1 || fail "reset-only failed"
  awk -F: '$1=="dave"{print $2}' "$w/reset/etc/shadow" | grep -q '^\$' \
    && pass "reset-only set dave password" || fail "dave still locked"
  grep -q '^eve:\|^alice:' "$w/reset/etc/passwd" && fail "extra user on reset-only" || pass "reset-only did not add a user"

  # Rollback: a failure AFTER useradd (sudoers drop-in rejected) must remove
  # the half-created user, or the next boot sees an "existing user" and skips.
  prep_root "$w/rollback"
  mkdir -p "$w/fakebin"
  printf '#!/bin/sh\nexit 1\n' >"$w/fakebin/visudo"
  chmod +x "$w/fakebin/visudo"
  write_conf "$w/rollback.conf" "${BASE[@]}" username=zed password=pw-rollback
  chmod 0644 "$w/rollback.conf"
  if PATH="$w/fakebin:$PATH" run_wiz "$w/rollback" "$w/rollback.conf" >/dev/null 2>&1; then
    fail "rollback: run succeeded despite visudo failure"
  else
    pass "rollback: visudo failure exits non-zero"
  fi
  grep -q '^zed:' "$w/rollback/etc/passwd" && fail "rollback: zed left in passwd" || pass "rollback: zed removed from passwd"
  grep -q '^zed:' "$w/rollback/etc/shadow" && fail "rollback: zed left in shadow" || pass "rollback: zed removed from shadow"
  grep -qE '(^zed:|[:,]zed(,|$))' "$w/rollback/etc/group" && fail "rollback: zed left in group" || pass "rollback: zed removed from group"
  [[ -e "$w/rollback/home/zed" ]] && fail "rollback: /home/zed left" || pass "rollback: /home/zed removed"
  [[ -f "$w/rollback/var/lib/vaultos/firstboot-done" ]] && fail "rollback: stamp written" || pass "rollback: no stamp"
  grep -q 'rollback zed' "$w/rollback/var/log/vaultos-firstboot.log" && pass "rollback: logged" || fail "rollback: not logged"
  [[ -f "$w/rollback.conf" ]] && pass "rollback: answers file kept for retry" || fail "rollback: answers file gone"
  [[ "$(stat -c %a "$w/rollback.conf" 2>/dev/null)" == 600 ]] \
    && pass "rollback: answers file is 0600" || fail "rollback: answers mode $(stat -c %a "$w/rollback.conf" 2>/dev/null)"
  grep -q '^password=pw-rollback$' "$w/rollback.conf" \
    && pass "rollback: answers still usable for retry" || fail "rollback: answers lost the password"
  grep -q 'was mode 644' "$w/rollback/var/log/vaultos-firstboot.log" \
    && pass "rollback: loose answers mode warned" || fail "rollback: no warning for mode 644"

  # Rollback on a signal after useradd (SIGTERM while visudo runs).
  prep_root "$w/sigterm"
  mkdir -p "$w/slowbin"
  printf '#!/bin/sh\nsleep 1\nexit 0\n' >"$w/slowbin/visudo"
  chmod +x "$w/slowbin/visudo"
  write_conf "$w/sigterm.conf" "${BASE[@]}" username=sig password=pw-sig
  # env execs the wizard, so $! is the wizard itself (no timeout wrapper here).
  env PATH="$w/slowbin:$PATH" VAULTOS_TEST_ROOT="$w/sigterm" VAULTOS_LIB="$ROOT" \
    VAULTOS_FIRSTBOOT_CONF="$w/sigterm.conf" VAULTOS_TEST_CMDLINE="" "$WIZ" </dev/null >/dev/null 2>&1 &
  local bg=$! n=0
  until grep -q '^sig:' "$w/sigterm/etc/passwd" 2>/dev/null || (( n++ > 200 )); do sleep 0.05; done
  kill -TERM "$bg" 2>/dev/null || true
  wait "$bg" && rc=0 || rc=$?
  [[ "$rc" -eq 143 ]] && pass "SIGTERM after useradd: exit 143" || fail "SIGTERM after useradd: rc=$rc"
  grep -q '^sig:' "$w/sigterm/etc/passwd" && fail "SIGTERM: sig left in passwd" || pass "SIGTERM: sig rolled back"
  [[ -f "$w/sigterm/var/lib/vaultos/firstboot-done" ]] && fail "SIGTERM: stamp written" || pass "SIGTERM: no stamp"
  [[ -f "$w/sigterm.conf" ]] && pass "SIGTERM: answers kept for retry" || fail "SIGTERM: answers file gone"

  # Timezone must be a zone file, not a directory or a path escape.
  prep_root "$w/tz"
  out=$(run_stdin "$w/tz" 'vaultos\nAmerica\n../../../etc/passwd\nNew_York\nUTC\n' 2>&1) || true
  [[ "$(readlink "$w/tz/etc/localtime")" == */zoneinfo/UTC ]] \
    && pass "timezone rejects directory and .. path" \
    || fail "timezone accepted $(readlink "$w/tz/etc/localtime")"
  [[ "$out" == *"America/New_York"* ]] && pass "timezone search lists America/New_York" || fail "timezone search: no match list"

  # skip_wifi=yes means skip (it used to be read as "yes, connect").
  local sw
  for sw in yes 0; do
    prep_root "$w/wifi$sw"
    write_conf "$w/wifi$sw.conf" hostname=vaultos timezone=UTC locale=en_US.UTF-8 keymap=us \
      username=wendy password=pw-wifi online=0 wifi_dev=wlan0 skip_wifi=$sw wifi_ssid=testnet wifi_psk=testpsk
    run_wiz "$w/wifi$sw" "$w/wifi$sw.conf" >/dev/null 2>&1 || fail "wifi skip_wifi=$sw run failed"
  done
  grep -q 'wifi ssid=' "$w/wifiyes/var/log/vaultos-firstboot.log" \
    && fail "skip_wifi=yes still connected" || pass "skip_wifi=yes skips Wi-Fi"
  grep -q 'wifi ssid=testnet' "$w/wifi0/var/log/vaultos-firstboot.log" \
    && pass "skip_wifi=0 connects Wi-Fi" || fail "skip_wifi=0 did not connect"
  # No skip_wifi: asked on the keyboard; the password is read silently.
  prep_root "$w/wifikbd"
  write_conf "$w/wifikbd.conf" hostname=vaultos timezone=UTC locale=en_US.UTF-8 keymap=us \
    username=wes password=pw-wifi online=0 wifi_dev=wlan0
  out=$(printf 'y\nkbdnet\nkbdpsk\n' | VAULTOS_TEST_ROOT="$w/wifikbd" VAULTOS_LIB="$ROOT" \
        VAULTOS_FIRSTBOOT_CONF="$w/wifikbd.conf" VAULTOS_TEST_CMDLINE="" timeout 60 "$WIZ" 2>&1) || true
  grep -q 'wifi ssid=kbdnet' "$w/wifikbd/var/log/vaultos-firstboot.log" && [[ "$out" != *kbdpsk* ]] \
    && pass "Wi-Fi asked: SSID used, password not echoed" || fail "Wi-Fi keyboard path"
  prep_root "$w/nowifi"
  write_conf "$w/nowifi.conf" hostname=vaultos timezone=UTC locale=en_US.UTF-8 keymap=us \
    username=nia password=pw online=0
  out=$(run_wiz "$w/nowifi" "$w/nowifi.conf" 2>&1) || true
  [[ "$out" == *"No Wi-Fi device detected"* ]] && pass "offline, no Wi-Fi device: says so" || fail "no-wifi message"

  # Typeahead on a real TTY: keys typed while locale/keymap apply must be
  # discarded, never read as the username, and never as the password
  # confirmation. Needs a pty, so drive the wizard from python3's pty module.
  if command -v python3 >/dev/null 2>&1; then
    prep_root "$w/tty"
    if python3 - "$WIZ" "$w/tty" "$ROOT" >"$w/tty.out" 2>&1 <<'PYTTY'
import os, pty, select, sys, time
wiz, root, lib = sys.argv[1:4]
env = dict(os.environ, VAULTOS_TEST_ROOT=root, VAULTOS_LIB=lib, VAULTOS_TEST_CMDLINE="")
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
      fail "tty typeahead: wizard did not finish ($(tail -1 "$w/tty.out"))"
    fi
    grep -q '^carl:' "$w/tty/etc/passwd" && pass "tty typeahead: username is carl" || fail "tty typeahead: carl missing"
    grep -qiE '^(typedaheadpw|partialjunk|partialjunkcarl|de|extra|carl-pw-1):' "$w/tty/etc/passwd" \
      && fail "tty typeahead: typed-ahead text became a user" || pass "tty typeahead: no typed-ahead user"
    grep -qx 'KEYMAP=us' "$w/tty/etc/vconsole.conf" \
      && pass "tty typeahead: keymap us (typed-ahead 'de' discarded)" || fail "tty typeahead: keymap $(cat "$w/tty/etc/vconsole.conf")"
    grep -q 'Applying locale' "$w/tty/pty-transcript.txt" && grep -q 'Applying keyboard layout' "$w/tty/pty-transcript.txt" \
      && pass "tty: Applying… messages shown" || fail "tty: no Applying… message"
    grep -q 'Carl-pw-1' "$w/tty/pty-transcript.txt" && fail "tty: password echoed" || pass "tty: password not echoed"
  else
    echo "SKIP  tty typeahead (no python3)"
  fi

  # Answers file with loose mode: tightened with a warning, used, then deleted.
  prep_root "$w/loose"
  write_conf "$w/loose.conf" "${BASE[@]}" username=lou password=pw-loose
  chmod 0644 "$w/loose.conf"
  run_wiz "$w/loose" "$w/loose.conf" >/dev/null 2>&1 && pass "loose answers: run ok" || fail "loose answers: run failed"
  grep -q 'was mode 644' "$w/loose/var/log/vaultos-firstboot.log" && pass "loose answers: warned" || fail "loose answers: no warning"
  grep -q '^lou:' "$w/loose/etc/passwd" && pass "loose answers: still used" || fail "loose answers: not used"
  [[ -e "$w/loose.conf" ]] && fail "loose answers: file left" || pass "loose answers: file deleted"

  # Symlinked answers file: refused (not read, not deleted, target untouched).
  prep_root "$w/symlink"
  write_conf "$w/symlink-target.conf" "${BASE[@]}" username=sym password=pw-sym
  ln -s "$w/symlink-target.conf" "$w/symlink.conf"
  run_wiz "$w/symlink" "$w/symlink.conf" >/dev/null 2>&1 || true
  grep -q '^sym:' "$w/symlink/etc/passwd" && fail "symlink answers: used" || pass "symlink answers: refused"
  grep -q '^password=pw-sym$' "$w/symlink-target.conf" \
    && pass "symlink answers: target untouched" || fail "symlink answers: target changed"

  # skip=1 path also removes the answers file.
  prep_root "$w/skipconf"
  write_conf "$w/skipconf.conf" skip=1 password=pw-skip
  run_wiz "$w/skipconf" "$w/skipconf.conf" >/dev/null 2>&1 || fail "skip answers: run failed"
  grep -q 'reason=skip' "$w/skipconf/var/lib/vaultos/firstboot-done" 2>/dev/null \
    && pass "skip answers: stamped skip" || fail "skip answers: no skip stamp"
  [[ -e "$w/skipconf.conf" ]] && fail "skip answers: file left" || pass "skip answers: file deleted"

  # Boot options: vaultos.firstboot=skip and vaultos.firstboot=PATH on the
  # kernel command line, and the default /etc/vaultos/firstboot.conf.
  prep_root "$w/bootskip"
  VAULTOS_TEST_ROOT="$w/bootskip" VAULTOS_LIB="$ROOT" VAULTOS_TEST_CMDLINE="quiet vaultos.firstboot=skip splash" \
    timeout 60 "$WIZ" </dev/null >/dev/null 2>&1 || fail "boot skip: run failed"
  grep -q 'reason=skip' "$w/bootskip/var/lib/vaultos/firstboot-done" 2>/dev/null \
    && pass "boot option vaultos.firstboot=skip stamps skip" || fail "boot option skip"
  prep_root "$w/bootconf"
  write_conf "$w/bootconf.conf" "${BASE[@]}" username=bea password=pw-boot
  VAULTOS_TEST_ROOT="$w/bootconf" VAULTOS_LIB="$ROOT" VAULTOS_TEST_CMDLINE="rw vaultos.firstboot=$w/bootconf.conf" \
    timeout 60 "$WIZ" </dev/null >/dev/null 2>&1 || fail "boot conf: run failed"
  grep -q '^bea:' "$w/bootconf/etc/passwd" && [[ ! -e "$w/bootconf.conf" ]] \
    && pass "boot option vaultos.firstboot=PATH used and shredded" || fail "boot option PATH"
  prep_root "$w/defconf"
  mkdir -p "$w/defconf/etc/vaultos"
  write_conf "$w/defconf/etc/vaultos/firstboot.conf" "${BASE[@]}" username=dee password=pw-def
  VAULTOS_TEST_ROOT="$w/defconf" VAULTOS_LIB="$ROOT" VAULTOS_TEST_CMDLINE="" \
    timeout 60 "$WIZ" </dev/null >/dev/null 2>&1 || fail "default conf: run failed"
  grep -q '^dee:' "$w/defconf/etc/passwd" && [[ ! -e "$w/defconf/etc/vaultos/firstboot.conf" ]] \
    && pass "/etc/vaultos/firstboot.conf used and shredded" || fail "default answers file"

  # Password mismatch via stdin (no answers password)
  prep_root "$w/mismatch"
  if run_stdin "$w/mismatch" 'vaultos\nUTC\nen_US.UTF-8\nus\nn\nalice\none\ntwo\none\ntwo\n' >/dev/null 2>&1; then
    fail "mismatch eventually succeeded unexpectedly"
  else
    pass "mismatch/EOF did not finish"
  fi
  grep -q '^alice:' "$w/mismatch/etc/passwd" && fail "alice left after mismatch abort" || pass "mismatch rolled back / no user"

  # A real run (no fake root) must refuse to start as non-root.
  if [[ "$(id -u)" -ne 0 ]]; then
    out=$(env -u VAULTOS_TEST_ROOT -u VAULTOS_FIRSTBOOT_CONF "$WIZ" </dev/null 2>&1) && rc=0 || rc=$?
    [[ "$rc" -ne 0 && "$out" == *"needs root"* ]] && pass "real run refuses non-root" || fail "real run as non-root: rc=$rc"
  fi
  TAG=""
}

for wz in $WIZARDS; do
  case "$wz" in
    sh) suite sh "$SH_WIZ" ;;
    cxx) [[ -n "$CXX_WIZ" ]] && suite cxx "$CXX_WIZ" ;;
  esac
done

# --- parity: same answers, same fake root path, diff the trees ---
snapshot() {
  # Tree listing with modes, then contents with crypt hashes and times masked.
  local r="$1"
  (cd "$r" && find . -printf '%p %y %m %l\n' | LC_ALL=C sort)
  (cd "$r" && find . -type f ! -name 'vaultos-firstboot.log' -print0 | LC_ALL=C sort -z \
     | while IFS= read -r -d '' f; do echo "== $f"; sed -E 's/\$6\$[^:]*/HASH/; s/^done=.*/done=T/' "$f"; done)
  echo "== log"
  sed -E 's/^vaultos-firstboot [^ ]+ //' "$r/var/log/vaultos-firstboot.log"
}
if [[ -n "$CXX_WIZ" && " $WIZARDS " == *" sh "* ]]; then
  TAG=parity
  for scen in happy reset rollback; do
    for wz in sh cxx; do
      prep_root "$work/par"
      args=(hostname=parhost timezone=Europe/Berlin locale=de_DE.UTF-8 keymap=de skip_wifi=0
            online=0 wifi_dev=wlan0 wifi_ssid=parnet wifi_psk=parpsk username=pat password=pw-par)
      [[ "$scen" == reset ]] && { echo 'dora:x:1000:1000::/home/dora:/bin/bash' >>"$work/par/etc/passwd"
                                  echo 'dora:!:1:0:99999:7:::' >>"$work/par/etc/shadow"; }
      write_conf "$work/par.conf" "${args[@]}"
      [[ "$wz" == sh ]] && WIZ="$SH_WIZ" || WIZ="$CXX_WIZ"
      if [[ "$scen" == rollback ]]; then
        PATH="$work/sh/fakebin:$PATH" run_wiz "$work/par" "$work/par.conf" >"$work/par-$scen-$wz.out" 2>&1 || true
      else
        run_wiz "$work/par" "$work/par.conf" >"$work/par-$scen-$wz.out" 2>&1 || true
      fi
      snapshot "$work/par" >"$work/par-$scen-$wz.snap"
      [[ -e "$work/par.conf" ]] && echo "answers kept $(stat -c %a "$work/par.conf")" >>"$work/par-$scen-$wz.snap"
    done
    if diff -u "$work/par-$scen-sh.snap" "$work/par-$scen-cxx.snap" >"$work/par-$scen.diff"; then
      pass "$scen: shell and C++ leave identical trees, modes and log"
    else
      fail "$scen: trees differ"
      cat "$work/par-$scen.diff"
    fi
  done
  TAG=""
fi

# --- Wi-Fi PSK never on a command line, never logged (both wizards) ---
# Stub nmcli/iwctl record their argv, every process's /proc/*/cmdline while
# they run, and what they were handed as the secret (passwd-file or iwd
# profile). VAULTOS_TEST_WIFI makes the wizards run the real Wi-Fi code
# against them. Then the two wizards' results are diffed.
stub="$work/wifistub"
mkdir -p "$stub"
cat >"$stub/nmcli" <<'STUB'
#!/bin/bash
d="$STUB_DIR"
{ printf 'nmcli'; printf ' [%s]' "$@"; echo; } >>"$d/argv"
for f in /proc/[0-9]*/cmdline; do tr '\0' ' ' <"$f" 2>/dev/null; echo; done >>"$d/procs"
if [[ "$1 $2" == "connection up" ]]; then
  while [[ $# -gt 0 && "$1" != passwd-file ]]; do shift; done
  [[ -n "${2:-}" ]] && { cat "$2"; echo "<eof>"; } >>"$d/secret"
  exit "${STUB_UP_RC:-0}"
fi
exit 0
STUB
cat >"$stub/iwctl" <<'STUB'
#!/bin/bash
d="$STUB_DIR"
{ printf 'iwctl'; printf ' [%s]' "$@"; echo; } >>"$d/argv"
for f in /proc/[0-9]*/cmdline; do tr '\0' ' ' <"$f" 2>/dev/null; echo; done >>"$d/procs"
for f in "$VAULTOS_TEST_ROOT"/var/lib/iwd/*.psk; do
  [[ -f "$f" ]] && { echo "== ${f##*/} $(stat -c %a "$f")"; cat "$f"; } >>"$d/secret"
done
exit "${STUB_UP_RC:-0}"
STUB
chmod +x "$stub/nmcli" "$stub/iwctl"
# Random marker: the command line that started this harness may contain a
# fixed one, and /proc/*/cmdline would then "leak" it.
MARK="m$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
PSK=" ${MARK}\\x y\$z'q"$'\t'"end"     # leading space, backslash, $, quote, tab
NM_LINE="802-11-wireless-security.psk:\\ ${MARK}\\\\x\\ y\$z'q\\tend"
IWD_LINE="Passphrase=\\s${MARK}\\\\x y\$z'q\\tend"
wifi_run() {  # wiz backend scen -> $work/wf-<scen>-<backend>-<wz>/
  local wz=$1 be=$2 scen=$3 d="$work/wf-$3-$2-$1" ssid=café-net psk_args=()
  rm -rf "$d"; mkdir -p "$d"
  prep_root "$d/root"
  case "$scen" in
    ok|fail) psk_args=("wifi_psk=$PSK") ;;
    restore) psk_args=("wifi_psk=$PSK"); ssid=home_net
             mkdir -p "$d/root/var/lib/iwd"; printf '[Security]\nPassphrase=oldpass1\n' >"$d/root/var/lib/iwd/home_net.psk"
             chmod 600 "$d/root/var/lib/iwd/home_net.psk" ;;
    open) ;;   # no wifi_psk: read (empty) from the keyboard
  esac
  write_conf "$d/conf" hostname=wfhost timezone=UTC locale=en_US.UTF-8 keymap=us username=wally password=pw-wifi \
    online=0 wifi_dev=wlan0 skip_wifi=0 "wifi_ssid=$ssid" "${psk_args[@]}"
  [[ "$wz" == sh ]] && WIZ="$SH_WIZ" || WIZ="$CXX_WIZ"
  local rc=0
  [[ "$scen" == fail || "$scen" == restore ]] && rc=1
  : >"$d/argv"; : >"$d/procs"; : >"$d/secret"
  STUB_DIR="$d" STUB_UP_RC=$rc VAULTOS_TEST_WIFI=$be PATH="$stub:$PATH" \
    run_wiz "$d/root" "$d/conf" >"$d/out" 2>&1 || true
}
if [[ -n "$CXX_WIZ" && " $WIZARDS " == *" sh "* ]]; then
  TAG=wifi
  for be in nmcli iwctl; do
    for scen in ok fail open restore; do
      [[ "$be" == nmcli && "$scen" == restore ]] && continue
      for wz in sh cxx; do wifi_run "$wz" "$be" "$scen"; done
      a="$work/wf-$scen-$be-sh"; b="$work/wf-$scen-$be-cxx"
      for wz in sh cxx; do
        d="$work/wf-$scen-$be-$wz"
        if grep -qF -- "$MARK" "$d/argv" "$d/procs" "$d/out" "$d/root/var/log/vaultos-firstboot.log"; then
          fail "$be/$scen [$wz]: PSK seen in argv, /proc/*/cmdline, output or log"
        else
          pass "$be/$scen [$wz]: PSK not in argv, /proc/*/cmdline, output or log"
        fi
        [[ -s "$d/argv" ]] || fail "$be/$scen [$wz]: stub never ran"
      done
      d="$a"
      case "$be/$scen" in
        nmcli/ok|nmcli/fail)
          grep -qxF -- "$NM_LINE" "$d/secret" && pass "$be/$scen: PSK reached nmcli via passwd-file, escaped" \
            || { fail "$be/$scen: passwd-file content"; cat "$d/secret"; } ;;
        nmcli/open)
          grep -qF '[device] [wifi] [connect] [café-net] [ifname] [wlan0]' "$d/argv" && [[ ! -s "$d/secret" ]] \
            && pass "$be/open: open network uses device wifi connect, no secret" || fail "$be/open argv" ;;
        iwctl/ok|iwctl/fail)
          grep -qxF -- "$IWD_LINE" "$d/secret" && grep -q '^== =636166c3a92d6e6574.psk 600$' "$d/secret" \
            && pass "$be/$scen: iwd profile =hex(SSID).psk 0600 with escaped passphrase" \
            || { fail "$be/$scen: iwd profile"; cat "$d/secret"; } ;;
        iwctl/open)
          [[ ! -s "$d/secret" ]] && pass "iwctl/open: no profile written" || fail "iwctl/open wrote a profile" ;;
        iwctl/restore) : ;;
      esac
      case "$be/$scen" in
        nmcli/fail) grep -qF '[connection] [delete] [uuid]' "$d/argv" && pass "nmcli/fail: half-made profile deleted" \
                      || fail "nmcli/fail: profile not deleted" ;;
        iwctl/ok) [[ -f "$d/root/var/lib/iwd/=636166c3a92d6e6574.psk" ]] && pass "iwctl/ok: profile kept" || fail "iwctl/ok: profile gone" ;;
        iwctl/fail) [[ -z "$(ls -A "$d/root/var/lib/iwd")" ]] && pass "iwctl/fail: new profile removed" \
                      || { fail "iwctl/fail: leftovers"; ls -la "$d/root/var/lib/iwd"; } ;;
        iwctl/restore) [[ "$(cat "$d/root/var/lib/iwd/home_net.psk")" == $'[Security]\nPassphrase=oldpass1' ]] \
                         && [[ "$(ls -A "$d/root/var/lib/iwd")" == home_net.psk ]] \
                         && pass "iwctl/restore: previous profile restored on failure" || fail "iwctl/restore" ;;
      esac
      want=0; [[ "$scen" == fail || "$scen" == restore ]] && want=1
      [[ "$(grep -c 'Wi-Fi connect failed' "$a/out")" == "$want" ]] \
        && pass "$be/$scen: failure reported only when the connect fails" || fail "$be/$scen: failure message"
      for x in a b; do
        d=${!x}
        { sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/UUID/g' "$d/argv"
          echo "-- secret"; cat "$d/secret"
          # The wizards' screen styling differs (banner, indent); compare
          # only the Wi-Fi outcome line.
          echo "-- out"; grep -c 'Wi-Fi connect failed' "$d/out" || true
          echo "-- tree"; snapshot "$d/root" | sed "s|$d/|D/|g"
          [[ -e "$d/conf" ]] && echo "answers kept $(stat -c %a "$d/conf")"; } >"$d.cmp"
      done
      diff -u "$a.cmp" "$b.cmp" >"$a.diff" && pass "$be/$scen: shell and C++ identical (argv, secret, output, tree)" \
        || { fail "$be/$scen: shell and C++ differ"; cat "$a.diff"; }
    done
  done
  TAG=""
fi

# Identity script does not write firstboot-done
prep_root "$work/id"
VAULTOS_TEST_ROOT="$work/id" VAULTOS_LIB="$ROOT" "$IDEN" || true
[[ -f "$work/id/var/lib/vaultos/identity-applied" ]] && pass "identity-applied stamp" || fail "no identity stamp"
[[ -f "$work/id/var/lib/vaultos/firstboot-done" ]] && fail "identity wrote firstboot-done" || pass "identity does not stamp firstboot-done"

# --- vaultos firstboot --run needs root (shell and C++ CLI) ---
if [[ "$(id -u)" -ne 0 ]]; then
  out=$(VAULTOS_LIB="$ROOT" bash "$ROOT/bin/vaultos" firstboot --run </dev/null 2>&1) && rc=0 || rc=$?
  [[ "$rc" -ne 0 && "$out" == *"needs root"* ]] \
    && pass "shell vaultos firstboot --run refuses non-root" || fail "shell vaultos firstboot --run ran as non-root (rc=$rc)"
  if [[ -n "$CXX_CLI" ]]; then
    out=$("$CXX_CLI" firstboot --run </dev/null 2>&1) && rc=0 || rc=$?
    [[ "$rc" -ne 0 && "$out" == *"needs root"* ]] \
      && pass "C++ vaultos firstboot --run refuses non-root" || fail "C++ vaultos firstboot --run ran as non-root (rc=$rc)"
  fi
fi

# --- C++ only: --dry-run reads the (fake) root but changes nothing ---
if [[ -n "$CXX_WIZ" ]]; then
  TAG=cxx
  prep_root "$work/dry"
  write_conf "$work/dry.conf" "${BASE[@]}" username=dry password=pw-dry
  before=$(cd "$work/dry" && find . -printf '%p %m %s\n' | sort; md5sum "$work/dry.conf")
  out=$(VAULTOS_TEST_ROOT="$work/dry" VAULTOS_LIB="$ROOT" VAULTOS_FIRSTBOOT_CONF="$work/dry.conf" VAULTOS_TEST_CMDLINE="" \
        timeout 60 "$CXX_WIZ" --dry-run </dev/null 2>&1) && rc=0 || rc=$?
  after=$(cd "$work/dry" && find . -printf '%p %m %s\n' | sort; md5sum "$work/dry.conf")
  [[ "$rc" -eq 0 && "$before" == "$after" ]] && pass "--dry-run: exit 0, fake root and answers untouched" \
    || fail "--dry-run changed something (rc=$rc)"
  [[ "$out" == *"[dry-run] write $work/dry/etc/hostname"* && "$out" == *"[dry-run] stamp"* && "$out" == *"[dry-run] shred"* ]] \
    && pass "--dry-run: reports the writes, stamp and shred" || fail "--dry-run output"
  TAG=""
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "All first-boot tests passed."
  exit 0
fi
echo "$FAIL test(s) failed."
exit 1

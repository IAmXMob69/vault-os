#!/usr/bin/env bash
# Parity tests for src/vaultos-doctor against the bash checks in bin/vault-os.
# Copies the tracked tree into a temp dir, breaks it on purpose, and diffs
# `vault-os lint` / `vault-os doctor` output and exit codes between bash
# (VAULTOS_DOCTOR=) and native. The doctor runs with a fake HOME and a stub
# xfconf-query, so it never reads or writes the live session.
#   VAULTOS_DOCTOR_BIN=/path  test an already built binary
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
FAIL=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }
work=$(mktemp -d /tmp/vaultos-doctor-test.XXXXXX)
trap '[[ -n "${KEEP:-}" ]] || rm -rf "$work"' EXIT

ND="${VAULTOS_DOCTOR_BIN:-}"
if [[ -z "$ND" ]]; then
  ND="$work/vaultos-doctor"
  "${CXX:-g++}" -O2 -std=c++17 -Wall -Wextra -Werror -I"$ROOT/src/libvaultos" \
    "$ROOT/src/vaultos-doctor/main.cpp" -o "$ND" 2>"$work/build.log" \
    && pass "native build without warnings" || { fail "native build"; cat "$work/build.log"; exit 1; }
fi

# compare NAME -- command...   (runs it twice: bash checks, then native)
compare() {
  local name="$1"; shift 2
  local rs rn
  VAULTOS_DOCTOR= "$@" >"$work/$name.sh" 2>&1 && rs=0 || rs=$?
  VAULTOS_DOCTOR="$ND" "$@" >"$work/$name.cxx" 2>&1 && rn=0 || rn=$?
  if [[ "$rs" == "$rn" ]] && cmp -s "$work/$name.sh" "$work/$name.cxx"; then
    pass "$name: identical output, exit $rs ($(grep -cE '^[a-zA-Z-]+ +(OK|WARN|FAIL|SKIP) ' "$work/$name.sh") checks)"
  else
    fail "$name: bash exit $rs, native exit $rn"
    diff -u "$work/$name.sh" "$work/$name.cxx" | head -40 || true
  fi
}

copy_tree() {
  mkdir -p "$1"
  git -C "$ROOT" ls-files -z | tar -C "$ROOT" --null -T - -cf - | tar -C "$1" -xf -
  # The working copy of the checks under test, not the committed one.
  cp "$ROOT/bin/vault-os" "$1/bin/vault-os"
}

# --- lint: clean tree ---
copy_tree "$work/clean"
compare lint-clean -- "$work/clean/bin/vault-os" lint "$work/clean"
compare lint-noarg -- "$work/clean/bin/vault-os" lint

# --- lint: every check broken ---
cp -a "$work/clean" "$work/bad"
B="$work/bad"
HX="33FF""6A"; HY="44FF""3D"; IMP="!import""ant"
for i in $(seq 1 9); do echo ".x$i { color: #$HX; }" >>"$B/themes/Vault.OS/gtk-3.0/gtk.css"; done
printf '/* #%s in a comment is fine */\n.y { color: rgb(51, 255, 106); }\n.z { color: 0x%s; }\n' "$HX" "$HY" >>"$B/source/gtk-3.20/gtk.css"
printf 'COLOR=#%s\nOTHER=#%s\n' "$HY" "$HX" >"$B/bin/zz-colors.conf"
printf '\0\0binary #%s\n' "$HX" >"$B/source/zz-binary.dat"
printf '# #%s in docs is fine\n' "$HX" >"$B/source/zz-notes.md"
echo "{\"c\": \"#$HX\"}" >>"$B/config/vscode/settings-snippet.json"
echo ".q{color:#$HY}" >>"$B/config/discord/PipBoyNV.theme.css"
echo "a { color: red $IMP; }" >>"$B/source/gtk-3.0/gtk.css"
echo "label { text-trans""form: uppercase; } a:bef""ore { }" >>"$B/source/lock/lock.css"
rm -f "$B/themes/Vault.OS-Reduced/gtk-3.20/gtk.css"
x=$(ls "$B/themes/Vault.OS/xfwm4"/*.xpm | head -1)
sed -i -E 's/ c #[0-9A-Fa-f]+//' "$x"
echo extra >"$B/themes/Vault.OS/xfwm4/zz-only-in-theme.xpm"
mkdir -p "$B/source/xfwm4/subdir" && echo s >"$B/source/xfwm4/subdir/file"
echo doc >"$B/themes/Vault.OS/xfwm4/README.md"
rm -f "$B/themes/Vault.OS-Reduced/xfwm4/themerc" "$B/source/xfwm4-reduced/themerc"
sed -i 's/^ScrollingBar=.*/ScrollingBar=TERMINAL_SCROLLBAR_''NONE/' "$B/source/xfce4-terminal/terminalrc.full"
sed -i '/^ScrollingBar=/d' "$B/source/xfce4-terminal/terminalrc.clear"
echo 'Hidden=false' >>"$B/source/xfce4-screensaver/vaultos-arch-spin.desktop"
mkdir -p "$B/extras/zz" && printf '[Desktop Entry]\nExec=/usr/bin/vaultos-thing\n' >"$B/extras/zz/xfce-floaters.desktop.bak"
printf '[Desktop Entry]\nExec=vaultos-spin-arch --instance desktop --full\n' >"$B/extras/zz/spin.desktop"
echo drift >>"$B/source/ERRORS.md"
echo '/* drift */' >>"$B/source/tokens.css"
printf '#!/bin/bash\nif then fi\n' >"$B/bin/zz-broken"
printf '#!/bin/bash\nexit 0\n' >"$B/bin/vaultos-spin-arch-autostart.new"
compare lint-broken -- "$B/bin/vault-os" lint "$B"
# spin-default FAIL: autostart that always passes --full
printf '#!/bin/bash\nexec "$HOME/.local/bin/vaultos-spin-arch" --full --instance desktop\n' >"$B/bin/vaultos-spin-arch-autostart"
compare lint-spinfull -- "$B/bin/vault-os" lint "$B"

# --- lint: bare checkout (SKIP paths, missing files) ---
mkdir -p "$work/bare/themes/Vault.OS" "$work/bare/source" "$work/bare/bin"
cp "$ROOT/bin/vault-os" "$work/bare/bin/vault-os"
compare lint-bare -- "$work/bare/bin/vault-os" lint "$work/bare"
compare lint-notrepo -- "$work/clean/bin/vault-os" lint "$work/clean/source"

# --- doctor: fake HOME, stub xfconf-query ---
mkhome() {
  local H="$1"
  mkdir -p "$H/.local/bin" "$H/.config/autostart" "$H/.config/Vault.OS" "$H/.themes" "$H/.config/fallout-nv"
  cat >"$H/.local/bin/xfconf-query" <<'STUB'
#!/bin/bash
# Stub: answers from $HOME/xfconf.db ("channel|property|value", \n escapes).
ch="" prop="" list=0
while (($#)); do case "$1" in -c) ch="$2"; shift ;; -p) prop="$2"; shift ;; -l) list=1 ;; *) exit 9 ;; esac; shift; done
db="$HOME/xfconf.db"
if ((list)); then awk -F'|' -v c="$ch" '$1==c{print $2}' "$db"; exit 0; fi
v=$(awk -F'|' -v c="$ch" -v p="$prop" '$1==c && $2==p{print substr($0, length($1)+length($2)+3); f=1; exit} END{exit !f}' "$db") \
  || { echo "Property \"$prop\" does not exist on channel \"$ch\"." >&2; exit 1; }
printf '%b\n' "$v"
STUB
  chmod +x "$H/.local/bin/xfconf-query"
}
D="$work/home-ok"
mkhome "$D"
cp -a "$work/clean/themes/Vault.OS" "$work/clean/themes/Vault.OS-Reduced" "$D/.themes/"
cp "$work/clean/source/xfce4-terminal/terminal.reduced.css" "$D/.themes/Vault.OS/gtk-3.0/terminal.css"
cp "$work/clean/source/xfce4-terminal/terminal.reduced.css" "$D/.themes/Vault.OS/gtk-3.20/terminal.css"
mkdir -p "$D/.config/gtk-3.0" && echo '@import url("hud.css");' >"$D/.config/gtk-3.0/gtk.css"
ln -s "$work/clean/bin/vault-os" "$D/.local/bin/vault-os"
printf '[Desktop Entry]\nExec=%s/.local/bin/vaultos-spin-arch-autostart\n' "$D" >"$D/.config/autostart/vaultos-spin-arch.desktop"
mkdir -p "$D/.icons/Vault.OS/cursors" "$D/.themes/Vault.OS/xfce-notify-4.0"
cat >"$D/xfconf.db" <<EOF
xsettings|/Net/ThemeName|Vault.OS
xsettings|/Net/IconThemeName|Vault.OS
xsettings|/Gtk/CursorThemeName|Vault.OS
xfwm4|/general/theme|Vault.OS
xfce4-panel|/panels/panel-1/length|100.000000
xfce4-panel|/panels/panel-2/length|100.000000
xfce4-panel|/panels/panel-2/position|p=10;x=0;y=0
xfce4-desktop|/backdrop/screen0/monitor0/workspace0/last-image|$D/.themes/Vault.OS/gtk-3.0/gtk.css
xfce4-notifyd|/theme|Vault.OS
xfce4-terminal|/scrolling-bar|TERMINAL_SCROLLBAR_RIGHT
xfce4-screensaver|/saver/themes/list|Value is an array with 1 items:\n\nscreensavers-vaultos-arch-spin
xfce4-session|/general/LockCommand|$D/.local/bin/vaultos-session-lock
EOF
compare doctor-ok -- env HOME="$D" XDG_CONFIG_HOME= "$work/clean/bin/vault-os" doctor

D="$work/home-bad"
mkhome "$D"
mkdir -p "$D/.themes/Vault.OS/gtk-3.0" "$D/.config/gtk-3.0" "$D/.config/gtk-4.0" \
  "$D/.local/share/applications/screensavers" "$D/.themes/Vault.OS/xfwm4"
cp -a "$work/clean/themes/Vault.OS/xfwm4/." "$D/.themes/Vault.OS/xfwm4/"
rm -f "$(ls "$D/.themes/Vault.OS/xfwm4"/*.xpm | head -1)"
echo zz >"$D/.themes/Vault.OS/xfwm4/zz-extra"
echo ".a{color:#$HX}" >"$D/.themes/Vault.OS/gtk-3.0/gtk.css"
echo "b{x:y $IMP}" >"$D/.config/gtk-4.0/gtk.css"
printf '/* spinner ok in comment */\nspinner { opacity: 0; }\n' >"$D/.config/gtk-3.0/gtk.css"
printf '#!/bin/bash\nreadonly VERSION="0.9.0"\n' >"$D/.local/bin/vault-os"; chmod +x "$D/.local/bin/vault-os"
printf '[Desktop Entry]\nExec=vaultos-spin-arch --full --instance desktop\n' >"$D/.config/autostart/spin.desktop"
printf '[Desktop Entry]\nExec=vaultos-spin-arch\nHidden=true\n' >"$D/.config/autostart/hidden.desktop"
echo junk >"$D/.config/Vault.OS/desktop-spin"
echo clear >"$D/.config/Vault.OS/terminal-phosphor"
touch "$D/.local/share/applications/screensavers/xfce-floaters.desktop"
mkdir -p "$D/.config/xfce4/terminal" && echo 'ScrollingBar=TERMINAL_SCROLLBAR_''NONE' >"$D/.config/xfce4/terminal/terminalrc"
printf 'THEME_NAME = Vault.OS-Reduced\nICON_THEME=Other\n# CURSOR_THEME=x\nINTRO_ENABLED=1\nINTRO_FILE=$HOME/none.mp4\n' >"$D/.config/fallout-nv/vault-os.conf"
cat >"$D/xfconf.db" <<EOF
xsettings|/Net/ThemeName|Vault.OS
xfwm4|/general/theme|Vault.OS-Reduced
xfce4-panel|/panels/panel-1/length|100
xfce4-panel|/panels/panel-2/length|10.5
xfce4-panel|/panels/panel-2/position|p=10
xfce4-desktop|/backdrop/screen0/monitor1/workspace0/last-image|/nonexistent/wall.png
xfce4-terminal|/scrolling-bar|TERMINAL_SCROLLBAR_LEFT
xfce4-session|/general/LockCommand|xflock4
EOF
compare doctor-bad -- env HOME="$D" XDG_CONFIG_HOME= "$B/bin/vault-os" doctor
: >"$D/xfconf.db"
rm -rf "$D/.config/autostart"
compare doctor-empty -- env HOME="$D" XDG_CONFIG_HOME="$D/.config" VAULT_OS_ROOT= "$work/bare/bin/vault-os" doctor

# --- timing (lint on the clean tree, doctor on the ok home) ---
t() { local s e; s=$(date +%s%N); "$@" >/dev/null 2>&1 || true; e=$(date +%s%N); echo $(( (e - s) / 1000000 )); }
best() { local b=999999 v i; for i in 1 2 3; do v=$(t "$@"); (( v < b )) && b=$v; done; echo "$b"; }
echo "TIME  lint   bash $(VAULTOS_DOCTOR= best "$work/clean/bin/vault-os" lint "$work/clean") ms   native $(best "$ND" lint "$work/clean") ms"
echo "TIME  doctor bash $(HOME="$work/home-ok" VAULTOS_DOCTOR= best "$work/clean/bin/vault-os" doctor) ms   native $(HOME="$work/home-ok" VAULTOS_DOCTOR="$ND" best "$work/clean/bin/vault-os" doctor) ms"

echo
if [[ "$FAIL" -eq 0 ]]; then echo "All doctor/lint parity tests passed."; exit 0; fi
echo "$FAIL test(s) failed."
exit 1

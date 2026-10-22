#!/usr/bin/env bash
# Vault.OS installer — Arch Linux + XFCE session files.
# Idempotent. Safe to re-run after git pull.
# Copies a changed file aside before replacing it. Does not restart XFCE or LightDM.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME="${HOME:-/home/$USER}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLY=1
SYSTEM=0
PACKAGES=0
LEGACY=0
BAK_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

# Phosphor #1AFF6B (26;255;107).
info()  { printf '\033[38;2;26;255;107m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[38;2;26;255;107m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[38;2;255;176;0m  !\033[0m %s\n' "$*"; }

refuse() {
  local code="$1"
  shift
  echo "install.sh: $* ($code)" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    "Usage: $0 [options]" \
    '' \
    '  --no-apply     Install files only (do not call vault-os apply)' \
    '  --system       Also install LightDM greeter + GRUB background (sudo)' \
    '  --packages     Install the desktop package list with pacman --needed' \
    '  --legacy       Also install Pip-Boy packs, app skins, and Kvantum' \
    '  -h, --help     Show this help'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-apply) APPLY=0 ;;
    --system) SYSTEM=1 ;;
    --packages) PACKAGES=1 ;;
    --legacy) LEGACY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) refuse E100 "unknown option: $1" ;;
  esac
  shift
done

# Copy an existing file or link aside. A failed copy stops the install.
backup_path() {
  local dest="$1" base cand n=0
  [[ -e "$dest" || -L "$dest" ]] || return 0
  base="${dest}.vaultos-bak-${BAK_STAMP}"
  cand="$base"
  while [[ -e "$cand" || -L "$cand" ]]; do
    n=$((n + 1))
    cand="${base}.${n}"
  done
  cp -a "$dest" "$cand" \
    || refuse E102 "could not back up $dest, so it was left unchanged"
  ok "backup ${cand##*/}"
}

# Replace dest with tmp when the bytes differ. tmp is removed.
commit_file() {
  local tmp="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    return 0
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    backup_path "$dest"
  fi
  cp -f --remove-destination "$tmp" "$dest"
  rm -f "$tmp"
}

install_file() {
  local src="$1" dest="$2" tmp
  [[ -f "$src" ]] || return 0
  tmp="$(mktemp)"
  cp -f "$src" "$tmp"
  commit_file "$tmp" "$dest"
}

subst_home() {
  local src="$1" dest="$2" tmp
  tmp="$(mktemp)"
  sed "s|@HOME@|$HOME|g" "$src" >"$tmp"
  commit_file "$tmp" "$dest"
}

install_new() {
  # Write dest only when it does not already exist (never clobber wallpaper/conf).
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    return 0
  fi
  subst_home "$src" "$dest"
}

# Directory copy. Files rsync replaces are kept beside dest.
rsync_tree() {
  local src="$1" dest="$2"
  shift 2
  mkdir -p "$dest"
  # Backup copies live beside the files they came from. Leave them in place.
  rsync -a --backup --backup-dir "${dest%/}.vaultos-bak-${BAK_STAMP}" \
    --exclude '*.vaultos-bak-*' "$@" "$src" "$dest"
}

command -v rsync >/dev/null \
  || refuse E101 "rsync is not installed, so files cannot be copied"

VER="$(tr -d '[:space:]' <"$ROOT/overlay/VERSION" 2>/dev/null || echo unknown)"
info "Vault.OS $VER — installing desktop files"
(( LEGACY == 1 )) && info "Pip-Boy packs included (--legacy)"

# ---------------------------------------------------------------------------
# Optional packages (add alongside; never hold or replace installed packages)
# ---------------------------------------------------------------------------
if (( PACKAGES == 1 )); then
  list="$ROOT/overlay/packages/packages.desktop"
  [[ -f "$list" ]] \
    || refuse E103 "package list overlay/packages/packages.desktop is missing, so --packages stopped"
  if command -v pacman >/dev/null; then
    mapfile -t pkgs < <(grep -vE '^[[:space:]]*(#|$)' "$list")
    pkgs+=(qt5ct qt6ct rsync)
    (( LEGACY == 1 )) && pkgs+=(kvantum)
    info "Installing recommended packages..."
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" || warn "pacman returned non-zero"
  else
    warn "pacman not found, so --packages skipped"
  fi
fi

# ---------------------------------------------------------------------------
# Themes / icons / cursors / fonts / wallpapers
# ---------------------------------------------------------------------------
info "Installing theme, icons, fonts, wallpapers..."
mkdir -p "$HOME/.themes" "$HOME/.icons" "$DATA/icons" "$DATA/backgrounds" \
  "$DATA/fonts/ShareTechMono" "$HOME/.local/bin"

# terminal.css is owned by the phosphor dial (seeded below), not by this tree.
rsync_tree "$ROOT/themes/Vault.OS/" "$HOME/.themes/Vault.OS/" \
  --delete --exclude 'icon-theme.cache' --exclude 'terminal.css'
if [[ -d "$ROOT/themes/Vault.OS-Reduced" ]]; then
  rsync_tree "$ROOT/themes/Vault.OS-Reduced/" "$HOME/.themes/Vault.OS-Reduced/" \
    --delete --exclude 'icon-theme.cache'
fi
# Phosphor dial reads terminal.reduced.css. Seed both GTK copies after the theme sync.
if [[ -f "$ROOT/source/xfce4-terminal/terminal.reduced.css" ]]; then
  for t in gtk-3.0 gtk-3.20; do
    [[ -d "$HOME/.themes/Vault.OS/$t" ]] || continue
    install_file "$ROOT/source/xfce4-terminal/terminal.reduced.css" \
      "$HOME/.themes/Vault.OS/$t/terminal.css"
  done
fi
rsync_tree "$ROOT/icons/Vault.OS/" "$HOME/.icons/Vault.OS/" \
  --delete --exclude 'icon-theme.cache'
rsync_tree "$ROOT/icons/Vault.OS/" "$DATA/icons/Vault.OS/" \
  --exclude 'icon-theme.cache' || true

if (( LEGACY == 1 )); then
  rsync_tree "$ROOT/themes/PipBoy-NV/" "$HOME/.themes/PipBoy-NV/" \
    --delete --exclude 'icon-theme.cache'
  rsync_tree "$ROOT/icons/FalloutMojave/" "$DATA/icons/FalloutMojave/" \
    --delete --exclude 'icon-theme.cache'
  rsync_tree "$ROOT/icons/PipBoy-Dock/" "$DATA/icons/PipBoy-Dock/"
  rsync_tree "$ROOT/extras/dock/" "$HOME/.icons/vault-dock/"
  rsync_tree "$ROOT/cursors/PipBoy-NV-Cursors/" "$HOME/.icons/PipBoy-NV-Cursors/" --delete
  ln -sfn "$HOME/.icons/PipBoy-NV-Cursors" "$DATA/icons/PipBoy-NV-Cursors"
  ln -sfn "$DATA/icons/FalloutMojave" "$HOME/.icons/FalloutMojave"
  mkdir -p "$DATA/fonts/pipboy" "$DATA/sounds"
  rsync_tree "$ROOT/fonts/pipboy/" "$DATA/fonts/pipboy/"
  rsync_tree "$ROOT/sounds/PipBoy-NV/" "$DATA/sounds/PipBoy-NV/"
else
  rsync_tree "$ROOT/extras/dock/" "$HOME/.icons/vault-dock/"
fi

rsync_tree "$ROOT/fonts/ShareTechMono/" "$DATA/fonts/ShareTechMono/"
rsync_tree "$ROOT/wallpapers/" "$DATA/backgrounds/"
if [[ -d "$ROOT/source/wallpapers" ]]; then
  mkdir -p "$DATA/backgrounds/Vault.OS"
  rsync_tree "$ROOT/source/wallpapers/" "$DATA/backgrounds/Vault.OS/"
fi
mkdir -p "$DATA/vault-os/panel"
rsync_tree "$ROOT/extras/panel/" "$DATA/vault-os/panel/"

if command -v fc-cache >/dev/null; then
  fc-cache -f "$DATA/fonts" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f "$HOME/.icons/Vault.OS" >/dev/null 2>&1 || true
fi
ok "assets installed"

# ---------------------------------------------------------------------------
# Scripts
# ---------------------------------------------------------------------------
info "Installing vault-os commands..."
install_file "$ROOT/bin/vault-os" "$HOME/.local/bin/vault-os"
install_file "$ROOT/bin/vault-os-lock" "$HOME/.local/bin/vault-os-lock"
install_file "$ROOT/bin/vault-os-close-all" "$HOME/.local/bin/vault-os-close-all"
install_file "$ROOT/bin/vault-os-install-system-theme" "$HOME/.local/bin/vault-os-install-system-theme"
install_file "$ROOT/bin/vault-os-chromium-theme" "$HOME/.local/bin/vault-os-chromium-theme"
chmod 0755 "$HOME/.local/bin/vault-os" \
  "$HOME/.local/bin/vault-os-lock" \
  "$HOME/.local/bin/vault-os-close-all" \
  "$HOME/.local/bin/vault-os-install-system-theme" \
  "$HOME/.local/bin/vault-os-chromium-theme"
# GUI pkexec helper for vault-os-lockdown / vault-os-system-fix (link, so it tracks the checkout)
chmod 0755 "$ROOT/bin/vaultos-root"
ln -sfn "$ROOT/bin/vaultos-root" "$HOME/.local/bin/vaultos-root"
ok "commands in ~/.local/bin"
# Native C++ helpers. src/Makefile checks each tool's own g++/pkg-config
# deps and skips just that tool when something is missing; every native
# binary has a script fallback, so a skipped or failed tool changes nothing.
if command -v g++ >/dev/null && command -v make >/dev/null && command -v pkg-config >/dev/null; then
  if make -s -C "$ROOT/src" install PREFIX="$HOME/.local"; then
    ok "native helpers built (C++); any 'skip' above keeps its script fallback"
  else
    warn "some C++ helpers failed to build, their script fallbacks stay in place"
  fi
else
  warn "g++, make or pkg-config missing, skipping C++ helpers (script fallbacks stay in place)"
fi

# ---------------------------------------------------------------------------
# Configs
# ---------------------------------------------------------------------------
info "Installing configs..."
mkdir -p "$CFG" "$CFG/gtk-3.0" "$CFG/gtk-4.0" "$CFG/fontconfig" \
  "$CFG/qt5ct" "$CFG/qt6ct" \
  "$CFG/environment.d" "$CFG/fallout-nv" \
  "$CFG/xfce4/terminal" "$CFG/xfce4/xfconf/xfce-perchannel-xml" \
  "$CFG/xfce4/panel" "$CFG/xfce4/autostart"

if (( LEGACY == 1 )); then
  rsync_tree "$ROOT/config/pipboy/" "$CFG/pipboy/"
  chmod +x "$CFG/pipboy/"*.sh "$CFG/pipboy/pipboy.bash" 2>/dev/null || true
  mkdir -p "$CFG/Kvantum"
  rsync_tree "$ROOT/config/Kvantum/" "$CFG/Kvantum/"
fi

gtk3tmp="$(mktemp)"
if [[ -f "$ROOT/source/gtk-overlay/gtk.css" ]]; then
  if ! sed "s|\\$HOME|$HOME|g; s|file://.*/.themes/|file://$HOME/.themes/|" \
      "$ROOT/source/gtk-overlay/gtk.css" >"$gtk3tmp" 2>/dev/null; then
    printf '%s\n' "/* Vault.OS overlay */" \
      "@import url(\"file://$HOME/.themes/Vault.OS/gtk-3.0/hud.css\");" >"$gtk3tmp"
  fi
else
  sed "s|\\$HOME|$HOME|g" "$ROOT/config/gtk-3.0/gtk.css" >"$gtk3tmp"
fi
commit_file "$gtk3tmp" "$CFG/gtk-3.0/gtk.css"

install_file "$ROOT/config/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
if [[ -f "$ROOT/source/gtk-overlay/gtk4.css" ]]; then
  install_file "$ROOT/source/gtk-overlay/gtk4.css" "$CFG/gtk-4.0/gtk.css"
else
  install_file "$ROOT/config/gtk-4.0/gtk.css" "$CFG/gtk-4.0/gtk.css"
fi
install_file "$ROOT/config/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"
install_file "$ROOT/config/gtkrc-2.0" "$HOME/.gtkrc-2.0"
install_file "$ROOT/config/picom.conf" "$CFG/picom.conf"
install_file "$ROOT/config/picom-anim.conf" "$CFG/picom-anim.conf"
install_file "$ROOT/config/picom-reduced.conf" "$CFG/picom-reduced.conf"
install_file "$ROOT/config/fontconfig/fonts.conf" "$CFG/fontconfig/fonts.conf"
install_file "$ROOT/config/qt5ct/qt5ct.conf" "$CFG/qt5ct/qt5ct.conf"
install_file "$ROOT/config/qt6ct/qt6ct.conf" "$CFG/qt6ct/qt6ct.conf"
if (( LEGACY == 1 )); then
  for q in "$CFG/qt5ct/qt5ct.conf" "$CFG/qt6ct/qt6ct.conf"; do
    [[ -f "$q" ]] || continue
    grep -q '^style=kvantum$' "$q" && continue
    backup_path "$q"
    sed -i 's/^style=.*/style=kvantum/' "$q"
  done
fi
install_file "$ROOT/config/environment.d/qt.conf" "$CFG/environment.d/qt.conf"
install_file "$ROOT/config/environment.d/vault-os.conf" "$CFG/environment.d/vault-os.conf"
[[ -f "$HOME/.xprofile" ]] || install_file "$ROOT/config/xprofile" "$HOME/.xprofile"

install_new "$ROOT/config/fallout-nv/vault-os.conf" "$CFG/fallout-nv/vault-os.conf"
# Terminal theme: source/xfce4-terminal is the single source of truth.
if [[ -d "$ROOT/source/xfce4-terminal" ]]; then
  mkdir -p "$HOME/Vault.OS/source" "$DATA/xfce4/terminal/colorschemes" "$DATA/Vault.OS" "$CFG/Vault.OS"
  rsync_tree "$ROOT/source/xfce4-terminal/" "$HOME/Vault.OS/source/xfce4-terminal/"
  install_file "$ROOT/source/xfce4-terminal/terminalrc.reduced" "$CFG/xfce4/terminal/terminalrc"
  install_file "$ROOT/source/xfce4-terminal/Vault.OS.theme" \
    "$DATA/xfce4/terminal/colorschemes/Vault.OS.theme"
  install_file "$ROOT/source/xfce4-terminal/scanline.png" "$DATA/Vault.OS/scanline.png"
  if [[ -f "$CFG/Vault.OS/terminal-phosphor" ]] \
     && [[ "$(tr -d '[:space:]' <"$CFG/Vault.OS/terminal-phosphor")" != reduced ]]; then
    backup_path "$CFG/Vault.OS/terminal-phosphor"
  fi
  echo reduced >"$CFG/Vault.OS/terminal-phosphor"
fi
install_file "$ROOT/config/xfce4/helpers.rc" "$CFG/xfce4/helpers.rc"

for xml in xsettings.xml xfwm4.xml xfce4-notifyd.xml thunar.xml; do
  [[ -f "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/$xml" ]] || continue
  subst_home "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/$xml" \
    "$CFG/xfce4/xfconf/xfce-perchannel-xml/$xml"
done
# Never overwrite an existing desktop/panel layout (wallpaper is user-owned).
install_new "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" \
  "$CFG/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
install_new "$ROOT/config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" \
  "$CFG/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"

for id in 13 14 15 16 19; do
  mkdir -p "$CFG/xfce4/panel/launcher-$id"
done
subst_home "$ROOT/config/xfce4/panel/launcher-13.desktop" \
  "$CFG/xfce4/panel/launcher-13/17851123751.desktop"
subst_home "$ROOT/config/xfce4/panel/launcher-14.desktop" \
  "$CFG/xfce4/panel/launcher-14/17851123752.desktop"
subst_home "$ROOT/config/xfce4/panel/launcher-15.desktop" \
  "$CFG/xfce4/panel/launcher-15/178511277010.desktop"
subst_home "$ROOT/config/xfce4/panel/launcher-16.desktop" \
  "$CFG/xfce4/panel/launcher-16/17851123754.desktop"
subst_home "$ROOT/config/xfce4/panel/launcher-19.desktop" \
  "$CFG/xfce4/panel/launcher-19/vault-os-close-all.desktop"

subst_home "$ROOT/config/xfce4/autostart/picom.desktop" \
  "$CFG/xfce4/autostart/picom.desktop"
subst_home "$ROOT/config/xfce4/autostart/vault-os-session.desktop" \
  "$CFG/xfce4/autostart/vault-os-session.desktop"
subst_home "$ROOT/config/xfce4/autostart/vault-os-theme-guard.desktop" \
  "$CFG/xfce4/autostart/vault-os-theme-guard.desktop"
if (( LEGACY == 1 )); then
  subst_home "$ROOT/config/xfce4/autostart/vault-os-chromium-theme.desktop" \
    "$CFG/xfce4/autostart/vault-os-chromium-theme.desktop"
fi
ok "configs installed"

# ---------------------------------------------------------------------------
# App skins (Pip-Boy). Canon install leaves these alone.
# ---------------------------------------------------------------------------
if (( LEGACY == 1 )); then
  info "Installing Pip-Boy app skins..."
  mkdir -p "$CFG/Vencord/themes" "$CFG/BetterDiscord/themes" \
    "$DATA/chromium-extensions/pipboy-nv-theme"
  install_file "$ROOT/config/discord/PipBoyNV.theme.css" "$CFG/Vencord/themes/PipBoyNV.theme.css"
  install_file "$ROOT/config/discord/PipBoyNV.theme.css" "$CFG/BetterDiscord/themes/PipBoyNV.theme.css"
  rsync_tree "$ROOT/config/chromium/pipboy-nv-theme/" "$DATA/chromium-extensions/pipboy-nv-theme/"

  for codedir in \
    "$CFG/Code - OSS/User" \
    "$CFG/VSCodium/User" \
    "$CFG/Code/User"
  do
    mkdir -p "$codedir/themes"
    install_file "$ROOT/config/vscode/pipboy-nv-color-theme.json" \
      "$codedir/themes/pipboy-nv-color-theme.json"
    [[ -f "$codedir/settings.json" ]] \
      || install_file "$ROOT/config/vscode/settings-snippet.json" "$codedir/settings.json"
  done

  shopt -s nullglob
  for prof in "$HOME/.mozilla/firefox/"*.default* \
              "$HOME/.mozilla/firefox/"*.default-release \
              "$CFG/mozilla/firefox/"*.default*; do
    [[ -d "$prof" ]] || continue
    mkdir -p "$prof/chrome"
    install_file "$ROOT/config/firefox/chrome/userChrome.css" "$prof/chrome/userChrome.css"
    if [[ ! -f "$prof/user.js" ]]; then
      install_file "$ROOT/config/firefox/user.js" "$prof/user.js"
    elif ! grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "$prof/user.js" 2>/dev/null; then
      backup_path "$prof/user.js"
      cat "$ROOT/config/firefox/user.js" >>"$prof/user.js"
    fi
  done
  shopt -u nullglob
  ok "app skins installed"
fi

# ---------------------------------------------------------------------------
# bashrc / PATH
# ---------------------------------------------------------------------------
if (( LEGACY == 1 )) && [[ -f "$HOME/.bashrc" ]] && ! grep -q 'pipboy theme' "$HOME/.bashrc"; then
  backup_path "$HOME/.bashrc"
  printf '%s\n' \
    '' \
    '# -- pipboy theme --' \
    'if [[ -r "$HOME/.config/pipboy/pipboy.bash" ]]; then' \
    '  # shellcheck source=/dev/null' \
    '  source "$HOME/.config/pipboy/pipboy.bash"' \
    'fi' \
    '# -- end pipboy theme --' \
    >>"$HOME/.bashrc"
  ok "hooked Pip-Boy theme into bashrc"
fi

if [[ -f "$HOME/.bashrc" ]] && ! grep -q '\.local/bin' "$HOME/.bashrc"; then
  backup_path "$HOME/.bashrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
fi

# ---------------------------------------------------------------------------
# User timer. Does not restart the XFCE session or LightDM.
# ---------------------------------------------------------------------------
if command -v systemctl >/dev/null; then
  mkdir -p "$HOME/.config/systemd/user"
  install_file "$ROOT/extras/systemd/vault-os-watch.service" \
    "$HOME/.config/systemd/user/vault-os-watch.service"
  install_file "$ROOT/extras/systemd/vault-os-watch.timer" \
    "$HOME/.config/systemd/user/vault-os-watch.timer"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now vault-os-watch.timer 2>/dev/null || true
fi

if (( APPLY == 1 )); then
  if command -v xfconf-query >/dev/null && [[ -n "${DISPLAY:-}" ]]; then
    info "Applying live session..."
    "$HOME/.local/bin/vault-os" apply || warn "vault-os apply had warnings"
  else
    warn "No live XFCE session — files are installed. Log in and run: vault-os apply"
  fi
fi

if (( SYSTEM == 1 )); then
  info "Installing system greeter / GRUB..."
  "$HOME/.local/bin/vault-os-install-system-theme" || warn "system theme install failed"
fi

info "Done. Log out and back in, then run: vault-os doctor"
printf '%s\n' '' '  Theme   Vault.OS' '  Icons   Vault.OS' '  Cursor  Vault.OS' \
  '  Walls   ~/.local/share/backgrounds/' '  Pick a wallpaper in Settings -> Desktop' ''

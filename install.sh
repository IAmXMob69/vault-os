#!/usr/bin/env bash
# Vault-OS installer — Arch Linux + XFCE Pip-Boy rice
# Idempotent. Safe to re-run after git pull.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME="${HOME:-/home/$USER}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLY=1
SYSTEM=0
PACKAGES=0

info()  { printf '\033[38;2;51;255;106m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[38;2;51;255;106m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[38;2;255;176;0m  !\033[0m %s\n' "$*"; }

usage() {
  printf '%s\n' \
    "Usage: $0 [options]" \
    '' \
    '  --no-apply     Install files only (do not call vault-os apply)' \
    '  --system       Also install LightDM greeter + GRUB background (sudo)' \
    '  --packages     Install recommended Arch packages with pacman' \
    '  -h, --help     Show this help'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-apply) APPLY=0 ;;
    --system) SYSTEM=1 ;;
    --packages) PACKAGES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

subst_home() {
  # Replace @HOME@ placeholders with the installing user's home.
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  sed "s|@HOME@|$HOME|g" "$src" >"$dest"
}

install_new() {
  # Write dest only when it does not already exist (never clobber wallpaper/conf).
  local src="$1" dest="$2"
  if [[ -e "$dest" ]]; then
    return 0
  fi
  subst_home "$src" "$dest"
}

info "Vault-OS — installing Pip-Boy rice into $HOME"

# ---------------------------------------------------------------------------
# Optional packages
# ---------------------------------------------------------------------------
if (( PACKAGES == 1 )); then
  if command -v pacman >/dev/null; then
    info "Installing recommended packages..."
    sudo pacman -S --needed --noconfirm \
      xfce4 xfce4-goodies papirus-icon-theme \
      kvantum qt5ct qt6ct picom \
      xfce4-whiskermenu-plugin python-gobject libwnck3 rsync \
      ttf-liberation noto-fonts || warn "pacman returned non-zero"
  else
    warn "pacman not found — skip --packages"
  fi
fi

# ---------------------------------------------------------------------------
# Themes / icons / cursors / fonts / wallpapers / sounds
# ---------------------------------------------------------------------------
info "Installing theme, icons, cursors, fonts, wallpapers..."
mkdir -p "$HOME/.themes" "$HOME/.icons" "$DATA/icons" "$DATA/backgrounds" \
  "$DATA/fonts/ShareTechMono" "$DATA/fonts/pipboy" "$DATA/sounds" \
  "$DATA/vault-os/panel" "$HOME/.local/bin"

rsync -a --delete --exclude 'icon-theme.cache' \
  "$ROOT/themes/PipBoy-NV/" "$HOME/.themes/PipBoy-NV/"
rsync -a --delete --exclude 'icon-theme.cache' \
  "$ROOT/icons/FalloutMojave/" "$DATA/icons/FalloutMojave/"
rsync -a "$ROOT/icons/PipBoy-Dock/" "$DATA/icons/PipBoy-Dock/"
rsync -a "$ROOT/extras/dock/" "$HOME/.icons/vault-dock/"
rsync -a --delete "$ROOT/cursors/PipBoy-NV-Cursors/" "$HOME/.icons/PipBoy-NV-Cursors/"
ln -sfn "$HOME/.icons/PipBoy-NV-Cursors" "$DATA/icons/PipBoy-NV-Cursors"
ln -sfn "$DATA/icons/FalloutMojave" "$HOME/.icons/FalloutMojave"

rsync -a "$ROOT/fonts/ShareTechMono/" "$DATA/fonts/ShareTechMono/"
rsync -a "$ROOT/fonts/pipboy/" "$DATA/fonts/pipboy/"
rsync -a "$ROOT/wallpapers/" "$DATA/backgrounds/"
rsync -a "$ROOT/sounds/PipBoy-NV/" "$DATA/sounds/PipBoy-NV/"
rsync -a "$ROOT/extras/panel/" "$DATA/vault-os/panel/"

if command -v fc-cache >/dev/null; then
  fc-cache -f "$DATA/fonts" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f "$DATA/icons/FalloutMojave" >/dev/null 2>&1 || true
fi
ok "assets installed"

# ---------------------------------------------------------------------------
# Scripts
# ---------------------------------------------------------------------------
info "Installing vault-os commands..."
install -m 0755 "$ROOT/bin/vault-os" "$HOME/.local/bin/vault-os"
install -m 0755 "$ROOT/bin/vault-os-lock" "$HOME/.local/bin/vault-os-lock"
install -m 0755 "$ROOT/bin/vault-os-close-all" "$HOME/.local/bin/vault-os-close-all"
install -m 0755 "$ROOT/bin/vault-os-install-system-theme" "$HOME/.local/bin/vault-os-install-system-theme"
install -m 0755 "$ROOT/bin/vault-os-chromium-theme" "$HOME/.local/bin/vault-os-chromium-theme"
ok "binaries in ~/.local/bin"

# ---------------------------------------------------------------------------
# Configs
# ---------------------------------------------------------------------------
info "Installing configs..."
rsync -a "$ROOT/config/pipboy/" "$CFG/pipboy/"
chmod +x "$CFG/pipboy/"*.sh "$CFG/pipboy/pipboy.bash" 2>/dev/null || true

mkdir -p "$CFG/gtk-3.0" "$CFG/gtk-4.0" "$CFG/fontconfig" \
  "$CFG/Kvantum/PipBoy-NV" "$CFG/qt5ct" "$CFG/qt6ct" \
  "$CFG/environment.d" "$CFG/fallout-nv" \
  "$CFG/xfce4/terminal" "$CFG/xfce4/xfconf/xfce-perchannel-xml" \
  "$CFG/xfce4/panel" "$CFG/xfce4/autostart" \
  "$CFG/Vencord/themes" "$CFG/BetterDiscord/themes" \
  "$DATA/chromium-extensions/pipboy-nv-theme"

cp -f "$ROOT/config/gtk-3.0/gtk.css" "$CFG/gtk-3.0/gtk.css"
cp -f "$ROOT/config/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
cp -f "$ROOT/config/gtk-4.0/gtk.css" "$CFG/gtk-4.0/gtk.css"
cp -f "$ROOT/config/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"
cp -f "$ROOT/config/gtkrc-2.0" "$HOME/.gtkrc-2.0"
cp -f "$ROOT/config/picom.conf" "$CFG/picom.conf"
cp -f "$ROOT/config/fontconfig/fonts.conf" "$CFG/fontconfig/fonts.conf"
rsync -a "$ROOT/config/Kvantum/" "$CFG/Kvantum/"
cp -f "$ROOT/config/qt5ct/qt5ct.conf" "$CFG/qt5ct/qt5ct.conf"
cp -f "$ROOT/config/qt6ct/qt6ct.conf" "$CFG/qt6ct/qt6ct.conf"
cp -f "$ROOT/config/environment.d/qt.conf" "$CFG/environment.d/qt.conf"
cp -f "$ROOT/config/environment.d/vault-os.conf" "$CFG/environment.d/vault-os.conf"
[[ -f "$HOME/.xprofile" ]] || cp -f "$ROOT/config/xprofile" "$HOME/.xprofile"

install_new "$ROOT/config/fallout-nv/vault-os.conf" "$CFG/fallout-nv/vault-os.conf"
cp -f "$ROOT/config/xfce4/terminal/terminalrc" "$CFG/xfce4/terminal/terminalrc"
[[ -f "$ROOT/config/xfce4/helpers.rc" ]] && cp -f "$ROOT/config/xfce4/helpers.rc" "$CFG/xfce4/helpers.rc"

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

# Dock launchers
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

# Autostart (portable Exec=)
subst_home "$ROOT/config/xfce4/autostart/picom.desktop" \
  "$CFG/xfce4/autostart/picom.desktop"
subst_home "$ROOT/config/xfce4/autostart/vault-os-session.desktop" \
  "$CFG/xfce4/autostart/vault-os-session.desktop"
subst_home "$ROOT/config/xfce4/autostart/vault-os-theme-guard.desktop" \
  "$CFG/xfce4/autostart/vault-os-theme-guard.desktop"
subst_home "$ROOT/config/xfce4/autostart/vault-os-chromium-theme.desktop" \
  "$CFG/xfce4/autostart/vault-os-chromium-theme.desktop"
ok "configs installed"

# ---------------------------------------------------------------------------
# App skins
# ---------------------------------------------------------------------------
info "Installing app skins..."
cp -f "$ROOT/config/discord/PipBoyNV.theme.css" "$CFG/Vencord/themes/PipBoyNV.theme.css"
cp -f "$ROOT/config/discord/PipBoyNV.theme.css" "$CFG/BetterDiscord/themes/PipBoyNV.theme.css"
rsync -a "$ROOT/config/chromium/pipboy-nv-theme/" "$DATA/chromium-extensions/pipboy-nv-theme/"

# VS Code OSS / VSCodium / Code
for codedir in \
  "$CFG/Code - OSS/User" \
  "$CFG/VSCodium/User" \
  "$CFG/Code/User"
do
  mkdir -p "$codedir/themes"
  cp -f "$ROOT/config/vscode/pipboy-nv-color-theme.json" "$codedir/themes/pipboy-nv-color-theme.json"
  if [[ -f "$ROOT/config/vscode/settings-snippet.json" && ! -f "$codedir/settings.json" ]]; then
    cp -f "$ROOT/config/vscode/settings-snippet.json" "$codedir/settings.json"
  fi
done

# Firefox: drop chrome + user.js onto existing profiles (never overwrite prefs.js)
shopt -s nullglob
for prof in "$HOME/.mozilla/firefox/"*.default* \
            "$HOME/.mozilla/firefox/"*.default-release \
            "$CFG/mozilla/firefox/"*.default*; do
  [[ -d "$prof" ]] || continue
  mkdir -p "$prof/chrome"
  cp -f "$ROOT/config/firefox/chrome/userChrome.css" "$prof/chrome/userChrome.css"
  if [[ ! -f "$prof/user.js" ]]; then
    cp -f "$ROOT/config/firefox/user.js" "$prof/user.js"
  else
    grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' "$prof/user.js" 2>/dev/null \
      || cat "$ROOT/config/firefox/user.js" >>"$prof/user.js"
  fi
done
shopt -u nullglob
ok "app skins installed"

# ---------------------------------------------------------------------------
# bashrc / PATH
# ---------------------------------------------------------------------------
if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'pipboy theme' "$HOME/.bashrc"; then
  printf '%s\n' \
    '' \
    '# -- pipboy theme --' \
    'if [[ -r "$HOME/.config/pipboy/pipboy.bash" ]]; then' \
    '  # shellcheck source=/dev/null' \
    '  source "$HOME/.config/pipboy/pipboy.bash"' \
    'fi' \
    '# -- end pipboy theme --' \
    >>"$HOME/.bashrc"
  ok "hooked Pip-Boy theme into ~/.bashrc"
fi

if [[ -f "$HOME/.bashrc" ]] && ! grep -q '\.local/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
fi

# ---------------------------------------------------------------------------
# Apply live (if an XFCE session is running)
# ---------------------------------------------------------------------------
# systemd user watch (theme/panel/xfdesktop liveness — does not touch wallpaper)
if command -v systemctl >/dev/null; then
  mkdir -p "$HOME/.config/systemd/user"
  cp -f "$ROOT/extras/systemd/vault-os-watch.service" "$HOME/.config/systemd/user/vault-os-watch.service"
  cp -f "$ROOT/extras/systemd/vault-os-watch.timer" "$HOME/.config/systemd/user/vault-os-watch.timer"
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

# ---------------------------------------------------------------------------
# Optional system theme
# ---------------------------------------------------------------------------
if (( SYSTEM == 1 )); then
  info "Installing system greeter / GRUB..."
  "$HOME/.local/bin/vault-os-install-system-theme" || warn "system theme install failed"
fi

info "Done. Log out and back in (or run: vault-os doctor)"
printf '\n  Theme   PipBoy-NV\n  Icons   FalloutMojave\n  Cursor  PipBoy-NV-Cursors\n  Walls   ~/.local/share/backgrounds/  (pick one in Settings → Desktop)\n\n'

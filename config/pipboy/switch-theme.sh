#!/usr/bin/env bash
# Switch Pip-Boy terminal between green and amber phosphor
set -euo pipefail

RC="$HOME/.config/xfce4/terminal/terminalrc"
THEME="${1:-green}"

if [[ ! -f "$RC" ]]; then
  echo "No terminalrc at $RC" >&2
  exit 1
fi

case "$THEME" in
  green|g)
    FG='#33ff66'
    BG='#050d05'
    CUR='#66ff99'
    BOLD='#7dff9a'
    SEL='#1a3d1a'
    PAL='#0a140a;#ff4444;#33ff66;#c8ff4a;#3aa0ff;#b066ff;#33e6cc;#a8d4a8;#1a331a;#ff7777;#66ff99;#e0ff88;#66b8ff;#d090ff;#66f0dd;#e8ffe8'
    NAME='green'
    ;;
  amber|a|orange)
    FG='#ffb000'
    BG='#100a00'
    CUR='#ffcc44'
    BOLD='#ffd060'
    SEL='#3d2a10'
    PAL='#100a00;#ff4444;#ffb000;#ffd060;#3aa0ff;#ff66aa;#ffcc66;#e0c8a0;#2a1a00;#ff7777;#ffcc44;#ffe088;#66b8ff;#ff90cc;#ffe0a0;#fff0d0'
    NAME='amber'
    ;;
  *)
    echo "Usage: $0 {green|amber}" >&2
    exit 1
    ;;
esac

# In-place updates with sed
sed -i \
  -e "s|^ColorForeground=.*|ColorForeground=${FG}|" \
  -e "s|^ColorBackground=.*|ColorBackground=${BG}|" \
  -e "s|^ColorCursor=.*|ColorCursor=${CUR}|" \
  -e "s|^ColorBold=.*|ColorBold=${BOLD}|" \
  -e "s|^ColorSelection=.*|ColorSelection=${SEL}|" \
  -e "s|^ColorPalette=.*|ColorPalette=${PAL}|" \
  "$RC"

echo "Pip-Boy phosphor set to ${NAME}."
echo "Open a new terminal tab/window to see the full palette (or restart xfce4-terminal)."

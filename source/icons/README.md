# Icons, cursors, wallpaper

Vault.OS plate language: phosphor glyph on an inset plate, 1px bevel (`bevel-hi` / `bevel-lo`), optional corner LED. Destructive marks use rad-red plus a shape cue (X, linked rings, triangle), never color alone. Cursor is vault-black fill with a phosphor outline — no amber chrome.

## Install

```bash
mkdir -p ~/.icons
cp -a source/icons/. ~/.icons/Vault.OS/
# or use the packaged tree:
# cp -a icons/Vault.OS ~/.icons/
gtk-update-icon-cache -f ~/.icons/Vault.OS

mkdir -p ~/.local/share/backgrounds/Vault.OS
cp -a source/wallpapers/vault-111.png ~/.local/share/backgrounds/Vault.OS/

xfconf-query -c xsettings -p /Net/IconThemeName -s Vault.OS
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s Vault.OS
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 24
```

Dock launchers may point at `~/.icons/vault-dock/*.png` (same stamp language). Regenerate with `gen_dock.py` / `gen_desktop_plates.py` / `gen_assets.py` if you change tokens.

Sizes: 16 / 24 / 32 / 48. Theme inherits `hicolor` only.

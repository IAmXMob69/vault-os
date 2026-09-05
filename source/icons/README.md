# Icons and cursors

The Vault.OS icon theme is a small set of stamped plates for XFCE — phosphor on dark metal, sharp corners, no glossy stock icons.

## Install

Prefer the packaged tree (what `./bin/vault-os install` uses):

```bash
mkdir -p ~/.icons
cp -a icons/Vault.OS ~/.icons/
gtk-update-icon-cache -f ~/.icons/Vault.OS

mkdir -p ~/.local/share/backgrounds/Vault.OS
cp -a source/wallpapers/. ~/.local/share/backgrounds/Vault.OS/

xfconf-query -c xsettings -p /Net/IconThemeName -s Vault.OS
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s Vault.OS
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 24
```

Working files live under `source/icons/` if you need to regenerate plates (`gen_assets.py`, `gen_dock.py`, `gen_desktop_plates.py`). Dock PNGs for the bottom panel go in `~/.icons/vault-dock/`.

Sizes are 16, 24, 32, and 48. The theme inherits `hicolor`.

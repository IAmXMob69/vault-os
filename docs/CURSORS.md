# PipBoy-NV-Cursors

CRT phosphor green X11 cursor theme for Vault-OS / PipBoy-NV.

## Location
- `~/.icons/PipBoy-NV-Cursors/`
- symlink: `~/.local/share/icons/PipBoy-NV-Cursors`
- sources/previews: `extras/cursors-src/` in this repo

## Apply
```bash
vault-os apply
# or:
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s PipBoy-NV-Cursors
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -t int -s 24
```

## Sizes
Each cursor embeds 24, 32, and 48 px frames.

## Animated
- `watch` / `wait` — rotating Pip-Boy ring
- `left_ptr_watch` / `progress` — same spinner

## Config
`CURSOR_THEME` and `CURSOR_SIZE` in `~/.config/fallout-nv/vault-os.conf`

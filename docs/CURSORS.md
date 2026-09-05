# Cursors

Vault.OS ships a 24px (also 32 / 48) X11 cursor set: vault-black fill, phosphor outline. Busy cursors use a short gauge spin — visible only when the system is actually waiting.

## Paths

- Live: `~/.icons/Vault.OS/` (or the cursor theme name set in `vault-os.conf`)
- Sources / rebuild notes: `extras/cursors-src/` when present

## Apply

```bash
vault-os ensure-theme
# or:
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s Vault.OS
xfconf-query -c xsettings -p /Gtk/CursorThemeSize -t int -s 24
```

`CURSOR_THEME` / `CURSOR_SIZE` live in `~/.config/fallout-nv/vault-os.conf`.

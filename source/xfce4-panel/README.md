# Panel, notifications, and launcher

XFCE panel chrome for Vault.OS: top bar, Whisker menu sizing, tasklist LED rail, and clock readout.

## Layout

- Top panel height **28px**, Vault.OS plate art under `~/.local/share/backgrounds/Vault.OS/`
- Whisker menu **320×420**, full opacity (no translucent menu)
- Tasklist active tab is a phosphor LED rail, not a filled highlight
- Clock uses Share Tech Mono; urgent states use rad with a label, not color alone

## Files

| Path | Role |
|------|------|
| `hud.css` | Panel / Whisker / clock styles (imported by the GTK theme) |
| `xfce4-panel.xml` | Reference panel channel (apply carefully on a live session) |
| `whiskermenu-1.rc` | Optional Whisker settings snapshot |

Live theme copies live under `~/.themes/Vault.OS/gtk-3.0/hud.css` (and `gtk-3.20/`). Notifications use `../xfce4-notifyd/`.

## Rules

See root `ERRORS.md` (panel / notify / unlock plate). Do not use web-only CSS properties in GTK themes. Do not force 28px minimum height on tasklist buttons.

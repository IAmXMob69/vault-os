# Panel, notifications, and launcher

XFCE panel chrome for Vault.OS — top bar, Whisker menu, tasklist, and clock.

## Layout

- Top panel is **28px** with plate art under `~/.local/share/backgrounds/Vault.OS/`
- Whisker menu is **320×420** at full opacity
- Active tasklist tabs use a phosphor LED rail instead of a filled highlight
- Clock uses Share Tech Mono; urgent states pair rad with a label, not color alone

## Files

| Path | Role |
|------|------|
| `hud.css` | Panel, Whisker, and clock styles (imported by the GTK theme) |
| `xfce4-panel.xml` | Reference panel channel (apply carefully on a live session) |
| `whiskermenu-1.rc` | Optional Whisker settings snapshot |

Live copies land in `~/.themes/Vault.OS/gtk-3.0/hud.css` (and `gtk-3.20/`). Notification chrome lives under `../xfce4-notifyd/`.

## Notes

Stick to GTK CSS — web-only properties will fail to parse. Keep tasklist button minimum height at 22px so labels are not crushed; chrome controls can stay at 28px.

Top-right session control is a launcher (`launcher-10/session.desktop`) that opens the centered logout plate — not the Actions edge dropdown.

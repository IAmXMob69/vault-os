# Screensaver and lock face

Live idle theme: `screensavers-vaultos-arch-spin`

| Piece | Path |
|-------|------|
| Theme desktop | `/usr/share/applications/screensavers/vaultos-arch-spin.desktop` |
| Wrapper | `/usr/lib/xfce4-screensaver/vaultos-arch-spin` |
| Painter | `~/.local/bin/vaultos-spin-lock` (Gtk.Plug / `$XSCREENSAVER_WINDOW`) |
| Runner | `~/.local/bin/vaultos-spin-lock-run` |

## Behavior

- Idle and lock paint the Arch code mark on vault-black, spinning on the Y axis (`--full`).
- Static only when the GTK theme is `Vault.OS-Reduced`.
- The terminal phosphor dial does not freeze lock or idle spin.
- Desktop homescreen mark is separate: `vaultos-spin-arch --full --instance desktop`.

## System install

Requires root once. See `INSTALL-SYSTEM.md` or run `install-system.sh`.

Exec must stay under `/usr/lib/xfce4-screensaver/…` (stock shape). A home-path Exec resolves to `(null)` in the daemon. Do not override stock floaters under `~/.local/share/applications/screensavers/`.

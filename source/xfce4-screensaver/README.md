# Screensaver and lock

Idle theme id: `screensavers-vaultos-arch-spin`

| Piece | Where it lives |
|-------|----------------|
| Theme desktop | `/usr/share/applications/screensavers/vaultos-arch-spin.desktop` |
| Wrapper | `/usr/lib/xfce4-screensaver/vaultos-arch-spin` |
| Painter | `~/.local/bin/vaultos-spin-lock` (Gtk.Plug / `$XSCREENSAVER_WINDOW`) |
| Runner | `~/.local/bin/vaultos-spin-lock-run` |

## Behavior

Idle and lock draw the Arch mark on vault-black and spin it on the Y axis (`--full`). It goes static only when the GTK theme is `Vault.OS-Reduced`. The terminal phosphor dial does not freeze lock or idle spin.

The homescreen mark is separate: `vaultos-spin-arch --full --instance desktop`.

## System install

Needs root once. See `INSTALL-SYSTEM.md`, or run `install-system.sh`.

Keep the Exec under `/usr/lib/xfce4-screensaver/` — a home-path Exec shows up as `(null)` in the daemon. Leave stock floaters alone under `~/.local/share/applications/screensavers/`.

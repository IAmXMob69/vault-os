# Vault.OS screensaver / lock

## Canonical
- Theme id: `screensavers-vaultos-arch-spin`
- System desktop: `/usr/share/applications/screensavers/vaultos-arch-spin.desktop`
  (local `~/.local/...` alone resolved Exec to null — system path required)
- Runner: `~/.local/bin/vaultos-spin-lock-run` → `vaultos-spin-lock --full`
- Binary: `~/.local/bin/vaultos-spin-lock` (Gtk.Plug + `$XSCREENSAVER_WINDOW`; fullscreen fallback if xid missing/0)

## Behavior
- Lock/idle: **spin** (`--full`). Terminal phosphor dial does **not** freeze lock.
- Static only when `ThemeName=Vault.OS-Reduced` or `--reduced-phosphor`.
- Desktop homescreen: separate `vaultos-spin-arch --full --instance desktop` — do not relaunch with `--reduced-phosphor`.

## Update system desktop (needs sudo)
```
sudo cp ~/Vault.OS/source/xfce4-screensaver/vaultos-arch-spin.desktop /usr/share/applications/screensavers/vaultos-arch-spin.desktop
```

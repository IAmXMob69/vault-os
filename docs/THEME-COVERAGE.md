# Theme coverage

What Vault.OS owns in a normal Arch + XFCE session.

| Layer | Theme / path |
|-------|----------------|
| GTK 2/3 | `themes/Vault.OS` (Reduced: `themes/Vault.OS-Reduced`) |
| Window manager | `themes/Vault.OS/xfwm4` (Reduced doors when `THEME_NAME=Vault.OS-Reduced`) |
| Icons | `icons/Vault.OS` |
| Cursors | `Vault.OS` cursor theme (see [`CURSORS.md`](CURSORS.md)) |
| Notifications | `themes/Vault.OS/xfce-notify-4.0` |
| Panel / HUD | `source/xfce4-panel/`, plates under backgrounds |
| Terminal | CANON phosphor via `vaultos-terminal-phosphor` |
| Lock / screensaver | `screensavers-vaultos-arch-spin` — see `source/lock/SCREENSAVER.md` |
| Qt (Kvantum) | Prefer Vault.OS skin when present; otherwise legacy PipBoy-NV Qt only |

## Operator commands

```bash
vault-os status
vault-os ensure-theme
vault-os doctor
```

System greeter / Plymouth need sudo once — [`BOOT.md`](../BOOT.md), [`SYSTEM-INSTALL.md`](SYSTEM-INSTALL.md).

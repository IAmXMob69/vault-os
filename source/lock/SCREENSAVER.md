# Vault.OS screensaver / lock

## Canon

- Theme id: `screensavers-vaultos-arch-spin`
- System Exec: `/usr/lib/xfce4-screensaver/vaultos-arch-spin` → `vaultos-spin-lock-run` (always `--full` unless GTK theme is Vault.OS-Reduced)
- `LockCommand`: `xfce4-screensaver-command --lock`
- Stock `xfce-floaters` stays stock — do not hijack that slot
- Desktop mark: `vaultos-spin-arch --full --instance desktop` (separate from the saver)

## Install system entry (sudo once)

```bash
sudo ./source/xfce4-screensaver/install-system.sh
```

Until that lands, `ensure-theme` still pins the theme id and keeps slideshow frames at  
`~/.local/share/backgrounds/Vault.OS/lock-spin-frames` as a fallback face.

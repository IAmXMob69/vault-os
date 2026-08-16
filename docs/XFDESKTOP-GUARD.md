# XFDesktop wallpaper guard (Vault-OS 1.4.2)

Keeps xfdesktop alive if it dies. Does **not** rewrite `last-image` when a
valid wallpaper is already set — rewriting it made xfdesktop reload the JPEG
every 30s and the background appeared to change. Slideshows stay off; all
workspaces share workspace 0 (`single-workspace-mode`).

## Layers
1. **systemd user service** `vault-os-xfdesktop.service` — owns xfdesktop, `Restart=always` (1s)
2. **systemd timer** `vault-os-watch.timer` — every 30s runs ensure-desktop + ensure-panel
3. **Autostart** `xfdesktop.desktop` → `vault-os ensure-desktop`
4. **Session** `vault-os session-start` / `apply` / `doctor` call `ensure_xfdesktop`

## Commands
```bash
vault-os ensure-desktop   # start xfdesktop + re-pin wallpaper
vault-os status           # shows xfdesktop running/DEAD
systemctl --user status vault-os-xfdesktop.service
systemctl --user status vault-os-watch.timer
```

## Logs
`~/.config/fallout-nv/xfdesktop.log`

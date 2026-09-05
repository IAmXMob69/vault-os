# Live Arch spin saver (sudo once)

## Root causes (both required)
1. `Hidden=true` on custom saver desktops → Exec `(null)`.
2. A *minimal* `.desktop` (Name/Exec/TryExec only) is often **not** picked up by
   `xfce4-screensaver` theme manager. Use a full desktop (clone floaters metadata,
   swap Exec/TryExec/Name, **delete Hidden**).

## Install
```bash
sudo install -m 644 ~/Vault.OS/source/xfce4-screensaver/vaultos-arch-spin.desktop \
  /usr/share/applications/screensavers/vaultos-arch-spin.desktop
# wrapper already: /usr/lib/xfce4-screensaver/vaultos-arch-spin → vaultos-spin-lock-run
xfconf-query -c xfce4-screensaver -p /saver/themes/list --force-array -t string -s screensavers-vaultos-arch-spin
# ensure-theme saver_want=screensavers-vaultos-arch-spin
killall xfce4-screensaver; xfce4-screensaver &
```

Do **not** leave a local `~/.local/share/applications/screensavers/xfce-floaters.desktop` override.

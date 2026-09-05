# Install real spinning Arch lock (needs sudo once)

System desktop is already at `/usr/share/applications/screensavers/vaultos-arch-spin.desktop`
but it points at a missing binary and is `Hidden=true`.

```bash
sudo tee /usr/lib/xfce4-screensaver/vaultos-arch-spin >/dev/null <<'SH'
#!/bin/bash
exec /home/xmob/.local/bin/vaultos-spin-lock-run "$@"
SH
sudo chmod 755 /usr/lib/xfce4-screensaver/vaultos-arch-spin

sudo tee /usr/share/applications/screensavers/vaultos-arch-spin.desktop >/dev/null <<'DESK'
[Desktop Entry]
Type=Application
Name=Vault.OS Arch Spin
Comment=Y-axis Arch code mark on vault-black
Exec=/usr/lib/xfce4-screensaver/vaultos-arch-spin
TryExec=/usr/lib/xfce4-screensaver/vaultos-arch-spin
Categories=Screensaver;
OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
DESK

xfconf-query -c xfce4-screensaver -p /saver/themes/list --force-array -t string -s screensavers-vaultos-arch-spin
# Then patch vault-os ensure-theme saver_want to screensavers-vaultos-arch-spin
```

Until then: slideshow uses foreshortened spin frames in `~/.local/share/backgrounds/Vault.OS/lock-slides/`.

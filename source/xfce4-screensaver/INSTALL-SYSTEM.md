# Install the Arch spin screensaver

Root once:

```bash
sudo ./source/xfce4-screensaver/install-system.sh
```

Or by hand:

```bash
sudo install -m 755 source/xfce4-screensaver/vaultos-arch-spin.wrapper \
  /usr/lib/xfce4-screensaver/vaultos-arch-spin
sudo install -m 644 source/xfce4-screensaver/vaultos-arch-spin.desktop \
  /usr/share/applications/screensavers/vaultos-arch-spin.desktop
sudo sed -i '/^Hidden=/d' /usr/share/applications/screensavers/vaultos-arch-spin.desktop

xfconf-query -c xfce4-screensaver -p /saver/themes/list \
  --force-array -t string -s screensavers-vaultos-arch-spin
```

Restart `xfce4-screensaver` after installing. Set `LockCommand` to `xfce4-screensaver-command --lock` in the session config.

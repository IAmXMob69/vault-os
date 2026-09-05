# LightDM greeter

Vault.OS login greeter config and CSS. Requires a one-time system install.

## Without root

Session lock uses the XFCE unlock plate (`../lock/lock.css`). Screensaver and lock behavior are documented in `../lock/SCREENSAVER.md`.

## With root (once)

```bash
# from the vault-os checkout
sudo cp source/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf
# Restart LightDM only when ready to end the current session
```

Set `theme-name=Vault.OS` and the Vault.OS wallpaper path in the conf. Greeter CSS rides the Vault.OS GTK theme; `greeter.css` is the craft reference.

# Vault.OS Boot — VDS-01

## Live without root
- Desktop 111 spins via `~/.local/bin/vaultos-spin-111` (autostart)
- Base wallpaper: `~/.local/share/backgrounds/Vault.OS/vault-111-base.png`
- Greeter CSS staged in theme + `~/Vault.OS/source/lightdm/`

## Needs human OK — packages
```
extra/plymouth
```
Optional later: `breeze-plymouth` only if you want a fallback theme.

## Needs human sudo (logout first for greeter restart)
```
# 1) LightDM greeter (login screen)
sudo cp ~/Vault.OS/source/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf

# 2) Plymouth theme
sudo mkdir -p /usr/share/plymouth/themes/Vault.OS
sudo cp -a ~/Vault.OS/source/plymouth/Vault.OS/. /usr/share/plymouth/themes/Vault.OS/
sudo plymouth-set-default-theme -R Vault.OS

# 3) Enable plymouth on boot (edit cmdline once)
# Add: splash quiet to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub
# Then: sudo grub-mkconfig -o /boot/grub/grub.cfg

# Greeter apply ends the session:
# sudo systemctl restart lightdm
```

Do not run step 3 until plymouth package is installed.

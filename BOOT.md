# Vault.OS boot + greeter (staged — needs sudo)

Paths below are relative to this repo checkout (or the same files under a local `Vault.OS` tree if you keep one).

## Live desktop (no sudo)

- Desktop mark: `vaultos-spin-arch --full --instance desktop`
- Base wallpaper: `~/.local/share/backgrounds/Vault.OS/vault-111-base.png`
- Greeter CSS / conf staged in `source/lightdm/`
- Plymouth pack staged in `source/plymouth/Vault.OS/`

## Package

```
extra/plymouth
```

## Needs sudo (logout first before greeter restart)

```bash
# from the repo root
ROOT="$(pwd)"

# 1) LightDM GTK greeter
sudo cp "$ROOT/source/lightdm/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf

# 2) Wallpaper for greeter (matches conf path)
sudo mkdir -p /usr/share/backgrounds/Vault.OS
sudo cp -a "$ROOT/source/wallpapers/vault-111.png" /usr/share/backgrounds/Vault.OS/

# 3) Plymouth theme
sudo mkdir -p /usr/share/plymouth/themes/Vault.OS
sudo cp -a "$ROOT/source/plymouth/Vault.OS/." /usr/share/plymouth/themes/Vault.OS/
sudo plymouth-set-default-theme -R Vault.OS

# 4) Enable plymouth on boot (edit cmdline once — add splash quiet), then:
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 5) Only after you OK a login-cycle:
# sudo systemctl restart lightdm
```

Do **not** run Plymouth steps until `plymouth` is installed.  
Do **not** restart LightDM until you explicitly OK.

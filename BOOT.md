# Vault.OS boot + greeter (staged — needs human sudo)

## Live desktop (already applied, no sudo)
- Desktop mark: Arch silhouette built from code — `~/.local/bin/vaultos-spin-arch` (Y-axis coin spin, click-through, autostart). Vault 111 spinner is **Hidden**/off.
- Base wallpaper: `~/.local/share/backgrounds/Vault.OS/vault-111-base.png`
- Greeter CSS staged in theme + `~/Vault.OS/source/lightdm/`
- Plymouth pack staged at `~/Vault.OS/source/plymouth/Vault.OS/`

## Package
```
extra/plymouth
```
Optional later: `breeze-plymouth` only if you want a fallback theme.

## Needs human sudo (logout first for greeter restart)

```bash
# 1) LightDM GTK greeter
sudo cp ~/Vault.OS/source/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf

# 2) Plymouth theme
sudo mkdir -p /usr/share/plymouth/themes/Vault.OS
sudo cp -a ~/Vault.OS/source/plymouth/Vault.OS/. /usr/share/plymouth/themes/Vault.OS/
sudo plymouth-set-default-theme -R Vault.OS

# 3) Enable plymouth on boot (edit cmdline once — add splash quiet)
# Then:
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 4) Only after you OK a login-cycle:
# sudo systemctl restart lightdm
```

Do **not** run step 3 until `plymouth` is installed.
Do **not** restart LightDM until Blaine explicitly OKs.

## Status (2026-09-04)
- `vault-os` doctor: session ThemeName/icons/wm/cursor/notify/font/wallpaper/panel all Vault.OS OK.
- Plymouth package: **not** installed yet.
- LightDM: still stock conf until step 1.

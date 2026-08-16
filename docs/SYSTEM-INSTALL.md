# Vault-OS system-level theme (needs sudo)

## LightDM greeter + GRUB
```bash
vault-os-install-system-theme
```

## Plymouth (optional, package-dependent)
```bash
sudo pacman -S plymouth
# then install a theme and:
# sudo plymouth-set-default-theme -R details
```

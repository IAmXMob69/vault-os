# Vault.OS

XFCE theme for Arch. Vault-Tec terminal energy — not a green wash over Adwaita.

Phosphor: `#1AFF6B`. Fonts: Share Tech Mono, Overpass Mono, Terminus (or PxPlus IBM VGA8).

## Layout

| Path | What |
|------|------|
| `themes/Vault.OS` | GTK, window borders, notifications |
| `themes/Vault.OS-Reduced` | High contrast / less motion |
| `icons/Vault.OS` | Icons and cursors |
| `source/` | Panel plates, lock, greeter, Plymouth |
| `bin/vault-os` | Install + keep the session on-theme |
| `bin/vaultos-*` | Lock, Arch spin, terminal phosphor |

Design notes live in [`DESIGN.md`](DESIGN.md). Colors are in [`tokens.css`](tokens.css).

## Install

```bash
./bin/vault-os install
vault-os status
```

That drops themes and icons into `~/.themes` / `~/.icons`, plates into `~/.local/share/backgrounds/Vault.OS`, links the helpers in `~/.local/bin`, writes a Vault.OS conf, and runs `ensure-theme`.

Or by hand:

```bash
cp -a themes/Vault.OS themes/Vault.OS-Reduced ~/.themes/
cp -a icons/Vault.OS ~/.icons/
mkdir -p ~/.local/share/backgrounds/Vault.OS ~/.local/bin
cp -a source/wallpapers/. ~/.local/share/backgrounds/Vault.OS/
ln -sfn "$(pwd)/bin/vault-os" ~/.local/bin/vault-os
# same for bin/vaultos-* if you want them on PATH
cp -f config/fallout-nv/vault-os.conf ~/.config/fallout-nv/vault-os.conf
vault-os ensure-theme
```

Set Appearance and Window Manager to **Vault.OS**. For the reduced look, set `THEME_NAME=Vault.OS-Reduced` in `~/.config/fallout-nv/vault-os.conf`.

## Lock and screensaver

Theme: `screensavers-vaultos-arch-spin`.  
Lock command: `xfce4-screensaver-command --lock`.  
Leave stock floaters alone.

One-time sudo so the saver has a real binary:

```bash
sudo ./source/xfce4-screensaver/install-system.sh
```

More detail: [`source/lock/SCREENSAVER.md`](source/lock/SCREENSAVER.md).

## Boot / greeter

Optional. Files are under `source/plymouth/` and `source/lightdm/`. See [`BOOT.md`](BOOT.md). Don’t restart LightDM until you’re ready for a login cycle.

## Fonts

```
extra/otf-overpass
extra/terminus-font
aur/ttf-share-tech-mono
aur/ttf-ultimate-oldschool-pc-font-pack
```

## License

[`LICENSE`](LICENSE).

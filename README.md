# Vault.OS

XFCE desktop theme for Arch. Meant to feel like a recovered Vault-Tec terminal, not a green filter glued on top of Adwaita.

Phosphor is `#1AFF6B`. Typefaces are Share Tech Mono, Overpass Mono, and Terminus (or PxPlus IBM VGA8 if you have it).

## What's in here

- `themes/Vault.OS` — GTK, xfwm4, notifications
- `themes/Vault.OS-Reduced` — high-contrast / reduced motion
- `icons/Vault.OS` — plate icons + cursors
- `source/` — panel, lock, greeter, Plymouth staging
- `bin/vault-os` — install, ensure-theme, status, session glue
- `bin/vaultos-*` — lock, Arch spin mark, terminal phosphor

Design rules: [`DESIGN.md`](DESIGN.md). Tokens: [`tokens.css`](tokens.css). Pitfalls: [`ERRORS.md`](ERRORS.md).

## Install (user session, no sudo)

From a clone of this repo:

```bash
./bin/vault-os install
vault-os status
```

That copies themes, icons, wallpapers/panel plates, and helpers into `~/.themes`, `~/.icons`, `~/.local/share/backgrounds/Vault.OS`, and `~/.local/bin`, seeds `~/.config/fallout-nv/vault-os.conf`, then runs `ensure-theme`.

Manual equivalent if you prefer:

```bash
cp -a themes/Vault.OS themes/Vault.OS-Reduced ~/.themes/
cp -a icons/Vault.OS ~/.icons/
mkdir -p ~/.local/share/backgrounds/Vault.OS ~/.local/bin
cp -a source/wallpapers/. ~/.local/share/backgrounds/Vault.OS/
install -m755 bin/vault-os bin/vaultos-* ~/.local/bin/
cp -f config/fallout-nv/vault-os.conf ~/.config/fallout-nv/vault-os.conf
vault-os ensure-theme
```

Pick **Vault.OS** under Appearance / Window Manager. Reduced mode: set `THEME_NAME=Vault.OS-Reduced` in the conf file above.

## Lock & screensaver

Theme id: `screensavers-vaultos-arch-spin`.  
`LockCommand`: `xfce4-screensaver-command --lock`.  
Stock floaters stay stock.

Optional (sudo once) so the daemon has a real Exec:

```bash
sudo ./source/xfce4-screensaver/install-system.sh
```

That installs `/usr/lib/xfce4-screensaver/vaultos-arch-spin` (wrapper) and the stock-shaped `.desktop`. Until then, idle may use the slideshow frames under `lock-spin-frames`. Details: [`source/lock/SCREENSAVER.md`](source/lock/SCREENSAVER.md).

## Boot / greeter (optional, sudo)

Staged under `source/plymouth/` and `source/lightdm/`. Steps: [`BOOT.md`](BOOT.md). Do not restart LightDM until you're ready.

## Fonts (optional)

```
extra/otf-overpass
extra/terminus-font
aur/ttf-share-tech-mono
aur/ttf-ultimate-oldschool-pc-font-pack
```

## Notes

Open work: [`CONTINUE.md`](CONTINUE.md). License: [`LICENSE`](LICENSE).

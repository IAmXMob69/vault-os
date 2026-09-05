# Vault.OS

XFCE desktop theme for Arch. Meant to feel like a recovered Vault-Tec terminal, not a green filter glued on top of Adwaita.

Phosphor is `#1AFF6B`. Typefaces are Share Tech Mono, Overpass Mono, and Terminus (or PxPlus IBM VGA8 if you have it).

## What's in here

- `themes/Vault.OS` — GTK, xfwm4, notifications
- `themes/Vault.OS-Reduced` — high-contrast / reduced motion
- `icons/Vault.OS` — plate icons
- `source/` — panel, lock, greeter, Plymouth staging
- `bin/vault-os` — `ensure-theme`, `status`, session glue
- `bin/vaultos-*` — lock, Arch spin mark, terminal phosphor

Design rules live in [`DESIGN.md`](DESIGN.md). Color tokens are [`tokens.css`](tokens.css) (and [`tokens-reduced.css`](tokens-reduced.css)). Stuff we've already burned ourselves on is in [`ERRORS.md`](ERRORS.md) — read that before touching lock or screensaver.

## Install

```bash
cp -a themes/Vault.OS ~/.themes/
cp -a themes/Vault.OS-Reduced ~/.themes/
cp -a icons/Vault.OS ~/.icons/

ln -sfn "$(pwd)/bin/vault-os" ~/.local/bin/vault-os

vault-os ensure-theme
vault-os status
```

In Appearance / Window Manager, pick **Vault.OS**. For Reduced mode, set `THEME_NAME=Vault.OS-Reduced` in `~/.config/fallout-nv/vault-os.conf`.

## Lock & screensaver

Uses theme `screensavers-vaultos-arch-spin` with Exec `/usr/lib/xfce4-screensaver/vaultos-arch-spin`. Lock command is just `xfce4-screensaver-command --lock`. Stock floaters stay stock — don't hijack that slot.

More detail: [`source/lock/SCREENSAVER.md`](source/lock/SCREENSAVER.md).

## Boot / greeter

Optional. Staged under `source/plymouth/` and `source/lightdm/`. See [`BOOT.md`](BOOT.md). Don't restart LightDM until you're ready.

## Fonts (optional)

```
extra/otf-overpass
extra/terminus-font
aur/ttf-share-tech-mono
aur/ttf-ultimate-oldschool-pc-font-pack
```

## Notes

Open work: [`CONTINUE.md`](CONTINUE.md). License: [`LICENSE`](LICENSE).

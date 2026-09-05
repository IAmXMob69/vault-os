# Vault.OS

An XFCE desktop theme for Arch Linux that reads as a recovered pre-war Vault-Tec interface — not a green overlay, not a ricing contest.

| | |
|---|---|
| **Environment** | Arch Linux · XFCE 4.18+ |
| **Phosphor** | `#1AFF6B` (hue 141) |
| **Type** | Share Tech Mono · Overpass Mono · Terminus / PxPlus IBM VGA8 |
| **Control plane** | `bin/vault-os` |

## Design law

- [`DESIGN.md`](DESIGN.md) — palette, type, chrome, accessibility
- [`tokens.css`](tokens.css) / [`tokens-reduced.css`](tokens-reduced.css) — single source of color
- [`ERRORS.md`](ERRORS.md) — pitfalls already paid for; read before changing lock, spin, or tokens

## Layout

```
themes/Vault.OS/           GTK 2/3 + xfwm4 + notify
themes/Vault.OS-Reduced/   high-contrast / reduced-effects variant
icons/Vault.OS/            plate + LED icon set
source/                    staged assets (panel, lock, lightdm, plymouth, …)
bin/vault-os               ensure-theme, status, session glue
bin/vaultos-*              lock, spin, phosphor helpers
```

## Install (local)

```bash
# Theme + icons into the user tree
cp -a themes/Vault.OS ~/.themes/
cp -a themes/Vault.OS-Reduced ~/.themes/
cp -a icons/Vault.OS ~/.icons/

# Control plane
install -m755 bin/vault-os ~/.local/bin/vault-os
# or: ln -sfn "$(pwd)/bin/vault-os" ~/.local/bin/vault-os

vault-os ensure-theme
vault-os status
```

Point XFCE Appearance / Window Manager at **Vault.OS**. Reduced mode is conf-opt-in: set `THEME_NAME=Vault.OS-Reduced` in `~/.config/fallout-nv/vault-os.conf`.

## Lock & screensaver

Theme id `screensavers-vaultos-arch-spin` (stock-shaped `.desktop` under `/usr/share/applications/screensavers/`).  
Exec: `/usr/lib/xfce4-screensaver/vaultos-arch-spin` → live Arch code-mark spin on vault-black.  
`LockCommand`: `xfce4-screensaver-command --lock`.

Details: [`source/lock/SCREENSAVER.md`](source/lock/SCREENSAVER.md). Do not invent custom theme ids or home-path `Exec` lines — see `ERRORS.md`.

## Boot / greeter (optional, needs sudo)

Staged under `source/plymouth/` and `source/lightdm/`. Steps: [`BOOT.md`](BOOT.md). Do not restart LightDM without an explicit OK.

## Fonts

Install only with operator approval:

```
extra/otf-overpass
extra/terminus-font
aur/ttf-share-tech-mono
aur/ttf-ultimate-oldschool-pc-font-pack   # PxPlus IBM VGA8
```

## Status

Working board: [`CONTINUE.md`](CONTINUE.md).  
Clunk / drift notes: [`CLUNK.md`](CLUNK.md).

## License

See [`LICENSE`](LICENSE).

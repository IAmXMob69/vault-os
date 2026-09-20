# CONTINUE

## Open — code improvement pass

Improve Arch XFCE / Vault.OS across the stack. Master Coding Bot can pull any lane; specialists still own craft depth.

| Lane | Focus |
|------|--------|
| Design bar / greeter staging | DESIGN.md quality bar; Plymouth/LightDM staged only |
| GTK CANON + Reduced | gtk.css densify; CssProvider clean; HUD overlay only |
| xfwm doors | XPMs/themerc both packs; source ≡ themes |
| Panel / notify / unlock | lock.css contrast; professional whisker sizes |
| Terminal + Arch spin | phosphor dial; no `#33FF6A`; install seeds terminalrc |
| Icons / cursors | vault-dock + cache on install; no Mojave pins |
| Control plane | `vault-os` install / ensure-theme / status / doctor |

## Open — human sudo later

- Greeter system files are installed (`/usr/share/themes|icons|backgrounds/Vault.OS` + lightdm-gtk-greeter.conf). **Do not** `systemctl restart lightdm` until you want to end the session — next logout shows it.
- Plymouth still staged only — package not installed; see [`BOOT.md`](BOOT.md).
- Optional fonts system-wide beyond Share Tech Mono for greeter.

## Landed

- `vault-os` 1.5.17 — install path + greeter system installer targets Vault.OS
- CANON + Reduced themes, icons, tokens, `screensavers-vaultos-arch-spin`
- Public README without `ERRORS.md` on the front door
- Door themerc hexes on tokens (`#1AFF6B` / Reduced `#66FF9C`)

See [`DESIGN.md`](DESIGN.md).

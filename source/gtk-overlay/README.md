# GTK user overlay

Target: `~/.config/gtk-3.0/gtk.css`

## Law
- Import **only** Vault.OS `hud.css` (or the Reduced tree’s hud when ThemeName is Vault.OS-Reduced).
- Do **not** import PipBoy-NV CSS, FNV panel skins, or absolute theme paths that point at PipBoy.
- Do **not** put Thunar spinner / black-square rules here (VDS): lasting home is theme `gtk-3.0`/`gtk-3.20` `gtk.css`. No fighting user override.
- `vault-os ensure-theme` / `vaultos-lock` write HUD `@import` only. Allowlist ThemeName: `Vault.OS|Vault.OS-Reduced`.

## Check
```
rg -n 'PipBoy|33FF6A|44FF3D' ~/.config/gtk-3.0/gtk.css ~/.themes/Vault.OS/gtk-3.0/gtk.css ~/.themes/Vault.OS/gtk-3.20/gtk.css
```
Expect: no matches (comments mentioning PipBoy OK).

## GTK4 overlay

Target: `~/.config/gtk-4.0/gtk.css` (+ `settings.ini`)

- Source: `~/Vault.OS/source/gtk-overlay/gtk4.css`
- CANON phosphor `#1AFF6B` only. Never PipBoy `#33FF6A`.
- Dense menus (20px), recessed entries, stamped buttons, AAA selected (`#121612` / `#1AFF6B`).
- `ensure-theme` should copy gtk4.css + settings.ini.gtk4 → `~/.config/gtk-4.0/`.

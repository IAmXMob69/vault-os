# GTK user overlay

User CSS that rides on top of the active Vault.OS GTK theme.

## GTK 3

Installed path: `~/.config/gtk-3.0/gtk.css`

This file should only `@import` the theme’s `hud.css` (Vault.OS or Vault.OS-Reduced, matching `ThemeName`). Do not pull in legacy theme CSS, Fallout panel skins, or absolute paths outside the active Vault.OS theme tree.

Thunar idle-spinner / menubar plate rules belong in the theme’s `gtk-3.0` / `gtk-3.20` `gtk.css`, not here. `vault-os ensure-theme` rewrites this overlay as a HUD import only. Allowed theme names: `Vault.OS`, `Vault.OS-Reduced`.

Quick drift check (expect no matches outside intentional comments):

```
rg -n '33FF6A|44FF3D|PipBoy' ~/.config/gtk-3.0/gtk.css ~/.themes/Vault.OS/gtk-3.0/gtk.css ~/.themes/Vault.OS/gtk-3.20/gtk.css
```

## GTK 4

Installed path: `~/.config/gtk-4.0/gtk.css` (and `settings.ini`)

Source: `source/gtk-overlay/gtk4.css`. Phosphor is CANON `#1AFF6B`. Dense menus, recessed entries, stamped buttons, selected text `#1AFF6B` on `#121612`. `ensure-theme` copies `gtk4.css` and `settings.ini.gtk4` into `~/.config/gtk-4.0/`.

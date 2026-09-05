# GTK user overlay

Extra CSS that sits on top of the active Vault.OS GTK theme.

## GTK 3

Path: `~/.config/gtk-3.0/gtk.css`

Import only the theme’s `hud.css` for whichever theme is active (`Vault.OS` or `Vault.OS-Reduced`). Don’t point this file at other theme trees.

Spinner and menubar rules stay in the theme’s own `gtk-3.0` / `gtk-3.20` `gtk.css`. `vault-os ensure-theme` rewrites this overlay as a HUD import only.

## GTK 4

Path: `~/.config/gtk-4.0/gtk.css` (plus `settings.ini`)

Source file: `gtk4.css` in this folder. Phosphor green is `#1AFF6B`. `ensure-theme` copies it into `~/.config/gtk-4.0/`.

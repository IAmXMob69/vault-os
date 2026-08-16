# Vault-OS 1.4 / PipBoy-NV upgrades

## Fixed bugs
- **vault-os.conf** still pointed at deleted wallpapers (mojave/desktop) — would re-break backdrop on login
- **ensure-panel** forced solid color panels (style 1), wiping textured CRT panels
- **Share Tech Mono** was configured but not installed → silent fallback mess
- **Flatpak ICON_THEME** was PipBoy-NV (wrong pack); now FalloutMojave
- **Cursor theme** was empty in xsettings

## New / improved
- Share Tech Mono installed under `~/.local/share/fonts/ShareTechMono/`
- Custom **xfce-notify-4.0** PipBoy-NV toast theme
- Cursor Adwaita 24 + applied via vault-os
- Qt5ct/Qt6ct icon+font sync; `QT_QPA_PLATFORMTHEME=qt5ct`
- Flatpak theme/icon/filesystem overrides
- Desktop icon labels CRT green (persisted in apply)
- Workspaces enforced: STAT / DATA / ITEM / MAP
- Panel images style=2, sizes 28/44, icon 16/32
- Shell aliases: `vault-os`, `vault-status`, `vault-doctor`
- Status reports wallpaper, cursor, notify, font health

## Commands
```
vault-os status
vault-os apply
vault-os doctor
```

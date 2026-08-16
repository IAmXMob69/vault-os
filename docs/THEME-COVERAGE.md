# Vault-OS Theme Integration Coverage

## Applied (user session)

| Area | Implementation |
|------|----------------|
| GTK 2/3/4 | PipBoy-NV |
| Icons | FalloutMojave (~10k) |
| WM | PipBoy-NV xfwm4 |
| Cursors | PipBoy-NV-Cursors |
| Notifications | PipBoy-NV |
| Panels | Neon dock + map/trash |
| Qt5/Qt6 | Kvantum **PipBoy-NV** via qt5ct/qt6ct |
| Sounds | PipBoy-NV beep pack |
| VS Code OSS | Pip-Boy color customizations |
| Firefox | userChrome.css + user.js (profile vault-os.default) |
| Discord | CSS theme file (enable in Vencord/BetterDiscord) |
| Chromium | Pip-Boy theme extension + flags |
| Flatpak | GTK/icon/cursor/Qt env overrides |
| Thunar | Vault-style bookmarks |
| Lock | `vault-os-lock` helper |
| Guards | vault-os ensure-theme/coverage on login + 30s watch |

## Needs sudo once

```bash
vault-os-install-system-theme
```

- LightDM greeter → PipBoy-NV + Mojave wallpaper
- System-wide theme/icon install for greeter
- Optional GRUB background

## Discord

1. Install Vencord or BetterDiscord
2. Enable theme: `~/.config/Vencord/themes/PipBoyNV.theme.css`
   or `~/.config/BetterDiscord/themes/PipBoyNV.theme.css`

## Commands

```bash
vault-os coverage          # report
vault-os ensure-coverage   # re-apply Qt/sounds/flatpak/chromium
vault-os doctor            # full repair
vault-os-install-system-theme  # LightDM/GRUB (sudo)
```

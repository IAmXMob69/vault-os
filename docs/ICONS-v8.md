# FalloutMojave v8 — Full app coverage

Professional CRT medallion icons for **every** installed desktop app.

## Style
Matches the original FalloutMojave pack you installed:
- Circular beveled badge (dark CRT disk + phosphor rim)
- Green monochrome art (Papirus silhouettes → phosphor, or FNV game art)
- Sizes: 16, 22, 24, 32, 48, 64, 128, 256

## Coverage
- **124/124** visible apps themed (0 missing)
- ~58 newly generated badges
- ~44 smart aliases to existing pack icons
- Special: Claude, Grok, X, Fallout NV (vault-boy art), HP Device Manager

## Locations
- `~/.local/share/icons/FalloutMojave/`
- `~/.icons/PipBoy-NV/` (mirror)
- Desktop overrides: `~/.local/share/applications/` (HP absolute-path icons)

## Reload
```bash
xfconf-query -c xsettings -p /Net/IconThemeName -s FalloutMojave
gtk-update-icon-cache -f -t ~/.local/share/icons/FalloutMojave
```

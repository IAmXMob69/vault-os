# PipBoy-NV Icons — Real Fallout: New Vegas Assets

Icons are **extracted from your installed FNV game BSAs**, then phosphorized
(green CRT tint + glow) to match the Pip-Boy 3000 display shader.

## Source
- `Fallout - Textures2.bsa` / `Fallout - Textures.bsa`
- Paths under `textures/interface/icons/...`
- ~1,500 DDS decoded → PNG masters in `~/Themes/fallout-nv/game-icons-png/`

## Theme
- Install path: `~/.icons/PipBoy-NV`
- ~4,500 PNG files (multi-size)
- Inherits Papirus-Dark for anything not remapped

## Desktop mappings (examples)
| Desktop icon | Game asset |
|--------------|------------|
| Start menu | Vault Boy (neutral) |
| Home | Vault Boy (Goodsprings) |
| Folder / Files | Hotkey books type-icon |
| Downloads | Gift box message icon |
| Music | Guitar item |
| Pictures | Film roll |
| Trash | Junk item |
| Terminal / Code | Science skill |
| Browser | World map message icon |
| Chat (Discord/Telegram) | Radio tower |
| Password manager | Padlock |
| Games | Small Guns skill |

## Extra icons
All inventory/weapons/perks/SPECIAL/message icons are also installed as:
`fnv-<name>` under apps (sizes 32–128).

Example: `fnv-message-vaultboy-ncr`, `fnv-weapons-9mm-pistol`, `fnv-special-strength`

## Rebuild
Extract + convert + map scripts live in session history; masters cached under
`~/Themes/fallout-nv/game-icons-png/`.

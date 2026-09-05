# Terminal theme

xfce4-terminal colors and optional CRT layers for Vault.OS.

## Install

```bash
mkdir -p ~/.config/xfce4/terminal
cp source/xfce4-terminal/terminalrc ~/.config/xfce4/terminal/terminalrc
cp source/xfce4-terminal/Vault.OS.theme ~/.local/share/xfce4/terminal/colorschemes/
# optional: install vaultos-terminal-phosphor to ~/.local/bin
```

Reopen Terminal after changing modes so VTE CSS reloads.

## Phosphor modes

| Mode | Effect |
|------|--------|
| `reduced` (default) | Solid well, no scanlines/bloom |
| `clear` | Sharp phosphor only |
| `full` | Scanline tile + bloom |

```bash
vaultos-terminal-phosphor reduced|clear|full|status
```

State file: `~/.config/Vault.OS/terminal-phosphor`

## Palette

Foreground `#1AFF6B`, background `#070807`. ANSI 0–15 come from `tokens.css` only (cyan is phosphor; magenta is rad-red). Do not invent greens.

## Related

Desktop Arch mark and lock/saver spin are separate from this dial. See `source/xfce4-screensaver/`.

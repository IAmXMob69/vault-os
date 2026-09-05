# Terminal

xfce4-terminal colors for Vault.OS, plus an optional CRT layer if you want it.

## Install

```bash
mkdir -p ~/.config/xfce4/terminal
cp source/xfce4-terminal/terminalrc ~/.config/xfce4/terminal/terminalrc
cp source/xfce4-terminal/Vault.OS.theme ~/.local/share/xfce4/terminal/colorschemes/
```

Optional dial: put `vaultos-terminal-phosphor` on your `PATH` (`~/.local/bin` is fine). Reopen Terminal after switching modes so VTE picks up the CSS.

## Phosphor modes

| Mode | What you get |
|------|----------------|
| `reduced` (default) | Solid well, no scanlines or bloom |
| `clear` | Sharp phosphor, nothing else |
| `full` | Scanline tile + light bloom |

```bash
vaultos-terminal-phosphor reduced|clear|full|status
```

Mode is stored at `~/.config/Vault.OS/terminal-phosphor`.

## Colors

Foreground `#1AFF6B`, background `#070807`. The ANSI 0–15 map comes from `tokens.css` — cyan is phosphor, magenta is rad-red. Stick to that palette.

## Related

The desktop Arch mark and the lock/saver spin are separate. See `source/xfce4-screensaver/`.

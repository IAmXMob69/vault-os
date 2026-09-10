# Vault.OS xfwm4

XFCE window decorations for Vault.OS.

- Titlebar height 28px; buttons 22×22 so the phosphor rail under the title still shows
- All three latches share the same stamped plate (bevel-hi in, bevel-lo out)
- Glyphs: thin centered dash / square / X. The titlebar rail is the active cue, not a blob on the button
- Close at rest: inset plate, rad X + rad rail. Hover: rad fill, white X
- Inactive: steel glyph, no rail
- Pixel colors are `#RRGGBB` plus an xfwm symbolic name
- Regenerate with `python3 source/xfwm4/gen_buttons.py`

Install by copying this directory to `~/.themes/Vault.OS/xfwm4/` and setting the xfwm4 theme to `Vault.OS`.

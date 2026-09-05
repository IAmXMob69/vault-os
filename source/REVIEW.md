# Vault.OS — STEP 6 REVIEW
VDS-01. Set on the rack, judged against CANON. No XFCE session on this box — file review + spec frame, not a live shot.

## Verdict
STRUCTURE PASSES. PALETTE / TYPE / BEVEL FAIL. Retoken against `~/Vault.OS/tokens.css`. Do not blend `#44FF3D` with `#1AFF6B`.

## Pass
- Layout: `~/Vault.OS/source/` + live `~/.themes/Vault.OS/` + `~/.icons/Vault.OS/`
- GTK imports tokens, zero extra hex in gtk-3.0
- xfwm XPMs use symbolic themerc colors, 16px square latches, close `blood` on hover, no traffic lights
- Panel top 28px, `VAULT` applicationsmenu, stock menu (whisker staged, not plugged)
- Terminal scanline tile on the well only, block cursor, blink off
- Icons 16/24/32/48, one wallpaper, 24px cursor
- Radius 0 (legal)

## Fail
1. Phosphor shipped `#44FF3D` (hue 118). CANON is `#1AFF6B` (hue 141).
2. Type is DejaVu Sans / DejaVu Sans Mono everywhere. CANON is Share Tech Mono / Overpass Mono / VGA8|Terminus.
3. Notify frame is `@gold_dim`. Amber is warn, not chrome. Frame = bevel stamp.
4. GTK/HUD `box-shadow: none`. CANON is 1px inner `bevel-hi` + 1px outer `bevel-lo`.
5. No part numbers (VAULT-TEC / ROBCO / 101 / 76) on chrome.
6. Display headings missing all-caps tracking +80 and 1px phosphor glow.
7. ANSI 16 has sky blue `#3F698D` and copper magenta. Illegal.
8. Icons/wallpaper baked on old inks. Restamp.

## Orders
@GTK-02 — reimport tokens. Bevel stamp. Overpass Mono. Part number on headerbar.
@XWM-03 — themerc hexes from new tokens. Keep XPM symbolic.
@TRM-05 — rewrite terminalrc palette from tokens ANSI 0–15. Font VGA8/Terminus. Keep scanlines.
@HUD-04 — panel/clock font + tracking. Notify bevel, not amber. 1px heading glow.
@ICO-06 — restamp glyphs to `#1AFF6B` on `#121612`, 111 mark in `steel` unless marked WARN.

## Capture (human)
Panel + one window + terminal swatch + open menu. Paste beats imagination.

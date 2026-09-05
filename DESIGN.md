# Vault.OS — DESIGN.md
**VDS-01. CANON. Human screenshots beat this file.**

Arch Linux. XFCE 4.18+ (xfwm4, xfce4-panel, xfce4-terminal).
Vault-Tec industrial + Pip-Boy HUD + phosphor CRT. Not generic green hacker. Not modern flat.

## Palette (do not drift)

| Token | Hex | Use |
|---|---|---|
| `phosphor-primary` | `#1AFF6B` | Live text, LED, glyph ink |
| `phosphor-dim` | `#0E8A3A` | Selected fill, idle LED |
| `phosphor-ghost` | `#06381A` | Ghost fill, deep well tint |
| `amber-warn` | `#FFB000` | Warn only. Not chrome. |
| `rad-red` | `#C41E3A` | Destroy, close hover, urgent |
| `steel` | `#8A8F86` | Dead text, cold glyph |
| `vault-black` | `#070807` | Terminal well, deepest |
| `panel-black` | `#0C0F0C` | Panel, window chassis |
| `inset` | `#121612` | Recessed controls, plates |
| `bevel-hi` | `#2A332A` | 1px inner highlight, seams |
| `bevel-lo` | `#050605` | 1px outer shadow |

Hue **141°**. Every green is a lightness stop of that hue. Cyan in the ANSI map is phosphor. Magenta is rad-red. No sky blue. No copper. No gold-as-chrome.

Derived only: `phos-hot` `#66FF9C`, `phos-white` `#D4EDDD`, `steel-500` `#60665C`, `ansi-15` `#C7C9C5`.

## Type

- UI chrome: Share Tech Mono / Overpass Mono
- Terminal: "PxPlus IBM VGA8" or Terminus, fallback Share Tech Mono
- Display headings: all-caps, tracking +80, 1px phosphor glow
- Never Inter, Roboto, Segoe, or rounded friendly fonts
- Do not install fonts until human OKs the package list in README.md

## Chrome

- 1px inner highlight (`bevel-hi`), 1px outer shadow (`bevel-lo`). Fake thickness, not blur.
- Corners 0–2px. Windows 0. Stamped buttons may use 2px. No iOS pills.
- Buttons: stamped metal + green LED, not Material.
- Scanlines only in terminal / lock / splash. Not on GTK widgets.
- Every surface carries a part number: VAULT-TEC / ROBCO / 101 / 76.

## Per-bot

**GTK-02** — `~/.themes/Vault.OS/gtk-2.0|gtk-3.0|gtk-3.20/`
Import `~/Vault.OS/source/tokens.css`. Map widgets to aliases. Stamp bevel on plates. Font Overpass Mono 9pt. Headerbar 24px `panel-black`. Part number `VAULT-TEC` on header.

**XWM-03** — `~/.themes/Vault.OS/xfwm4/`
24px lintel `panel-black`. 1px jamb `bevel-hi` inside, `bevel-lo` outside. 16px square latches. Close hover `rad-red`. Active title `phosphor-primary`. Inactive `steel`. No traffic lights.

**TRM-05** — `~/.config/xfce4/terminal/terminalrc`
Well `ansi-0`. Beam `ansi-10`. Block cursor `phosphor-primary`, blink off. Palette = ANSI 0–15 in tokens.css. Scanline tile on the well. Font VGA8/Terminus.

**HUD-04** — panel / notify / launcher
Panel top 28px `panel-black`, bevel seam, `VAULT` applicationsmenu. Clock mono phosphor, tracking +80 on the heading. Notify 280×80 `panel-black` plate, bevel frame (not amber). Urgent `rad-red`. Quiet `steel`.

**ICO-06** — `~/.icons/Vault.OS/`
16/24/32/48. Glyph `phosphor-primary` on `inset` plate. 1px `bevel-hi` / `bevel-lo`. Cursor 24px `vault-black` fill, phosphor outline. One wallpaper: `vault-black`, 8px phosphor grid at 8%, Vault 111 in `steel` (amber only if marked WARN).

## Paths

- Source of truth: `~/Vault.OS/tokens.css` `~/Vault.OS/DESIGN.md` `~/Vault.OS/screenshots/`
- Working source: `~/Vault.OS/source/`
- Live theme: `~/.themes/Vault.OS/`
- Live icons: `~/.icons/Vault.OS/`
- Overlay: `~/.config/gtk-3.0/gtk.css`
- Terminal: `~/.config/xfce4/terminal/terminalrc`
- Panel: `~/.config/xfce4/panel/` + `~/.config/xfce4/xfconf/xfce-perchannel-xml/`

## Collision

Two bots on one pixel: VDS-01 calls it in one line. Do not blend.

## Screenshot spec

One frame, four things visible:

1. Top panel — `VAULT` launcher, one status, clock
2. One focused GTK window — titlebar latches, part number
3. Terminal — `ls` plus `for i in {0..15}; do tput setaf $i; echo -n "$i "; done`
4. Open app menu, one row selected

Human paste wins. Spec mock: `~/Vault.OS/screenshots/spec-frame.png`

## Forbidden

Freelance greens. Blur soup. Material pills. Scanlines on GTK. Amber used as chrome. Sky-blue ANSI. Inter/Roboto/Segoe. New packages without a listed wait.

## Pitfalls
Living do-not-repeat log: `ERRORS.md`.

## Accessibility (CANON)
Team baseline with Accessability Bot. Craft still Vault-Tec; usable with keyboard, low vision, CRT down/off.

### Contrast (on `#070807`)
| Pair | Ratio | Grade | Use |
|---|---|---|---|
| phosphor `#1AFF6B` | 14.86 | AAA | Primary text/chrome |
| phos_hot `#66FF9C` | 15.62 | AAA | Emphasis |
| steel `#8A8F86` | 6.07 | AA | Meta/labels — not long body |
| phosphor_dim `#0E8A3A` | 4.50 | AA | LED/fill only — not body |
| rad_red `#C41E3A` | 3.43 | AA-large | Status with icon/label — never small text alone |
| text_secondary `#B7BEB4` | 10.54 | AAA | Secondary body |

### Focus
2px `phosphor_primary` ring or LED rail. Never glow-only. Hit targets 24–44px (panel/header 28).

### Status
amber/rad never sole cue — pair with icon, label, or shape.

### Selection
`theme_selected_bg` = `inset` `#121612`, `theme_selected_fg` = `phosphor_primary` `#1AFF6B` (~13.5 AAA). Always pair with LED rail. Never phosphor_dim + phos_hot (~3.5 FAIL).

### Reduced phosphor
First-class file: `tokens-reduced.css` (clearer body, lifted rad, effects off).
Import instead of `tokens.css` for reduced/clear-terminal mode.
Spin/bloom/scanlines: opt-in; reduced mode sets them off.

# Vault.OS — ERRORS / pitfalls log

Living list of mistakes we already made. Read before changing theme, lock, spin, or a11y tokens.
Owners: whole team. Accessability Bot maintains a11y + lock/spin; Genius owns control-plane / session entries. Lock detail also linked from `source/lock/`.

---

## Lock / screensaver / Arch spin

### DO NOT override `xfce-floaters.desktop` in `~/.local/share/applications/screensavers/`
- **Symptom:** xfce4-screensaver debug shows `Setting command: '(null) -n 5'` / `Failed to execute child process "(null)"`.
- **Why:** User overrides of stock screensaver `.desktop` files often fail to resolve `Exec`; xfconf floaters args still append (`-n 5`).
- **Do instead:** Idle → stock `screensavers-xfce-personal-slideshow` pointed at `~/.local/share/backgrounds/Vault.OS/lock-spin-frames/`. Live spin on lock → `LockCommand` = `~/.local/bin/vaultos-session-lock`.
- **Later (needs sudo):** Unhide system `vaultos-arch-spin.desktop` under `/usr/share/applications/screensavers/` for true live idle Gtk.Plug spin.
- **Refs:** `source/lock/SCREENSAVER.md`

### DO NOT use SessionManager / `xflock4` as the only lock path if it hangs
- **Symptom:** Top-left/right lock buttons and Super+L appear dead; xflock4 dbus-calls `org.xfce.Session.Manager.Lock`, which can hang.
- **Do instead:** `vaultos-session-lock` or `xfce4-screensaver-command --lock`. Never point Super+L / panel lock at bare `xflock4`.
- **Wire:** `xfconf-query -c xfce4-session -p /general/LockCommand` → `~/.local/bin/vaultos-session-lock`
- **Logged:** 2026-09-05 Genius / VDS-01

### DO NOT let terminal phosphor dial freeze desktop or lock spin
- Terminal CRT: `vaultos-terminal-phosphor` (default `reduced`) — **only** the terminal.
- Desktop Arch: always `vaultos-spin-arch --full --instance desktop`.
- Lock/saver: `vaultos-spin-lock-run` → `--full` unless ThemeName is `Vault.OS-Reduced`.
- **Never** relaunch desktop instance with `--reduced-phosphor` “to match CRT.”

### DO NOT put a custom theme id in `/saver/themes/list` that the daemon cannot resolve
- Bad: `screensavers-vaultos-arch-spin` or a full path under `/usr/share/...` when the file is Missing/Hidden.
- Good (no root): `screensavers-xfce-personal-slideshow` + frame folder.
- Debug: run `xfce4-screensaver --debug` and grep `Setting command` / `Could not find information for theme`.

---


### DO NOT point screensaver Exec at `~/.local/bin/...` — use `/usr/lib/xfce4-screensaver/<name>` wrapper
- **Symptom:** Theme id resolves, Gio `new_from_filename` sees Exec, but activate still logs `Setting command: '(null)'`.
- **Why:** xfce4-screensaver theme/job path matches stock pattern (`/usr/lib/xfce4-screensaver/slideshow` etc.). Home-path Exec + args often fail theme-manager command resolution even when the `.desktop` file is valid.
- **Do instead:** `Exec=/usr/lib/xfce4-screensaver/vaultos-arch-spin` (thin wrapper → `vaultos-spin-lock-run --full`). No `Hidden=true` on the system desktop we care about listing. Stage: `~/Vault.OS/source/xfce4-screensaver/install-system.sh`.
- **Logged:** 2026-09-05 TRM-05 / Genius

### DO NOT leave `Hidden=true` on `/usr/share/applications/screensavers/vaultos-arch-spin.desktop`
- **Symptom:** `Setting command: '(null)'` even though wrapper `/usr/lib/xfce4-screensaver/vaultos-arch-spin` exists and points at `vaultos-spin-lock-run`.
- **Why:** xfce4-screensaver skips Hidden desktops → null Exec → black lock grab.
- **Do instead (sudo once):** `sudo sed -i '/^Hidden=/d' /usr/share/applications/screensavers/vaultos-arch-spin.desktop` then pin `screensavers-vaultos-arch-spin`. Until then keep slideshow + `lock-spin-frames`.
- **Logged:** 2026-09-05 VDS-01 / Genius

---


### DO NOT set `/general/LockCommand` to `xflock4`
- **Symptom:** Super+L / panel lock no-ops or hangs (xflock4 → SessionManager.Lock → LockCommand → xflock4).
- **Do instead:** `vaultos-session-lock` or `xfce4-screensaver-command --lock`.
- **Logged:** 2026-09-05 VDS-01

---


### DO NOT leave saver/lock active after remote tests
- **Symptom:** Session stuck on lock dialog after agent testing.
- **Do instead:** Always `xfce4-screensaver-command --deactivate` and reap `vaultos-spin-lock` after activate/lock tests. Do not leave a `--debug` screensaver daemon as the long-running session instance.
- **Logged:** 2026-09-05 Genius

### DO NOT write `~/.local/bin` scripts via `cp /dev/stdin`
- **Symptom:** Scripts become `~/.local/bin/foo -> /proc/self/fd/0` and die.
- **Do instead:** Heredoc to a real file (`cat > path <<'EOF'`).
- **Logged:** 2026-09-05 Genius

---


### DO NOT expect a *new* theme id under `/usr/share/.../screensavers/` to resolve Exec
- **Symptom:** Even with `Hidden=` removed, `screensavers-vaultos-arch-spin` still → `Setting command: '(null)'`.
- **Why:** xfce4-screensaver only reliably resolves the **stock** theme ids (`xfce-floaters`, `xfce-personal-slideshow`, `xfce-popsquares`).
- **Do instead (works):** Hijack **stock** `xfce-floaters.desktop` `Exec=` → `/usr/lib/xfce4-screensaver/vaultos-arch-spin` (wrapper → `vaultos-spin-lock-run --full`). Keep stock backup as `xfce-floaters.desktop.vaultos-stock`. Pin `/saver/themes/list` = `screensavers-xfce-floaters`.
- **Still DO NOT** override floaters only under `~/.local/share/applications/screensavers/` (user-local override → null).
- **Logged:** 2026-09-05 Genius / VDS-01

---


### Custom screensaver theme ids need *full stock metadata*, not a minimal .desktop
- **Symptom:** Minimal `vaultos-arch-spin.desktop` (even unhidden, correct Exec under `/usr/lib/...`) → `(null)`.
- **Do instead:** Clone stock floaters `.desktop` metadata; change `Name=` / `Exec=` / `TryExec=` to Vault.OS wrapper. Pin `screensavers-vaultos-arch-spin`. Home-path Exec still fails — keep `/usr/lib/xfce4-screensaver/vaultos-arch-spin`.
- **Working (2026-09-05):** theme `screensavers-vaultos-arch-spin` → spawns `vaultos-spin-lock --full`. Stock floaters restored (no permanent hijack).
- **Logged:** Genius / VDS-01

---

## Accessibility / tokens / themes

### DO NOT use selected fg/bg as phosphor_dim + phos_hot (or ghost + phos_hot)
- **Contrast:** ~3.5:1 or worse (AA-large only / FAIL for body).
- **Rule:** `@theme_selected_bg_color` = `@inset` (`#121612`); `@theme_selected_fg_color` = `@phosphor_primary` (`#1AFF6B` CANON / hotter in Reduced).
- Hover may use ghost; **`:selected` / `:checked` must not.**
- Live CANON once shipped dim+hot — fixed 2026-09-04; DESIGN.md documents the rule.

### DO NOT put `:root { --glow… }` custom properties in **theme-local** `gtk-*/tokens.css`
- **Symptom:** Gtk CssProvider fails / theme fails to load.
- **Do:** GTK-safe `@define-color` only in `~/.themes/Vault.OS*/gtk-*/tokens.css`. Masters `~/Vault.OS/tokens*.css` may keep `:root` hooks for craft/overlays.

### DO NOT hardcode `@phosphor_ghost` on `:selected` when tokens already define `theme_selected_*`
- Token-only fixes won’t paint if gtk.css hardcodes ghost. Use `@theme_selected_bg_color` / `@theme_selected_fg_color`.

### DO NOT treat `Vault.OS-Reduced` as “set ThemeName in Settings and walk away”
- Control plane is **conf-opt-in**: `THEME_NAME` in `~/.config/fallout-nv/vault-os.conf`.
- `ensure-theme` / watch reassert conf; manual Reduced without conf gets wiped.
- Notify theme stays **Vault.OS** (Reduced has no `xfce-notify-4.0`).

### DO NOT use amber/rad as the only status cue
- Pair with shape/label/LED rail (close latch stop-octagon + X; emblem-important bang triangle; destructive LED rail).

### DO NOT require bloom/scanlines/spin to read UI
- CRT effects optional; Reduced / clear-terminal paths exist. Desktop/lock spin is operator preference via `--full`, separate from CRT dial.

---


### DO NOT leave idle Thunar/menubar spinner visible (and don’t fix only gtk-3.0 or opacity-only)
- **Symptom:** Persistent grey loading circle in Thunar menubar when nothing is loading — reads broken, not Vault-Tec.
- **Why:** Thunar packs `GtkSpinner` always-visible; GTK 3.24 loads `gtk-3.20/gtk.css` first. Opacity-only + always-on `-gtk-icon-source: process-working` can still paint. Lasting home is theme `gtk-3.0`/`gtk-3.20` only. Do **not** re-add a fighting spinner override in `~/.config/gtk-3.0/gtk.css` (HUD `@import` only; VDS 2026-09-05).
- **Do instead:** Lasting fix in CANON + Reduced `gtk-3.0` **and** `gtk-3.20` (live + source): idle = opacity 0, `-gtk-icon-source: none`, `-gtk-icon-transform: scale(0)`; busy = quiet phosphor on `spinner:checked` / `.active` (incl. `:disabled:checked` for Thunar’s insensitive menuitem).
- **Owner:** GTK-02. **Logged:** 2026-09-05 VDS-01 / GTK-02


### DO NOT `opacity: 0` the Thunar spinner host menuitem
- **Symptom:** Idle plate gone, but busy phosphor also invisible (parent opacity multiplies child).
- **Why:** Thunar binds loading/searching → `GtkSpinner:active` (:checked) while host stays insensitive.
- **Do instead:** Transparent host (never solid `vault_black`); collapse idle spinner allocation with `margin: 0 -20px 0 0` + `scale(0)` / icon none; restore margin + phosphor on `spinner:disabled:checked`. Overlay stays HUD-only.
- **Logged:** 2026-09-05 GTK-02

### DO NOT give `menuitem:disabled` a solid `vault_black` background
- **Symptom:** Permanent black square in Thunar menubar next to Help/search (idle GtkSpinner host).
- **Why:** Thunar packs spinner in an insensitive right-justified menuitem; `menuitem:disabled { background-color: @vault_black }` paints that chrome even when the spinner glyph is hidden.
- **Do instead:** `menuitem:disabled` background transparent; collapse `menubar > menuitem:disabled` (+ `.thunar`/`:last-child`) in theme `gtk-3.0`/`gtk-3.20`. No lasting spinner half in `~/.config/gtk-3.0/gtk.css`.
- **Owner:** GTK-02. **Logged:** 2026-09-05

### DO NOT use `text-transform`, `:before`/`:after`, or `-GtkNotebook-*` in theme gtk.css
- **Symptom:** Gtk CssProvider parse warnings / load failures (`'text-transform' is not a valid property name`, unknown pseudo, deprecated GtkNotebook props).
- **Do instead:** Drop them. Use real selectors + box-shadow LED rails. No CSS2.1 web-only chrome in GTK themes.
- **Logged:** 2026-09-04 GTK-02 error-scrub

### DO NOT leave a trailing comma after a comment inside a CSS value list (esp. `terminal.css`)
- **Symptom:** `terminal.css:N:0'' is not a valid color name` — CssProvider treats the empty token as a color.
- **Do instead:** Comment outside the declaration; never `color: @phos, /* note */` style trails.
- **Logged:** 2026-09-04 GTK-02 (Vault.OS-Reduced terminal.css)

### DO NOT leave PipBoy `#33FF6A` / `#070C09` metrics in `~/.config/gtk-4.0/gtk.css`
- **Symptom:** GTK4 apps (VTE, Adwaita) paint old neon while GTK3 is CANON.
- **Do instead:** Overlay from `~/Vault.OS/source/gtk-overlay/gtk4.css` (CANON `#1AFF6B` / `#070807`). `ensure-theme` must rewrite gtk-3 + gtk-4 overlays every run; allowlist ThemeName `Vault.OS|Vault.OS-Reduced` only.
- **Logged:** 2026-09-05 GTK-02

### DO NOT ship `button:checked` / `switch:checked` on phos_hot-on-ghost after fixing `theme_selected_*`
- Same AAA rule as selected rows. Checked states must use `@theme_selected_bg_color` / `@theme_selected_fg_color`.
- **Logged:** 2026-09-04 GTK-02 / Accessability Bot

### DO NOT leave xfwm on `Vault.OS` when GTK is `Vault.OS-Reduced`
- **Symptom:** Reduced GTK with CANON doors (wrong phosphor/rad plates).
- **Do instead:** When `THEME_NAME=Vault.OS-Reduced`, set `xfwm4 /general/theme` to `Vault.OS-Reduced` (own plates `#66FF9C` / `#E94D5A` / `#B7BEB4`). CANON mode keeps WM `Vault.OS`.
- **Fix:** ensure-theme must set xfwm4 `/general/theme` with the GTK theme. Logged 2026-09-05.

---


## Control plane / session

### DO NOT leave `~/.local/bin/vault-os` behind Projects
- Autostart runs PATH binary. Stale 1.5.2 vs Projects 1.5.x caused missing allowlists / wrappers.
- After bumping Projects, sync install to `~/.local/bin/vault-os`.

### DO NOT hardcode ThemeName=Vault.OS only in old lock/watch scripts
- Superseded: thin wrappers → `vault-os ensure-theme`; conf is source of truth.

---

---

## HUD-04 — panel / notify / unlock plate

### DO NOT use `text-transform` (or other web-only props) in `hud.css` / `lock.css` / `xfce-notify-4.0/gtk.css`
- **Symptom:** Gtk CssProvider: `'text-transform' is not a valid property name` — notify theme fails to load.
- **Do instead:** Drop it. Headings stay mono + letter-spacing + text-shadow only.
- **Logged:** 2026-09-04 HUD-04 error-scrub

### DO NOT make the unlock / screensaver dialog translucent over the Arch spin
- **Symptom:** Password plate washes into the spinning mark; focus/contrast fail a11y.
- **Do instead:** `lock.css` plate stays `background-color: @vault_black`, `opacity: 1`, `background-image: none`, bevel stamp. Saver surface is behind the dialog — never through it.
- **Logged:** 2026-09-04/05 HUD-04 / Genius

### DO NOT force 28px `min-height` on `.xfce4-panel .tasklist button`
- **Symptom:** Tasklist labels ghost / tabs “disappear” on a 28–30px bar.
- **Do instead:** Tasklist floor ~22px; protect with `min-height: 0` on `.tasklist *` then set button mins. Chrome (clock, launchers, actions) may stay 28px.
- **Logged:** 2026-09-04 HUD-04 (PipBoy drift + a11y crush)

### DO NOT ship whisker at 400×505 with opacity theater
- **Symptom:** Menu reads as a clunky blob.
- **Do instead:** `menu-width=320`, `menu-height=420`, `menu-opacity=100`. `ensure-panel` must re-pin these.
- **Logged:** 2026-09-04 HUD-04 / CLUNK.md

### DO NOT hardcode notify theme / panel defaults to PipBoy-NV in `vault-os`
- **Symptom:** Session-start / ensure-theme flips notify (and defaults) off Vault.OS even when conf says Vault.OS.
- **Do instead:** Defaults + `xfce4-notifyd /theme` = `${THEME_NAME:-Vault.OS}`; fade/slide off; panel plates under `~/.local/share/backgrounds/Vault.OS/`.
- **Logged:** 2026-09-04 HUD-04 control-plane scrub (Genius took sound/chromium follow-ups)

### DO NOT use gold/amber as notify frame chrome
- **Symptom:** Review FAIL — amber is warn, not plate edge.
- **Do instead:** Bevel stamp (`bevel-hi` in / `bevel-lo` out) on `panel-black` notify plate.
- **Logged:** 2026-09-03 VDS-01 Step 6 / HUD-04 retoken


## TRM-05 — terminal / phosphor / Arch spin

### DO NOT hardcode PipBoy `#33FF6A` / `#070C09` in `vault-os` apply for xfce4-terminal
- **Symptom:** Every `vault-os apply` / session-start undoes CANON; live FG drifts to `#33FF6A` while `terminalrc` says `#1AFF6B`.
- **Do instead:** Call `vaultos-terminal-phosphor` with mode from `~/.config/Vault.OS/terminal-phosphor` (default `reduced`). Fallback palette is CANON ANSI from `~/Vault.OS/tokens.css` only. Title `ROBCO 76`, not Pip-Boy 3000.
- **Logged:** 2026-09-04 TRM-05 (vault-os 1.5.2-trm05+)

### DO NOT let terminal phosphor dial freeze desktop or lock spin
- Terminal CRT: `vaultos-terminal-phosphor` {full|reduced|clear} — **only** the terminal well/scanlines/bloom.
- Desktop Arch: always `vaultos-spin-arch --full --instance desktop`.
- Lock/saver: `vaultos-spin-lock-run` → `--full` unless ThemeName is `Vault.OS-Reduced`.
- **Never** relaunch the desktop instance with `--reduced-phosphor` “to match CRT.”
- **Logged:** 2026-09-04/05 TRM-05 / Accessability Bot / Genius

### DO NOT put a broken `xfce-floaters.desktop` (or floaters override) under `~/.local/share/applications/screensavers/`
- **Symptom:** `Setting command: '(null)'` / null Exec — kills theme resolution for *all* local savers.
- **Do instead:** System path `/usr/share/applications/screensavers/vaultos-arch-spin.desktop` (un-Hidden); local dir only Vault.OS spin desktops. No stock overrides.
- **Logged:** 2026-09-05 Genius / TRM-05

### DO NOT leave `cy = height/2 - 40` in draw when the Arch window is logo-sized
- **Symptom:** Mark clipped / off-center; looked “not spinning” or broken.
- **Do instead:** Center at allocation mid. Screen offset belongs in `move()` only. Tick ~66ms (15fps) — not 250ms stutter, not fullscreen DOCK at 30fps (starves Xorg / new windows).
- **Logged:** 2026-09-05 TRM-05

### DO NOT ship sky-blue / copper in the ANSI 16 map
- **Symptom:** Review FAIL — illegal `#3F698D` / copper magenta.
- **Do instead:** CANON tokens only. Cyan = phosphor `#1AFF6B`. Magenta = rad-red `#C41E3A`. Well `#070807`, beam `#1AFF6B`.
- **Logged:** 2026-09-03 VDS-01 Step 6 / TRM-05 retoken

### DO NOT leave a trailing comma after a comment inside `terminal.css` color lists
- Same as GTK-02: CssProvider reads empty token as a color → LOAD FAIL on Vault.OS-Reduced.
- **Logged:** 2026-09-04 GTK-02 / TRM-05 owns terminal.css trees

### DO NOT treat Gtk.Plug xid `0` / missing `XSCREENSAVER_WINDOW` as a valid embed
- **Symptom:** Blank saver surface.
- **Do instead:** Fullscreen `Gtk.Window` fallback when xid is None/0 or `Plug.new` throws.
- **Logged:** 2026-09-05 TRM-05


## ICO-06 — icons / plates / cursors

### DO NOT fall `ICON_THEME` / `ensure-theme` back to `FalloutMojave` or `PipBoy-NV`
- **Symptom:** Desktop Home/Trash/BloodLink look FNV again while ThemeName says Vault.OS; session-start undoes plates.
- **Do instead:** Defaults and empty-var fallbacks are `Vault.OS`. Treat `FalloutMojave|PipBoy-NV` as drift (same as Adwaita). Live conf `ICON_THEME=Vault.OS`. Launchers (`x-app`, `firefox`) must not export PipBoy/Fallout icon defaults.
- **Logged:** 2026-09-04 ICO-06 / Genius

### DO NOT ship glyph ink `#44FF3D` (hue 118) or any freelance green
- **Symptom:** Step-6 REVIEW FAIL; plates disagree with CANON phosphor.
- **Do instead:** `#1AFF6B` on `inset` `#121612`, bevel `bevel-hi`/`bevel-lo`. Wallpaper 111 mark in `steel` unless WARN. Regenerate + copy live to Arch — box-only restamp is not enough.
- **Logged:** 2026-09-03/04 VDS-01 / ICO-06

### DO NOT leave dock tiles outside the plate family (`dock-map` / `dock-toxic` FNV leftovers)
- **Symptom:** Bottom bar / vault-dock mixes neon FNV sprites with stamped plates — "toy shelf."
- **Do instead:** Every `~/.icons/vault-dock/*.png` uses the same inset stamp + LED language as terminal/files/browser/apps/close. Unused leftovers get restamped or deleted, not ignored.
- **Logged:** 2026-09-04 ICO-06 scrub

### DO NOT let BloodLink / chromium / close-all / showdesktop resolve outside `~/.icons/Vault.OS`
- **Symptom:** Desktop or dock breaks the plate family (hicolor photo icons, Adwaita emblems, stock showdesktop).
- **Do instead:** Ship names into Vault.OS (`apps/` + `emblems/`) and keep `Inherits=hicolor` only — never inherit FalloutMojave. `bloodlink`, `chromium`, `firefox`, `vault-os-close-all`, `org.xfce.panel.showdesktop`, `emblem-important` must resolve under Vault.OS.
- **Logged:** 2026-09-04/05 ICO-06

### DO NOT use hue alone for rad / amber meaning
- **Symptom:** A11y fail under high-contrast / no-glow / reduced phosphor.
- **Do instead:** Shape + LED. Close = X bolt on rad plate. BloodLink = linked rings + rad pin. `emblem-important` = triangle + bang (amber fill is secondary). Icons must read at 16px without bloom.
- **Logged:** 2026-09-04 Accessability Bot / ICO-06

### DO NOT bake gold/amber into cursor or as chrome on plates
- **Symptom:** Review FAIL — amber is warn, not chrome.
- **Do instead:** Cursor = `vault-black` fill, phosphor outline, no gold. Gold/amber only for WARN marks.
- **Logged:** 2026-09-03 DESIGN / ICO-06


### DO NOT pin `GTK_THEME=PipBoy-NV` / `ICON_THEME=FalloutMojave` inside `*.desktop` Exec lines
- **Symptom:** Chromium/Firefox/apps open with FNV chrome while the session is Vault.OS.
- **Do instead:** `env GTK_THEME=Vault.OS ICON_THEME=Vault.OS …` (or omit and inherit xsettings). Game shortcuts (Lutris/Wine Fallout) may keep Fallout *names* — never session theme pins.
- **Logged:** 2026-09-05 VDS-01 / ICO-06 sweep (chromium+firefox already Vault.OS; no other desktop theme pins left)

## How to add an entry
1. Title the pitfall as **DO NOT …**
2. Symptom → why → do instead → owner/date if known
3. Keep this file and `source/` copy in sync when you edit


### DO NOT use a minimal custom screensaver `.desktop`
- **Symptom:** Even without `Hidden=`, theme id `screensavers-vaultos-arch-spin` → Exec `(null)`.
- **Rule:** Install a full desktop (floaters clone, Exec/TryExec → `/usr/lib/xfce4-screensaver/vaultos-arch-spin`, no `Hidden=`). See `source/xfce4-screensaver/UNHIDE.md`.

### DO NOT hijack `xfce-floaters.desktop` as the Vault.OS saver (VDS STOP)
- **Wrong:** xfconf `screensavers-xfce-floaters` with Exec→vaultos-arch-spin “slot hijack.”
- **Approved:** xfconf `screensavers-vaultos-arch-spin` + full metadata system desktop (no Hidden), Exec=`/usr/lib/xfce4-screensaver/vaultos-arch-spin`. Keep stock floaters stock.

### STANDING ORDER (VDS-01): `screensavers-vaultos-arch-spin`
- Theme + `ensure-theme` `saver_want` = `screensavers-vaultos-arch-spin` only.
- Full-metadata system desktop; Exec=`/usr/lib/xfce4-screensaver/vaultos-arch-spin`; no `Hidden=`.
- Stock `xfce-floaters.desktop` stays stock — **do not** slot-hijack.
- Obsolete: “stock ids only resolve / hijack floaters” guidance.

## xfwm4 — mixed decoration trees
- Do not leave a mixed xfwm tree: some XPMs hex+`s`, others symbolic-only. xfwm will look half-Default. Replace the whole `xfwm4/` dir, don’t patch one latch.

## GTK / Thunar — idle menubar spinner (2026-09-05) — VDS DESIGN CALL
- **DO NOT** leave idle spinner visible on Thunar menubar.
- Root cause of black square: `menuitem:disabled` solid vault_black + menubar min-height/padding on Thunar’s insensitive spinner host.
- Hide idle spinner **and** collapse host menuitem chrome; busy = quiet phosphor only.
- **Never use `!important` in GTK CSS** — CssProvider treats it as parse junk and can break the block.
- Lasting craft: theme `gtk-3.0` **and** `gtk-3.20` (GTK 3.24 loads 3.20). GTK-02 owns.
- `~/.config/gtk-3.0/gtk.css`: HUD `@import` only — no permanent spinner override fighting the theme.

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

## Terminal scrollbar hide
Do not force `ScrollingBar=NONE` / `TERMINAL_SCROLLBAR_NONE` in `vaultos-terminal-phosphor` or `terminalrc*`. Old phosphor pipe was a full-height green column; fix is thin recessed latch CSS (GTK/HUD), not hiding the bar. Keep `TERMINAL_SCROLLBAR_RIGHT`.

## Terminal install seed
Fresh `vault-os install` must copy the full `source/xfce4-terminal/` tree and seed live `terminalrc` from `terminalrc.reduced` (not only the generic `terminalrc`). Always keep `ScrollingBar=TERMINAL_SCROLLBAR_RIGHT`.

## Desktop Arch spin CPU
Do not leave `vaultos-spin-arch --full` running for days on HD 630 — it burns CPU. Default desktop mark is `--reduced-phosphor` (static). Opt into spin with `~/.config/Vault.OS/desktop-spin=full`. Autostart must call `vaultos-spin-arch-autostart`, not a hard `--full` Exec.

## ISO / mkarchiso

### DO NOT rely on the exec bit of scripts copied into `airootfs`
- **Symptom:** A helper that is `0755` in the repo and in `iso/profile/airootfs` boots as `0644` on the ISO, so its systemd unit or caller fails with `Permission denied`.
- **Why:** mkarchiso drops the exec bit on airootfs files unless the path is listed in `file_permissions` in `profiledef.sh`. `install -m 0755` in `prepare-profile.sh` is not enough on its own.
- **Do instead:** Add every new script under `airootfs` to the `file_permissions` block that `iso/prepare-profile.sh` writes (`["/path"]="0:0:755"`), next to `vaultos-install` and the `vaultos-*.sh` libexec helpers.

## First-boot wizard (shell + C++ port)

### DO NOT stamp only `firstuser-done` from a wizard
- **Symptom:** The old C++ `vaultos-firstuser` wrote `/var/lib/vaultos/firstuser-done` only. `vaultos-firstuser.service` has `ConditionPathExists=!/var/lib/vaultos/firstboot-done`, so the wizard would have started again on every boot.
- **Do instead:** Write `firstboot-done` (the commit point) and copy it to `firstuser-done`, as the shell wizard does. `iso/test-firstboot.sh` checks both stamps for both wizards.
- **Logged:** 2026-09-30 cpp-firstuser

### DO NOT re-ask from the answers file without clearing the bad answer
- **Symptom:** `hostname=bad_host!` in `firstboot.conf` made the shell wizard print "Use letters, digits…" forever. Every other prompt cleared `ANSWERS[key]` on a bad value; the hostname loop did not.
- **Do instead:** Clear the key so the next round falls back to the keyboard (EOF on a headless boot fails cleanly and rolls back). The harness runs this case under `timeout`.
- **Logged:** 2026-09-30 cpp-firstuser

### DO NOT read wizard prompts through a buffered stream (`std::cin`, `fgets`)
- **Symptom:** Typed-ahead keys survive `tcflush()`. stdio/iostream pull them into a user-space buffer, and the next prompt reads them as the username.
- **Do instead:** Read fd 0 with `read(2)`, one byte at a time, and flush with `tcflush(TCIFLUSH)` until the keyboard has been quiet for 50 ms (the shell's `read -t 0.05` loop). No `SA_RESTART`, so Ctrl-C unblocks the read and rolls back.
- **Logged:** 2026-09-30 cpp-firstuser

### DO NOT compare wizard file modes under the developer's umask
- **Symptom:** On a box with `umask 077` the shell wizard writes `/etc/hostname` etc. 0600, but systemd runs it with 0022 (0644). Parity diffs of modes then mean nothing.
- **Do instead:** `iso/test-firstboot.sh` sets `umask 022`. The C++ `put()` creates new files `0666 & ~umask`, like a shell redirect, and keeps the mode of files it replaces.
- **Logged:** 2026-09-30 cpp-firstuser

### DO NOT `mv` a rewritten copy over `/etc/shadow` (even in a fake root)
- **Symptom:** The shell wizard's test-mode rollback did `grep -v … >shadow.tmp && mv shadow.tmp shadow`, leaving the fake shadow 0644 (the parity diff caught it).
- **Do instead:** `cat tmp >file` (keeps the mode) or write and rename with the old mode, as the C++ port does.
- **Logged:** 2026-09-30 cpp-firstuser

### DO NOT measure a child's memory with `ru_maxrss` from a big parent
- **Symptom:** Shell and C++ wizards both showed 17 MiB peak RSS. Linux keeps the RSS high-water mark across `execve`, so a Python `fork()`+exec reports Python's size.
- **Do instead:** Launch through a tiny static C launcher (`fork`, `execv`, `wait4`) and read `ru_maxrss` there.
- **Logged:** 2026-09-30 cpp-firstuser

### DO NOT pipe into `grep -q` under `set -o pipefail`
- **Symptom:** `vault-os doctor` said `font Share Tech Mono MISSING` with the font installed (seen with a fake HOME; the live run hid it behind the file check). `grep -q` exits at the first match, `fc-list` dies of SIGPIPE, and pipefail turns the match into a failure. Whether it happens depends on timing and output size.
- **Do instead:** `cmd | grep -F pattern >/dev/null` (grep reads to EOF), or capture first: `out=$(cmd); [[ $out == *x* ]]`.
- **Logged:** 2026-09-30 cpp-tools (found by the native doctor parity test)

### DO NOT assume a port of the lint can sort however it likes
- **Symptom:** Byte-identical output needs the same order as the bash tools: `find`/`grep -r` walk in readdir order (no sort), globs, `diff -r` and `sort -u` sort with `strcoll` in the user's locale, and bash walks associative-array keys in hash order (`hexsym symonly mixed none` for `_xpm_n`).
- **Do instead:** `src/vaultos-doctor` reads directories with `readdir`, sorts with `strcoll` where bash does, and hard-codes the assoc order. `src/vaultos-doctor/test-parity.sh` diffs both on clean and broken copies of the tree; run it after changing either side.
- **Logged:** 2026-09-30 cpp-tools

### DO NOT skip side effects that follow a failed redirect when porting
- **Symptom:** `{ …; } >"$IDSTAMP"; chmod 0644 "$IDSTAMP"` still runs the chmod when the redirect fails (set +e). With a directory in the way the script chmods the directory to 0644; a port that only chmods after a successful write leaves it 0755 (the boot parity test caught it).
- **Do instead:** Port every statement after a failing one unless the script uses `&&`/`set -e`. Test the "path is a directory" and "parent is a file" cases.
- **Logged:** 2026-09-30 cpp-tools

### DO NOT test real-mode boot helpers against the host's /var
- **Symptom:** The no-test-root branches (systemctl, identity-apply, /var/log) can't be run on a dev box without writing system state.
- **Do instead:** `unshare -rm` gives a private user+mount namespace where `mount --bind TMP /var/lib` works unprivileged; put stub `systemctl`/`identity-apply.sh` first in PATH/`VAULTOS_LIB`. See `src/vaultos-boot/test-parity.sh`.
- **Logged:** 2026-09-30 cpp-tools

### DO NOT pass a Wi-Fi PSK (or any secret) as a command-line argument
- **Symptom:** Both wizards ran `nmcli device wifi connect SSID password PSK` and `iwctl --passphrase PSK …`. Any local user can read the PSK from `ps` or `/proc/PID/cmdline` while the command runs. The shell test path also ran `openssl passwd -6 "$pw"`.
- **Do instead:** nmcli: `connection add … wifi-sec.key-mgmt wpa-psk` with no secret, then `connection up uuid U passwd-file /dev/fd/3 3<<<"802-11-wireless-security.psk:ESCAPED"` (passwd-file takes backslash escapes and strips unescaped edge spaces, so escape `\`, spaces and tabs). iwctl: write `/var/lib/iwd/<name>.psk` 0600 (`[Security]` `Passphrase=`; escape `\`, tab, and a leading space as `\s`; name is the SSID or `=`+hex), then `iwctl station DEV connect SSID`. In bash, only builtins may touch the secret. `iso/test-firstboot.sh` stubs nmcli/iwctl, scans every `/proc/*/cmdline` with a random marker in the PSK, and diffs both wizards.
- **Logged:** 2026-09-30 cpp-tools

### DO NOT record "I created X" only after creating X
- **Symptom:** The shell wizard set `CREATED_USER` after useradd returned. A SIGTERM between the passwd write and that line left the account behind, because the EXIT trap had no name to roll back (the SIGTERM test failed intermittently).
- **Do instead:** Set the rollback marker before the step that creates the thing, and make the rollback safe when nothing was made (the name was checked free, so `userdel` of a missing user is a no-op).
- **Logged:** 2026-09-30 cpp-tools

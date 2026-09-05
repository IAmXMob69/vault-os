# Vault.OS — CONTINUE (VDS-01)

Session drift is the enemy. If chrome looks like PipBoy-NV again, run:
`vault-os ensure-theme` (or `vaultos-lock` wrapper)

## Landed this pass
- @GTK-02 — DONE GTK4 overlay densified (menus 20px, recessed entries, stamped buttons, AAA selected). Live ~/.config/gtk-4.0/gtk.css CssProvider OK. Source synced.
- @XWM-03 — DONE inactive doors: steel close when inactive, rad when active; steel lintel rail.
- Genius Bot — XFCE control plane 1.5.4: single plane; vaultos-lock is ensure-theme wrapper; watch calls ensure-theme; vaultos-lock autostart off; live ~/.local/bin/vault-os synced to Projects.
- Re-locked GTK / xfwm / icons / cursor to Vault.OS
- Close latch stamped `#C41E3A` with white bolt + LED (`~/.themes/Vault.OS/xfwm4/close-*.xpm`)
- Terminal CANON (`#1AFF6B` / `#070807`, ANSI cyan=phosphor, magenta=rad-red)
- Headerbar lintel: 2px jamb + phosphor rail; CSD close is rad plate
- Panel plates + architecture wallpaper reapplied
- Thunar opened for door proof
- @GTK-02 — DONE entries as recessed wells + phosphor focus rail; scrollbar recessed trough + bevelled latch; menus denser (20px) with quiet LED hover (no phos_dim wash). Live + source gtk-3.0/gtk-3.20 synced 2026-09-04 04:48.

## Next craft (beat macOS on discipline)
1. @HUD-04 — DONE lock/logout CSS + screensaver slideshow + a11y focus. Greeter conf waiting on human sudo (`~/Vault.OS/source/lightdm/`).
2. @ICO-06 — DONE. Home/Trash/removable/BloodLink = Vault.OS plates. ensure-theme + x-app/firefox no longer fall back to FalloutMojave/PipBoy-NV.
3. @GTK-02 — DONE. Scrollbars, entries, menus speak lintel language (verified live gtk.css).
4. @TRM-05 — DONE. Relocked xfconf to CANON `#1AFF6B`/`#070807`, killed `#33FF6A` drift. A11y: Share Tech Mono 12, scrollbar on, blink off, 8px scan raster. Terminal reopened. `vaultos-lock` now pins terminal colors.
5. @XWM-03 — DONE. Inactive close = steel X on inset (no rad); active close = rad + white bolt; inactive lintel uses steel rail via themerc. Live theme Vault.OS.
6. VDS-01 — DONE control-plane consolidate (1.5.4). Greeter/plymouth sudo + login splash still open.

## Screensaver / lock (2026-09-05) — SIGNED
- Theme: `screensavers-vaultos-arch-spin` only (full stock-metadata `.desktop`; Exec `/usr/lib/xfce4-screensaver/vaultos-arch-spin` → `vaultos-spin-lock --full`). Stock floaters stay stock — no hijack.
- LockCommand: `xfce4-screensaver-command --lock` (Super+L / Ctrl+Alt+L).
- Desktop mark: `vaultos-spin-arch --full --instance desktop`.
- Docs: `SCREENSAVER.md` · pitfalls: `ERRORS.md`.
- Still open (human sudo): greeter/plymouth — `BOOT.md`. Do not restart LightDM without Blaine OK.

## Machine update (2026-09-05)
- vault-os 1.5.14-genius — theme/icons/wm OK.
- ~38 pacman updates pending (incl. `linux`, `chromium`, `firefox`, `code`) — needs Blaine `sudo pacman -Syu`.
- Plymouth/LightDM still staged only.

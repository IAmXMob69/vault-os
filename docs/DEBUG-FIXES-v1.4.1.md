# Debug fixes — Vault-OS 1.4.1

## Fixed
1. **picom** — removed deprecated `_GTK_FRAME_EXTENTS@:c` type specifier (was warning every start)
2. **Desktop backdrop rgba1** — was stock red; now CRT green `#070D09`
3. **xfconf xq_set** — type-safe: on set failure, remove property and recreate (prevents stuck wrong types)
4. **xfce4-notifyd /notify-location** — was gchararray vs gint; reset to proper numeric type; apply no longer overwrites if set
5. **xfce4-notifyd /primary-monitor** — removed bad prop writes that caused guint/gint errors
6. **Share Tech Mono detection** — file-first check avoids pipefail false negatives under `set -e`
7. **Empty scalable icon dirs** — removed (no files, not in index)
8. **Desktop files** — Categories/Encoding warnings cleaned (hplip, vault-os, pipboy-terminal)
9. **xfwm themerc** — `show_app_icon=false` to reduce GLib icon lookup noise; border colors set
10. **Status health** — reports cursor_dir, picom, notify theme dir

## Historical (already fixed earlier, confirmed clean)
- Invalid CSS `selection-color` / `selection-background-color` (gone from current gtk.css; GTK3 CSS loads OK)
- Stale wallpaper paths in vault-os.conf
- Panel background-style wiping textures

## Notes
- Massive historical `xfwm4 GLib-CRITICAL g_hash_table_lookup` spam in `.xsession-errors` came from `xfwm4 --replace` theme reload races; not present on steady-state after soft theme toggle.
- Panel integrity timer (`vault-os-panel-watch.timer` every 2m) is intentional.

# Screensaver desktop requirements

1. Do not set `Hidden=true` on `vaultos-arch-spin.desktop` if you expect the theme to run.
2. Prefer a full screensaver `.desktop` (same metadata shape as stock floaters/slideshow), with Exec/TryExec pointed at `/usr/lib/xfce4-screensaver/vaultos-arch-spin`.
3. Never leave a local override of `xfce-floaters.desktop` under `~/.local/share/applications/screensavers/`.

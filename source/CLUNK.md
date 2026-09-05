# Vault.OS — anti-clunk (VDS-01)

## Root cause of "unprofessional"
`~/.config/fallout-nv/vault-os.conf` still said PipBoy-NV. Autostart `vault-os session-start` kept flipping ThemeName. We fought ourselves.

## Fixed
- Conf retargeted to Vault.OS (backup: vault-os.conf.bak-pipboy)
- `vault-os ensure-theme` now reinforces Vault.OS
- Boot intro disabled (INTRO_ENABLED=0)
- Panel plates = Vault.OS, not FNV neon skins
- `vaultos-lock` no longer restarts the panel every call
- `vaultos-watch` autostart **off** (was 15s xfconf storm; systemd timer 10 min)
- Desktop: hide hidden files, icon size 40

## Still on specialists
@GTK-02 — denser spacing, quieter menus, kill leftover PipBoy metrics in gtk-4
@XWM-03 — inactive doors less muddy; resize grips professional
@HUD-04 — whisker 400×505 is a blob; tighten to 320×420, less opacity theater
@ICO-06 — BloodLink desktop icons still break the plate language; one family
@TRM-05 — font 11pt not 12 (12 reads loud on 1080p)

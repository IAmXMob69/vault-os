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
@GTK-02 — DONE. GTK4 overlay densified (20px menus, recessed entries, stamped buttons); PipBoy #33FF6A killed in ~/.config/gtk-4.0/gtk.css
@XWM-03 — inactive doors less muddy; resize grips professional
@HUD-04 — DONE whisker 320×420, opacity 100, denser 22px rows
@ICO-06 — DONE. BloodLink + desktop plates on Vault.OS family; dock leftovers restamped.
@TRM-05 — font 11pt not 12 (12 reads loud on 1080p)

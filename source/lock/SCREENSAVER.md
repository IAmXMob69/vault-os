# Vault.OS screensaver / lock face

## Idle screensaver
- Theme: `screensavers-xfce-personal-slideshow`
- Frames: `~/.local/share/backgrounds/Vault.OS/lock-spin-frames/frame-*.png` (24-step Y-spin on vault-black)
- Why slideshow: xfce4-screensaver only reliably resolves stock theme Exec without root

## Lock (Ctrl+Alt+L / panel)
- `LockCommand` = `~/.local/bin/vaultos-session-lock`
- Starts live `vaultos-spin-lock --full`, then `xfce4-screensaver-command --lock`
- Unlock dialog sits on top of the spinning Arch face

## Desktop mark
- `vaultos-spin-arch --full --instance desktop` (always spins)

## Pitfalls
- See [ERRORS.md](ERRORS.md) (pointer) and team canon [`~/Vault.OS/ERRORS.md`](../../ERRORS.md) — do not repeat those mistakes.

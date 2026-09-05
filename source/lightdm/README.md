# HUD-04 lock / greeter

## Live without root
- Lock/logout CSS: `~/.themes/Vault.OS/gtk-3.0/lock.css` (imported by gtk.css)
- Screensaver: personal slideshow on `vault-111.png`
- A11y: 2px phosphor focus, 28px hits on panel + lock plates

## Needs human (sudo once)
```
sudo cp ~/Vault.OS/source/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf
sudo systemctl restart lightdm   # ends session — do at logout
```
Greeter CSS rides ThemeName=Vault.OS + `greeter.css` in the theme.

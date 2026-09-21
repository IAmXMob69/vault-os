# Vault.OS

**Vault.OS is an Arch Linux derivative, not a from-scratch kernel.** It keeps the Arch kernel (`linux` or `linux-lts`), pacman, systemd, and official Arch repos. Identity is `ID=vaultos` with `ID_LIKE=arch`.

This repository is both:

1. **Distro overlay + live/install ISO** (`overlay/`, `iso/`, `bin/vaultos`) so a machine can report as Vault.OS and so other PCs can be installed from `vaultos-<version>-x86_64.iso`.
2. **XFCE desktop chrome** (GTK/xfwm theme, icons, Plymouth, greeter) with Vault-Tec terminal energy — not a green wash over Adwaita.

Phosphor: `#1AFF6B`. Fonts: Share Tech Mono, Overpass Mono, Terminus (or PxPlus IBM VGA8).

Distro CLI is `vaultos` (no hyphen): `status`, `version`, `doctor`, `overlay`, `update`, `iso`, `firstboot`.  
Theme/session CLI is `vault-os` (hyphen). Overlay docs: [`overlay/README.md`](overlay/README.md). ISO: [`iso/README.md`](iso/README.md).

## First boot

A freshly installed disk has **no login user**. The first boot takes tty1 and asks:

```text
  Vault.OS setup
  ──────────────
  Enter accepts the value in [brackets].

Hostname [vaultos]:
Timezone (type a zone, or a search like 'New_York') [UTC]:
Locale [en_US.UTF-8]:
Keyboard layout [us]:
Connect Wi-Fi now? [y/N]:
Username []:
Password:
Password (again):
```

Then LightDM starts with session `vaultos`. The wheel sudoers drop-in is visudo-checked. Theme bits are copied from `/etc/skel`.

Re-run (next boot shows the wizard again):

```bash
sudo vaultos firstboot --reset
```

Unattended:

- Kernel: `vaultos.firstboot=skip` (stamp and continue)
- Kernel: `vaultos.firstboot=/etc/vaultos/firstboot.conf`
- Or drop answers in `/etc/vaultos/firstboot.conf` (see `overlay/firstboot.conf.example`)

```text
hostname=vaultos
timezone=UTC
locale=en_US.UTF-8
keymap=us
username=alice
password=change-me
skip_wifi=1
```

Tests (fake root, does not touch this machine): `iso/test-firstboot.sh`.

## Layout

| Path | What |
|------|------|
| `themes/Vault.OS` | GTK, window borders, notifications |
| `themes/Vault.OS-Reduced` | High contrast / less motion |
| `icons/Vault.OS` | Icons and cursors |
| `source/` | Panel plates, lock, greeter, Plymouth |
| `bin/vault-os` | Install + keep the session on-theme |
| `bin/vaultos-*` | Lock, Arch spin, terminal phosphor |

Design notes live in [`DESIGN.md`](DESIGN.md). Colors are in [`tokens.css`](tokens.css).

## Install

```bash
./bin/vault-os install
vault-os status
```

That drops themes and icons into `~/.themes` / `~/.icons`, plates into `~/.local/share/backgrounds/Vault.OS`, links the helpers in `~/.local/bin`, writes a Vault.OS conf, and runs `ensure-theme`.

Stuck? See [INSTALLATION.md](INSTALLATION.md).

Or by hand:

```bash
cp -a themes/Vault.OS themes/Vault.OS-Reduced ~/.themes/
cp -a icons/Vault.OS ~/.icons/
mkdir -p ~/.local/share/backgrounds/Vault.OS ~/.local/bin
cp -a source/wallpapers/. ~/.local/share/backgrounds/Vault.OS/
ln -sfn "$(pwd)/bin/vault-os" ~/.local/bin/vault-os
# same for bin/vaultos-* if you want them on PATH
cp -f config/fallout-nv/vault-os.conf ~/.config/fallout-nv/vault-os.conf
vault-os ensure-theme
```

Set Appearance and Window Manager to **Vault.OS**. For the reduced look, set `THEME_NAME=Vault.OS-Reduced` in `~/.config/fallout-nv/vault-os.conf`.

## Lock and screensaver

Theme: `screensavers-vaultos-arch-spin`.  
Lock command: `xfce4-screensaver-command --lock`.  
Leave stock floaters alone.

One-time sudo so the saver has a real binary:

```bash
sudo ./source/xfce4-screensaver/install-system.sh
```

More detail: [`source/lock/SCREENSAVER.md`](source/lock/SCREENSAVER.md).

## Boot / greeter

Optional. Files are under `source/plymouth/` and `source/lightdm/`. See [`BOOT.md`](BOOT.md). Don’t restart LightDM until you’re ready for a login cycle.

## Fonts

```
extra/otf-overpass
extra/terminus-font
aur/ttf-share-tech-mono
aur/ttf-ultimate-oldschool-pc-font-pack
```

## License

[`LICENSE`](LICENSE).

# Vault.OS identity overlay (Phase 1)

Arch derivative branding. **Not a kernel.** `ID_LIKE=arch` stays so pacman and yay keep working.

Hostname is **not** changed by this overlay.
Bootloader, initramfs, and disks are **not** touched.

## Files this overlay installs

| Path | Action |
|------|--------|
| `/etc/os-release` | Replace Arch symlink with Vault.OS file. `/usr/lib/os-release` stays Arch (pacman `filesystem` package). |
| `/etc/lsb-release` | Create |
| `/etc/issue` | Replace |
| `/etc/motd` | Create |
| `/etc/pacman.conf` | Append a **commented** `[vaultos]` stub |
| `/etc/hostname` | Unchanged by identity-apply; the first-boot wizard may set it |

Source copies live in `overlay/identity/`.

## Commands

```bash
./overlay/identity-apply.sh status
./overlay/identity-apply.sh apply      # pkexec/sudo
./overlay/identity-apply.sh rollback
```

Same via `vault-os overlay status|apply|rollback`.

Backup lands in `/var/lib/vaultos/backups/phase1-<timestamp>/`.

## Phase 2 — control plane (system)

| Path | Role |
|------|------|
| `/usr/lib/vaultos/` | Installed overlay + `bin/vaultos` + libexec |
| `/usr/bin/vaultos` | Distro CLI (`status version doctor overlay update iso`) |
| `vaultos-core.service` | Oneshot, RemainAfterExit, WantedBy=multi-user. Not ordered before LightDM. |
| `vaultos-firstboot.service` | Identity (os-release) + NetworkManager. Stamps `identity-applied`, not `firstboot-done`. |
| `vaultos-firstuser.service` | Fresh-install TTY wizard (machine + account). Before LightDM, Conflicts getty@tty1. Stamps `firstboot-done` only on success. Not enabled by `install-system.sh`. |

Theme/session CLI remains `vault-os` (hyphen). XFCE watch stays a **user** unit.

```bash
./overlay/install-system.sh          # pkexec
vaultos status
vaultos doctor
systemctl status vaultos-core.service
```

`vaultos update` pulls the git checkout and re-applies identity. Pass `--packages` for `pacman -Syu` (not implied). `vaultos iso` is a Phase 5 stub.

## Phase 3 — boot menu and session

Does **not** add a Plymouth mkinitcpio hook (that can brick initramfs). Splash is the UKI BMP.

| Path | Role |
|------|------|
| `/boot/EFI/Linux/vaultos-linux.efi` | Default UKI (title from Vault.OS os-release) |
| `/boot/EFI/Linux/arch-linux-recovery.efi` | Static copy of the pre-phase3 Arch UKI |
| `/boot/EFI/Linux/arch-linux.efi` | Left in place |
| `/boot/loader/loader.conf` | `default vaultos-linux.efi`, `timeout 8` |
| `/usr/share/systemd/bootctl/splash-vaultos.bmp` | UKI splash |
| `/usr/share/xsessions/vaultos.desktop` | LightDM session name “Vault.OS” |
| `/usr/share/backgrounds/vaultos/` | Wallpapers |
| `/usr/share/pixmaps/vaultos.png` | Logo |
| `/usr/share/plymouth/themes/Vault.OS/` | Staged only — not in HOOKS |

```bash
./overlay/install-boot.sh
```

Rollback boot default to Arch UKI:

```bash
sudo cp /var/lib/vaultos/backups/phase3-*/loader.conf /boot/loader/loader.conf
# or:
#   default arch-linux.efi
# recovery image: /boot/EFI/Linux/arch-linux-recovery.efi
```

LightDM is not restarted by this script.

## Phase 4 — package lists and updates

| Path | Role |
|------|------|
| `/etc/vaultos/packages.base` | Base Arch packages (linux, not linux-lts) |
| `/etc/vaultos/packages.desktop` | XFCE + LightDM set |
| `vaultos packages` | Compare lists to installed |
| `vaultos update` | git pull + identity + unit restart |
| `vaultos update --syu` | Also `pacman -Syu` (can upgrade kernel; not implied) |

No chaotic-aur or unsigned repos. `[vaultos]` in pacman.conf stays commented.

```bash
./overlay/install-packages.sh "$PWD" --needed   # copies lists; pacman -S --needed only
```

## Rollback if identity breaks tools

```bash
sudo ./overlay/identity-apply.sh rollback
# or manually:
sudo ln -sfr /usr/lib/os-release /etc/os-release
```

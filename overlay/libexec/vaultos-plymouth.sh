#!/usr/bin/env bash
# Install firmware Plymouth theme + rebuild Vault.OS UKI only.
# Keeps arch-linux.efi and arch-linux-recovery.efi. Does not touch hostname.
set -euo pipefail
SCRIPT="$(readlink -f "$0")"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC="$(cd "$(dirname "$SCRIPT")/../.." && pwd)"
fi
if [[ "$(id -u)" -ne 0 ]]; then
  exec pkexec "$SCRIPT" "$SRC"
fi

THEME_SRC="$SRC/source/plymouth/Vault.OS"
[[ -f "$THEME_SRC/firmware.png" ]] || { echo "missing firmware.png" >&2; exit 1; }

TS=$(date +%Y%m%dT%H%M%S)
BAK=/var/lib/vaultos/backups/phase3-plymouth-$TS
mkdir -p "$BAK" /usr/share/plymouth/themes/Vault.OS /usr/share/systemd/bootctl
cp -a /etc/mkinitcpio.conf "$BAK/mkinitcpio.conf"
cp -a /etc/kernel/cmdline "$BAK/cmdline"
[[ -f /boot/EFI/Linux/vaultos-linux.efi ]] && cp -a /boot/EFI/Linux/vaultos-linux.efi "$BAK/vaultos-linux.efi" || true
[[ -f /boot/EFI/Linux/arch-linux-recovery.efi ]] || {
  echo "no recovery UKI — abort rather than risk boot" >&2
  exit 1
}

cp -a "$THEME_SRC/." /usr/share/plymouth/themes/Vault.OS/
install -m 0644 "$SRC/overlay/boot/splash-vaultos.bmp" /usr/share/systemd/bootctl/splash-vaultos.bmp
plymouth-set-default-theme Vault.OS

# Insert plymouth after kms if missing. Keep lvm2.
if ! grep -q ' plymouth ' /etc/mkinitcpio.conf; then
  sed -i 's/consolefont lvm2 block/consolefont plymouth lvm2 block/' /etc/mkinitcpio.conf
fi
if ! grep -qw splash /etc/kernel/cmdline; then
  echo "$(cat /etc/kernel/cmdline) splash" >/etc/kernel/cmdline
fi

if ! mkinitcpio -p linux; then
  echo "mkinitcpio failed — restoring mkinitcpio.conf and cmdline" >&2
  cp -a "$BAK/mkinitcpio.conf" /etc/mkinitcpio.conf
  cp -a "$BAK/cmdline" /etc/kernel/cmdline
  exit 1
fi
[[ -f /boot/EFI/Linux/vaultos-linux.efi ]] || { echo "vaultos UKI missing" >&2; exit 1; }
echo "plymouth theme Vault.OS; UKI rebuilt"
echo "recovery still /boot/EFI/Linux/arch-linux-recovery.efi"
grep '^HOOKS=' /etc/mkinitcpio.conf
cat /etc/kernel/cmdline
ls -l /boot/EFI/Linux/

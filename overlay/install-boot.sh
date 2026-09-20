#!/usr/bin/env bash
# Phase 3: UKI splash + recovery copy + desktop session assets.
# Does not add a Plymouth initramfs hook. Does not restart LightDM.
# Does not delete the current Arch UKI.
set -euo pipefail

SCRIPT="$(readlink -f "$0")"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
  SRC="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
fi
[[ -f "$SRC/overlay/boot/splash-vaultos.bmp" ]] || { echo "install-boot: missing splash" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  exec pkexec "$SCRIPT" "$SRC"
fi

TS="$(date +%Y%m%dT%H%M%S)"
BAK=/var/lib/vaultos/backups/phase3-$TS
mkdir -p "$BAK" /usr/share/backgrounds/vaultos /usr/share/backgrounds/Vault.OS \
  /usr/share/pixmaps /usr/share/xsessions /usr/share/wayland-sessions \
  /usr/share/plymouth/themes/Vault.OS /usr/share/systemd/bootctl \
  /boot/EFI/Linux /var/lib/vaultos

# --- backups (never skip the live UKI) ---
cp -a /etc/mkinitcpio.d/linux.preset "$BAK/linux.preset"
cp -a /boot/loader/loader.conf "$BAK/loader.conf"
if [[ -f /boot/EFI/Linux/arch-linux.efi ]]; then
  cp -a /boot/EFI/Linux/arch-linux.efi "$BAK/arch-linux.efi"
  if [[ ! -f /boot/EFI/Linux/arch-linux-recovery.efi ]]; then
    cp -a /boot/EFI/Linux/arch-linux.efi /boot/EFI/Linux/arch-linux-recovery.efi
    echo "recovery UKI: /boot/EFI/Linux/arch-linux-recovery.efi"
  else
    echo "recovery UKI already present, left as-is"
  fi
else
  echo "install-boot: no /boot/EFI/Linux/arch-linux.efi" >&2
  exit 1
fi

# --- splash + pixmap + wallpapers ---
install -m 0644 "$SRC/overlay/boot/splash-vaultos.bmp" /usr/share/systemd/bootctl/splash-vaultos.bmp
install -m 0644 "$SRC/overlay/boot/vaultos.png" /usr/share/pixmaps/vaultos.png
if [[ -d "$SRC/source/wallpapers" ]]; then
  install -m 0644 "$SRC/source/wallpapers/"*.png /usr/share/backgrounds/Vault.OS/ 2>/dev/null || true
  install -m 0644 "$SRC/source/wallpapers/"*.png /usr/share/backgrounds/vaultos/ 2>/dev/null || true
fi
install -m 0644 "$SRC/overlay/xsessions/vaultos.desktop" /usr/share/xsessions/vaultos.desktop
install -m 0644 "$SRC/overlay/xsessions/vaultos.desktop" /usr/share/wayland-sessions/vaultos.desktop

# Plymouth theme files only — no mkinitcpio hook, so this cannot change initramfs.
if [[ -d "$SRC/source/plymouth/Vault.OS" ]]; then
  cp -a "$SRC/source/plymouth/Vault.OS/." /usr/share/plymouth/themes/Vault.OS/
fi

# --- preset then UKI ---
install -m 0644 "$SRC/overlay/boot/linux.preset" /etc/mkinitcpio.d/linux.preset
echo "building /boot/EFI/Linux/vaultos-linux.efi (same HOOKS as current, new os-release + splash)"
if ! mkinitcpio -p linux; then
  echo "mkinitcpio failed — restoring linux.preset, loader.conf unchanged" >&2
  cp -a "$BAK/linux.preset" /etc/mkinitcpio.d/linux.preset
  exit 1
fi

if [[ ! -f /boot/EFI/Linux/vaultos-linux.efi ]]; then
  echo "vaultos-linux.efi missing after mkinitcpio — restoring preset" >&2
  cp -a "$BAK/linux.preset" /etc/mkinitcpio.d/linux.preset
  exit 1
fi
sz=$(stat -c '%s' /boot/EFI/Linux/vaultos-linux.efi)
if [[ "$sz" -lt 10000000 ]]; then
  echo "vaultos-linux.efi too small ($sz) — restoring preset" >&2
  rm -f /boot/EFI/Linux/vaultos-linux.efi
  cp -a "$BAK/linux.preset" /etc/mkinitcpio.d/linux.preset
  exit 1
fi

# Only now point the boot menu default at the new UKI. Old Arch UKI stays.
install -m 0755 "$SRC/overlay/boot/loader.conf" /boot/loader/loader.conf

{
  echo "phase3=$TS"
  echo "default=vaultos-linux.efi"
  echo "recovery=/boot/EFI/Linux/arch-linux-recovery.efi"
  echo "arch_uki=/boot/EFI/Linux/arch-linux.efi"
} >/var/lib/vaultos/phase3-boot.txt

echo "backup $BAK"
echo "default UKI: vaultos-linux.efi ($sz bytes)"
echo "recovery UKI: arch-linux-recovery.efi (copy of pre-phase3 Arch image)"
echo "arch-linux.efi left in place"
echo "LightDM not restarted"
echo "Plymouth hook NOT added to mkinitcpio (UKI splash only)"
ls -l /boot/EFI/Linux/
cat /boot/loader/loader.conf

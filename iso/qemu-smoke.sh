#!/usr/bin/env bash
# Boot the Vault.OS ISO live kernel in QEMU (serial only). Does not touch host disks.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VER="$(tr -d '\n' <"$ROOT/overlay/VERSION")"
ISO="${1:-$ROOT/iso/out/vaultos-${VER}-x86_64.iso}"
[[ -f "$ISO" ]] || { echo "missing $ISO (run iso/build.sh)" >&2; exit 1; }

DEST=/tmp/vaultos-iso-extract
mkdir -p "$DEST"
bsdtar xf "$ISO" -C "$DEST" vaultos/boot/x86_64/vmlinuz-linux vaultos/boot/x86_64/initramfs-linux.img
UUID="$(bsdtar tf "$ISO" | awk -F/ '/^boot\/[0-9].*\.uuid$/{sub(/\.uuid$/,"",$2); print $2; exit}')"
[[ -n "$UUID" ]] || { echo "no archiso uuid in ISO" >&2; exit 1; }
chmod u+r "$DEST/vaultos/boot/x86_64/"*

echo "ISO $ISO"
echo "UUID $UUID"
echo "serial on stdio; default live. Ctrl-A X to quit."
exec qemu-system-x86_64 -enable-kvm -cpu host -m 1536 -smp 2 \
  -display none -serial mon:stdio \
  -drive file="$ISO",media=cdrom,readonly=on,if=virtio \
  -kernel "$DEST/vaultos/boot/x86_64/vmlinuz-linux" \
  -initrd "$DEST/vaultos/boot/x86_64/initramfs-linux.img" \
  -append "archisobasedir=vaultos archisosearchuuid=${UUID} console=ttyS0,115200n8 loglevel=3" \
  -no-reboot

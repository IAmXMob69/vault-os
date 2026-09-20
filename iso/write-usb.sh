#!/usr/bin/env bash
# Write the Vault.OS ISO to a USB stick. Refuses SATA/NVMe and mounted system disks.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
VER="$(tr -d '\n' <"$ROOT/overlay/VERSION")"
ISO="${1:-$ROOT/iso/out/vaultos-${VER}-x86_64.iso}"
# Stable id for the 57.6G "General USB Flash Disk" used on this machine.
DEV="${2:-/dev/disk/by-id//dev/disk/by-id/usb-STICK}"

die() { echo "write-usb: $*" >&2; exit 1; }

[[ -f "$ISO" ]] || die "missing ISO $ISO (build with iso/build.sh)"
[[ -e "$DEV" ]] || die "device $DEV not present — plug in the USB stick"

if [[ "$(id -u)" -ne 0 ]]; then
  export DISPLAY="${DISPLAY:-:0}"
  export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
  export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
  if command -v pkexec >/dev/null 2>&1; then
    exec pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" \
      DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
      "$0" "$ISO" "$DEV"
  fi
  die "need root (pkexec)"
fi

real="$(readlink -f "$DEV")"
[[ -b "$real" ]] || die "$DEV is not a block device (resolved $real)"
case "$real" in
  /dev/sda|/dev/sdb|/dev/sda[0-9]*|/dev/sdb[0-9]*) die "refusing system disk $real" ;;
  /dev/nvme*|/dev/mmcblk*) die "refusing $real" ;;
esac

# Whole disk only, never a partition.
if [[ "$real" =~ [0-9]$ && "$real" != /dev/sd*[a-z] ]]; then
  die "give the whole USB disk, not a partition ($real)"
fi
[[ "$real" =~ ^/dev/sd[a-z]$ ]] || die "expected /dev/sdX, got $real"

tran="$(lsblk -no TRAN "$real" 2>/dev/null | head -1)"
rmflag="$(lsblk -no RM "$real" 2>/dev/null | head -1)"
model="$(lsblk -no MODEL "$real" 2>/dev/null | head -1)"
[[ "$tran" == "usb" ]] || die "$real transport is '$tran' (need usb)"
[[ "$rmflag" == "1" ]] || die "$real is not removable"
# Must not hold the running OS.
while read -r mp; do
  [[ -z "$mp" ]] && continue
  case "$mp" in
    /|/boot|/home) die "$real has $mp mounted — abort" ;;
  esac
done < <(lsblk -nr -o MOUNTPOINT "$real")

isosize="$(stat -c %s "$ISO")"
disksize="$(blockdev --getsize64 "$real")"
(( isosize < disksize )) || die "ISO ($isosize) does not fit on $real ($disksize)"

echo "ISO    $ISO ($(numfmt --to=iec "$isosize"))"
echo "USB    $DEV -> $real  model='$model' tran=$tran"
echo "This erases $real (current Arch ISO on the stick, if any)."
# Unmount any partitions, then copy.
lsblk -nr -o MOUNTPOINT "$real" | while read -r mp; do
  [[ -n "$mp" ]] && umount -f "$mp" || true
done
sync
dd if="$ISO" of="$real" bs=4M conv=fsync oflag=direct status=progress
sync
blockdev --rereadpt "$real" || true
echo "wrote $ISO -> $real"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$real"
file -s "$real" | head -1

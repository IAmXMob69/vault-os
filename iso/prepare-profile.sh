#!/usr/bin/env bash
# Build iso/profile from archiso releng + Vault.OS overlay. Does not touch /boot.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
RELENG=/usr/share/archiso/configs/releng
PROFILE="$ROOT/iso/profile"
[[ -d "$RELENG" ]] || { echo "install archiso first" >&2; exit 1; }

rm -rf "$PROFILE"
cp -a "$RELENG" "$PROFILE"

# --- identity. airootfs is copied after pacstrap, so these replace Arch stock
# on the live medium. vaultos-firstboot still applies them if they are missing. ---
install -m 0644 "$ROOT/iso/airootfs/etc/hostname" "$PROFILE/airootfs/etc/hostname"
install -m 0644 "$ROOT/iso/airootfs/etc/motd" "$PROFILE/airootfs/etc/motd"
install -m 0644 "$ROOT/iso/airootfs/etc/issue" "$PROFILE/airootfs/etc/issue"
install -m 0644 "$ROOT/overlay/identity/os-release" "$PROFILE/airootfs/etc/os-release"
install -m 0644 "$ROOT/overlay/identity/lsb-release" "$PROFILE/airootfs/etc/lsb-release"

# --- vaultos tree inside the live root ---
install -d "$PROFILE/airootfs/usr/lib/vaultos/bin" \
  "$PROFILE/airootfs/usr/lib/vaultos/libexec" \
  "$PROFILE/airootfs/usr/lib/vaultos/overlay/identity" \
  "$PROFILE/airootfs/usr/lib/vaultos/overlay/packages" \
  "$PROFILE/airootfs/usr/lib/systemd/system" \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants" \
  "$PROFILE/airootfs/usr/local/bin" \
  "$PROFILE/airootfs/usr/bin"
install -m 0755 "$ROOT/bin/vaultos" "$PROFILE/airootfs/usr/lib/vaultos/bin/vaultos"
install -m 0755 "$ROOT/overlay/identity-apply.sh" "$PROFILE/airootfs/usr/lib/vaultos/overlay/identity-apply.sh"
install -m 0644 "$ROOT/overlay/VERSION" "$PROFILE/airootfs/usr/lib/vaultos/overlay/VERSION"
install -m 0644 "$ROOT/overlay/README.md" "$PROFILE/airootfs/usr/lib/vaultos/overlay/README.md"
install -m 0644 "$ROOT/overlay/identity/"* "$PROFILE/airootfs/usr/lib/vaultos/overlay/identity/"
install -m 0644 "$ROOT/overlay/packages/"* "$PROFILE/airootfs/usr/lib/vaultos/overlay/packages/"
install -m 0755 "$ROOT/overlay/libexec/"*.sh "$PROFILE/airootfs/usr/lib/vaultos/libexec/"
install -m 0644 "$ROOT/overlay/systemd/"*.service "$PROFILE/airootfs/usr/lib/systemd/system/"
ln -sfn /usr/lib/vaultos/bin/vaultos "$PROFILE/airootfs/usr/bin/vaultos"
ln -sfn /usr/lib/systemd/system/vaultos-core.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/vaultos-core.service"
ln -sfn /usr/lib/systemd/system/vaultos-firstboot.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/vaultos-firstboot.service"
install -m 0755 "$ROOT/iso/airootfs/usr/local/bin/vaultos-install" \
  "$PROFILE/airootfs/usr/local/bin/vaultos-install"

# --- profiledef ---
sed -i \
  -e 's/^iso_name=.*/iso_name="vaultos"/' \
  -e 's/^iso_label=.*/iso_label="VAULTOS"/' \
  -e 's|^iso_publisher=.*|iso_publisher="Vault.OS <https://github.com/IAmXMob69/vault-os>"|' \
  -e 's|^iso_application=.*|iso_application="Vault.OS Live/Install"|' \
  -e 's/^iso_version=.*/iso_version="1.5.19"/' \
  -e 's/^install_dir=.*/install_dir="vaultos"/' \
  "$PROFILE/profiledef.sh"
# append file_permissions for installer
if ! grep -q vaultos-install "$PROFILE/profiledef.sh"; then
  sed -i 's|  \["/usr/local/bin/livecd-sound"\]="0:0:755"|  ["/usr/local/bin/livecd-sound"]="0:0:755"\n  ["/usr/local/bin/vaultos-install"]="0:0:755"\n  ["/usr/lib/vaultos/bin/vaultos"]="0:0:755"|' \
    "$PROFILE/profiledef.sh"
fi

# --- UEFI loader titles ---
cat >"$PROFILE/efiboot/loader/loader.conf" <<'EOF'
timeout 15
default 01-vaultos-live.conf
beep on
EOF
cat >"$PROFILE/efiboot/loader/entries/01-vaultos-live.conf" <<'EOF'
title    Vault.OS Live
sort-key 01
linux    /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
initrd   /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
options  archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% console=tty0 console=ttyS0,115200
EOF
cat >"$PROFILE/efiboot/loader/entries/02-vaultos-install.conf" <<'EOF'
title    Install Vault.OS
sort-key 02
linux    /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
initrd   /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
options  archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% vaultos.install=1 console=tty0 console=ttyS0,115200
EOF
cat >"$PROFILE/efiboot/loader/entries/03-uefi-shell.conf" <<'EOF'
title    UEFI Shell
sort-key 03
efi      /shellx64.efi
EOF
rm -f "$PROFILE/efiboot/loader/entries/01-archiso-linux.conf" \
      "$PROFILE/efiboot/loader/entries/02-archiso-speech-linux.conf"

# --- syslinux ---
sed -i 's/MENU TITLE Arch Linux/MENU TITLE Vault.OS/' "$PROFILE/syslinux/archiso_head.cfg"
cat >"$PROFILE/syslinux/archiso_sys-linux.cfg" <<'EOF'
LABEL vaultos
TEXT HELP
Boot the Vault.OS live medium (Arch derivative).
ENDTEXT
MENU LABEL Vault.OS Live
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% console=tty0 console=ttyS0,115200

LABEL vaultosinstall
TEXT HELP
Boot Vault.OS live and hint the installer (still requires confirmation).
ENDTEXT
MENU LABEL Install Vault.OS
LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% vaultos.install=1 console=tty0 console=ttyS0,115200
EOF

# --- grub ---
sed -i \
  -e 's/default=archlinux/default=vaultos-live/' \
  -e 's/menuentry "Arch Linux install medium (%ARCH%, ${archiso_platform})" --class arch --class gnu-linux --class gnu --class os --id '\''archlinux'\''/menuentry "Vault.OS Live" --class arch --class gnu-linux --class gnu --class os --id '\''vaultos-live'\''/' \
  -e 's/menuentry "Arch Linux install medium with speakup screen reader (%ARCH%, ${archiso_platform})" --hotkey s --class arch --class gnu-linux --class gnu --class os --id '\''archlinux-accessibility'\''/menuentry "Install Vault.OS" --class arch --class gnu-linux --class gnu --class os --id '\''vaultos-install'\''/' \
  "$PROFILE/grub/grub.cfg"
# install entry should pass vaultos.install=1
python3 - <<'PY'
from pathlib import Path
p=Path("/iso/profile/grub/grub.cfg")
t=p.read_text()
# second linux line (install) add flag if we replaced accessibility entry
old="id 'vaultos-install' {\n    set gfxpayload=keep\n    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% accessibility=on"
new="id 'vaultos-install' {\n    set gfxpayload=keep\n    linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% vaultos.install=1 console=tty0 console=ttyS0,115200"
if old in t:
    t=t.replace(old,new,1)
t=t.replace(
    "linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID%\n    initrd",
    "linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% console=tty0 console=ttyS0,115200\n    initrd",
    1)
p.write_text(t)
print('grub.cfg patched')
PY

if ! grep -qx 'iptables' "$PROFILE/packages.x86_64"; then
  echo iptables >>"$PROFILE/packages.x86_64"
fi

echo "profile ready: $PROFILE"

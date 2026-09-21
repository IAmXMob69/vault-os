# Vault.OS ISO (Phase 5)

Releng derivative. **Does not install to the host disk.**

```bash
# needs archiso (official extra)
./iso/prepare-profile.sh
./iso/build.sh          # pkexec mkarchiso
```

Output: `iso/out/vaultos-<version>-x86_64.iso`

A freshly installed disk does **not** pre-create a login user. First boot
asks hostname, timezone, locale, keyboard, optional Wi-Fi, then username
and password (twice). LightDM starts only after `/var/lib/vaultos/firstboot-done`
exists. Wizard tests: `./iso/test-firstboot.sh` (fake rootfs, no host writes).

QEMU smoke (serial, 1536M — keep the host bootable). Direct-kernel live boot; ISO still supplies the squashfs. Proven 2026-09-20: issue `Vault.OS live`, hostname `vaultos-live`, getty on ttyS0.

```bash
chmod +x iso/qemu-smoke.sh
./iso/qemu-smoke.sh
```

UEFI firmware menu (15s timeout, entries Vault.OS Live / Install Vault.OS / UEFI Shell):

```bash
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/vaultos-ovmf-vars.fd
qemu-system-x86_64 -enable-kvm -m 1536 -nographic \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/tmp/vaultos-ovmf-vars.fd \
  -cdrom iso/out/vaultos-1.5.19-x86_64.iso -boot d
```

Installer:

```text
vaultos-install 'INSTALL TO /dev/DISK CONFIRMED'
```

Anything else is refused. Do not run that on this machine unless you type that phrase yourself.

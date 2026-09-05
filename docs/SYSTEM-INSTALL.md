# System install (sudo)

User-session theming does not need root. Greeter and Plymouth do.

1. Read [`BOOT.md`](../BOOT.md).
2. Install staged LightDM GTK greeter conf and Plymouth theme from `source/lightdm/` and `source/plymouth/`.
3. Do **not** restart LightDM until the operator confirms.

Optional helper (if present): `bin/vault-os-install-system-theme`.

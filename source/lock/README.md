# Lock and logout plates

Unlock dialog and session-logout styling for Vault.OS. The spinning Arch mark on the saver surface is separate; this plate stays opaque over it.

## Behavior

- Opaque `vault-black` plate, bevel stamp, Share Tech Mono
- Focus ring 2px phosphor; controls at least 28px tall
- Amber is warning only — never the dialog frame

## Files

| Path | Role |
|------|------|
| `lock.css` | Imported by `~/.themes/Vault.OS/gtk-3.0/gtk.css` |
| `SCREENSAVER.md` | How idle lock and Arch spin are wired |
| `ERRORS.md` | Internal notes |

Greeter install (needs root once) is under `../lightdm/`.

# Lock and logout plates

Unlock dialog and session-logout styling for Vault.OS. The spinning Arch mark on the saver is separate; this plate stays opaque over it.

## Behavior

- Opaque vault-black plate with a bevel stamp and Share Tech Mono
- Focus ring is 2px phosphor; controls are at least 28px tall
- Amber is for warnings only — never the dialog frame

## Files

| Path | Role |
|------|------|
| `lock.css` | Imported by `~/.themes/Vault.OS/gtk-3.0/gtk.css` |
| `SCREENSAVER.md` | How idle lock and Arch spin are wired |

Greeter install (needs root once) is under `../lightdm/`.

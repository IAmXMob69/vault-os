# Terminal control plane

`vault-os ensure-theme` / apply must call `vaultos-terminal-phosphor` using
`~/.config/Vault.OS/terminal-phosphor` (default `reduced`). Do not hardcode
legacy PipBoy terminal colors (`#33FF6A`, `#070C09`) in the control plane.

Fallback xfconf values, if the dial is missing, must match `tokens.css` ANSI 0–15.

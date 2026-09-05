# Terminal and the control plane

`vault-os ensure-theme` (and apply) should call `vaultos-terminal-phosphor` with the mode in `~/.config/Vault.OS/terminal-phosphor` (default `reduced`).

If the dial script is missing, fall back to the same ANSI 0–15 values as `tokens.css`. Avoid hardcoding older PipBoy terminal colors (`#33FF6A`, `#070C09`) in the control plane.

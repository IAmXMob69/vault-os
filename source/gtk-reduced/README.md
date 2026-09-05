# Vault.OS-Reduced

High-contrast GTK theme with the CRT effects dialed down. Tokens here match `tokens-reduced.css` at the repo root.

Turn it on:

```
xfconf-query -c xsettings -p /Net/ThemeName -s Vault.OS-Reduced
```

Set `THEME_NAME=Vault.OS-Reduced` in `~/.config/fallout-nv/vault-os.conf` so `ensure-theme` keeps it, and use the matching `Vault.OS-Reduced` window theme. For the terminal, run `vaultos-terminal-phosphor reduced` or `clear`.

# Vault.OS-Reduced

High-contrast GTK theme with reduced CRT effects. Token file in this tree mirrors `tokens-reduced.css` at the repo root (hotter phosphor, lifted contrast, glow/bloom off).

Enable:

```
xfconf-query -c xsettings -p /Net/ThemeName -s Vault.OS-Reduced
```

Also set `THEME_NAME=Vault.OS-Reduced` in `~/.config/fallout-nv/vault-os.conf` so `ensure-theme` keeps it. Pair the window manager theme to `Vault.OS-Reduced` when Reduced is active. Terminal phosphor: `vaultos-terminal-phosphor reduced` or `clear`.

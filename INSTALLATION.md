# Installation Troubleshooting

## Common Issues

### Permission Errors on ~/.themes or ~/.icons

**Error:** `Permission denied` when installing themes

**Fix:**
```bash
chmod 700 ~/.themes ~/.icons
chmod 700 ~/.local/share/backgrounds/Vault.OS
./bin/vault-os install
```

### XFCE Not Detecting Theme

**Issue:** Theme appears in settings but doesn't apply

**Fix:**
1. Verify files are in correct locations:
   ```bash
   ls -la ~/.themes/Vault.OS
   ls -la ~/.icons/Vault.OS
   ```

2. Clear XFCE theme cache:
   ```bash
   rm -rf ~/.cache/xfce4/xfwm4/
   pkill -f xfwm4
   ```

3. Re-run installation:
   ```bash
   ./bin/vault-os ensure-theme
   ```

### Missing Fonts

**Issue:** "Share Tech Mono" or "Terminus" fonts not found

**Fix on Arch:**
```bash
sudo pacman -S extra/otf-overpass extra/terminus-font
yay -S aur/ttf-share-tech-mono aur/ttf-ultimate-oldschool-pc-font-pack
```

**Fix on Ubuntu/Debian:**
```bash
sudo apt install fonts-overpass fonts-terminus
# For Share Tech Mono, use Google Fonts or Nerd Fonts
```

### Script Errors During Installation

**Issue:** Installation script fails with cryptic error

**Fix:**
1. Check for shell errors:
   ```bash
   bash -n ./bin/vault-os  # syntax check
   ```

2. Run with debug output:
   ```bash
   bash -x ./bin/vault-os install
   ```

3. Verify Git repo state:
   ```bash
   git status
   git log -1 --oneline
   ```

### Screensaver Not Working

**Issue:** Lock screen or screensaver theme not appearing

**Fix:**
```bash
# Install system components
sudo ./source/xfce4-screensaver/install-system.sh

# Set lock command
xfce4-screensaver-command --lock

# Verify installation
ls -la ~/.local/bin/vaultos-*
```

## Getting Help

If issues persist:
1. Check XFCE logs:
   ```bash
   journalctl -u xfce4-session --no-pager
   ```

2. Report on GitHub with:
   - Output of `./bin/vault-os status`
   - Your OS/distribution
   - Full error message with `bash -x` output

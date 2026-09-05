# TRM-05 terminal stack upgrade

## Drift root cause
`vault-os` (`Projects/vault-os/bin/vault-os`) still hardcoded PipBoy terminal:
`#33FF6A` / `#070C09` palette. Conf said Vault.OS; apply path undid CANON.

## Fix (1.5.2-trm05)
`vault-os` apply now calls `vaultos-terminal-phosphor` with mode from
`~/.config/Vault.OS/terminal-phosphor` (default `reduced`).
Fallback xfconf uses CANON `#1AFF6B` / `#070807` ANSI map.

## Single source of truth
| Path | Role |
|------|------|
| `vaultos-terminal-phosphor` | Dial: full / reduced / clear |
| `~/Vault.OS/source/xfce4-terminal/` | terminalrc.* + terminal.*.css + A11Y.md |
| `vaultos-lock` | Session reinforce → dial |
| `vault-os` apply | Session start → dial |

No package changes. Reopen Terminal after mode switch.

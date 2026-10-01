# CONTINUE

## Open — code improvement pass

Improve Arch XFCE / Vault.OS across the stack. Master Coding Bot can pull any lane; specialists still own craft depth.

| Lane | Focus |
|------|--------|
| Design bar / greeter staging | DESIGN.md quality bar; Plymouth/LightDM staged only |
| GTK CANON + Reduced | gtk.css densify; CssProvider clean; HUD overlay only |
| xfwm doors | XPMs/themerc both packs; source ≡ themes |
| Panel / notify / unlock | lock.css contrast; professional whisker sizes |
| Terminal + Arch spin | phosphor dial; no `#33FF6A`; install seeds terminalrc |
| Icons / cursors | vault-dock + cache on install; no Mojave pins |
| Control plane | `vault-os` install / ensure-theme / status / doctor |

## Open — human sudo later

- Greeter system files are installed (`/usr/share/themes|icons|backgrounds/Vault.OS` + lightdm-gtk-greeter.conf). **Do not** `systemctl restart lightdm` until you want to end the session — next logout shows it.
- Plymouth still staged only — package not installed; see [`BOOT.md`](BOOT.md).
- Optional fonts system-wide beyond Share Tech Mono for greeter.

## C++ ports (branch `cpp-ports`, not merged, not pushed)

Every native tool keeps its script as the fallback: if the binary is not
built, the old path runs. `make -C src check-deps` shows what will build;
`make -C src install PREFIX=...` skips a tool whose deps are missing.

- `src/common.mk` + header-only `src/libvaultos/` (paths, phosphor tokens
  `#1AFF6B` / Reduced `#66FF9C`, flock instance lock). New tools include it;
  older tool Makefiles are left alone and checked from `src/Makefile`.
- Lock/idle saver: `vaultos-lockmark` (landed on main by another worker).
  This branch makes the `screensavers-vaultos-arch-spin` wrapper fall back to
  `vaultos-lockmark`, then Python `vaultos-spin-lock`, when the runner is
  missing. Python `vaultos-spin-lock` is marked fallback.
- `vaultos-xq`: batch libxfconf client (`set`/`get`/`reset`, stdin batches,
  `--dry-run`, skips same-value writes). `vault-os` `xq_set` uses it when it is
  on PATH; ensure-panel and the ensure-theme pin run go out as one batch each
  (`xq_begin`/`xq_commit`). `VAULTOS_XQ=` turns it off.
- `vaultos-close-all`: libwnck-3 + libnotify port of `vault-os-close-all`,
  with `--dry-run`. The Python script execs it when installed.
- `vaultos-mark`: `--logo --period --frame-ms --rotate --bare --size`, so it
  covers the Vault 111 overlay (`bin/vaultos-spin-111-run`) and the
  `vaultos-spin-arch` Python fallback. Static default unchanged.
- `vaultos-chromium-theme`: nlohmann_json port of `vault-os-chromium-theme`,
  byte-identical Preferences output apart from install timestamps.
- `install.sh` builds all of `src/` with per-tool skip.

Needs the maintainer before going live: merging, `make -C src install` into
`~/.local/bin`, pointing the Hidden `vaultos-spin-111` autostart at
`vaultos-spin-111-run`, and a real lock/idle test of the saver on `:0`.

## Landed

- `vault-os` 1.5.17 — install path + greeter system installer targets Vault.OS
- CANON + Reduced themes, icons, tokens, `screensavers-vaultos-arch-spin`
- Public README without `ERRORS.md` on the front door
- Door themerc hexes on tokens (`#1AFF6B` / Reduced `#66FF9C`)

See [`DESIGN.md`](DESIGN.md).

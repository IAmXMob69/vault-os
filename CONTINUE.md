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
| Control plane | ~~`vault-os` install / ensure-theme / status / doctor~~ landed on branch `control-plane-doctor` (unpushed); see below |

## Control plane — `vault-os doctor` / `vault-os lint` (branch `control-plane-doctor`, unpushed)

- `vault-os doctor` is read-only now: status + live rules + repo lint, exit 1 on any FAIL. It no longer runs apply / ensure-* or restarts xfce4-panel (it used to `xfce4-panel -r` a healthy panel on every run).
- `vault-os doctor --fix` (and `repair` / `fix`) is the repair pass; it restarts xfce4-panel only when it is dead or panel-2 length is bad, then runs the read-only doctor.
- `vault-os lint [PATH]` runs the repo checks with no session (CI-safe): palette (banned 33FF6A / 44FF3D), `!important` and web-only CSS in GTK css, gtk-3.0 + gtk-3.20, source ≡ themes (GTK warn, xfwm fail, mixed XPMs), terminal scrollbar, saver desktop + id + no floaters hijack, spin static by default, ERRORS.md ≡ source/, bash -n.
- `~/.local/bin/vault-os` points at the main checkout, so the live CLI changes only after this branch is merged there.

### Findings for other lanes (from the first doctor run)

- **TRM-05:** `config/xfce4/terminal/terminalrc` still has the PipBoy palette (`ColorForeground`, palette, `TabActivityColor` on the banned 33FF6A; well 070C09), and `install.sh` copies it to the live `terminalrc`. This is the only lint FAIL. Fix: seed from `source/xfce4-terminal/terminalrc.reduced` (as `vault-os install` does), or retoken.
- **TRM-05:** `vaultos-terminal-phosphor` `apply_css` also writes `$SRC/terminal.css`, which is the tracked `source/xfce4-terminal/terminal.css` in the checkout. Any mode other than `reduced` dirties the repo.
- **TRM-05 / Genius (sudo):** the installed `/usr/lib/xfce4-screensaver/vaultos-arch-spin` is the old wrapper with a hard-coded home path. It differs from `source/xfce4-screensaver/vaultos-arch-spin.wrapper`. Refresh it with `install-system.sh` when sudo is OK. The system desktop is fine: no `Hidden=`, Exec/TryExec on the wrapper, floaters stock.
- **GTK-02 / HUD-04:** source/ and themes/ have drifted on `hud.css` (CANON + Reduced, gtk-3.0 + gtk-3.20) and on Reduced `lock.css`. Reduced gtk-3.20 `terminal.css` has also drifted (TRM-05 owns the terminal.css trees).
- **GTK-02 / a11y:** `tokens-reduced.css` ≠ `source/tokens-reduced.css`. The source copy has the `reduced_phosphor` sentinel and comments.
- **XWM-03:** clean. source ≡ themes for both packs, 60 XPMs each with hex + symbolic colors, and live `~/.themes` ≡ repo.
- **ICO-06:** `icons/Vault.OS` is clean.
- **VDS-01 call:** the legacy PipBoy-NV app themes (`config/vscode`, `config/discord`, `config/firefox`, `config/Kvantum/PipBoy-NV`, `themes/PipBoy-NV`, …) still use 33FF6A. Lint warns only. `install.sh` still installs the Firefox userChrome and the Discord theme from them.
- Live `~/.themes/Vault.OS` gtk.css matches the unpushed local `main` (GTK motion commit), not `origin/main`. This is expected until that is pushed.

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

## C++ first-boot wizard (branch `cpp-firstuser`, not merged, not pushed)

- `src/vaultos-firstuser` now covers everything the shell wizard does:
  answers file (root:root 0600, tightened/refused, shredded on success, kept
  0600 on failure), boot options `vaultos.firstboot=skip|PATH`, hostname
  (+ /etc/hosts), timezone with validation and search, locale (locale.gen),
  keymap (vconsole + X11), Wi-Fi (`skip_wifi`, nmcli/iwctl), reset-only for a
  locked user, rollback on any failure or signal, typeahead drain, `--dry-run`,
  and a root check for real runs. Builds with `common.mk` (`-lcrypt`).
- `iso/test-firstboot.sh` runs the same scenarios against both wizards plus a
  tree/mode/log diff (`VAULTOS_TEST_WIZARDS=sh|cxx` to run one).
- Shell wizard fixes found on the way: bad `hostname=` answer looped forever,
  real-mode Wi-Fi detection always said "device found", no root check, and
  test-mode rollback left the fake shadow 0644.
- Not switched: the ISO and `vaultos firstboot --run` still run the `.sh`.

## Native doctor / lint (branch `cpp-tools`, not merged, not pushed)

- `src/vaultos-doctor`: `lint [PATH]`, `doctor`, `status`, read-only. Output
  and exit codes are byte-identical to the bash checks (tested by
  `src/vaultos-doctor/test-parity.sh` on clean and deliberately broken copies
  of the tree, plus a fake HOME with a stub xfconf-query for the doctor).
- `bin/vault-os` execs it for `lint` and read-only `doctor` when
  `vaultos-doctor` is on PATH (`VAULTOS_DOCTOR=` turns it off). `doctor --fix`
  and everything else stays bash. Live only after merge + `make -C src install`.
- Fixed on the way: `has_share_tech_mono` could report MISSING because
  `grep -q` + pipefail SIGPIPE'd `fc-list`.

## Landed

- `vault-os` 1.5.17 — install path + greeter system installer targets Vault.OS
- CANON + Reduced themes, icons, tokens, `screensavers-vaultos-arch-spin`
- Public README without `ERRORS.md` on the front door
- Door themerc hexes on tokens (`#1AFF6B` / Reduced `#66FF9C`)

See [`DESIGN.md`](DESIGN.md).

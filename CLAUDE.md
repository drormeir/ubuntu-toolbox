# ubuntu-toolbox

Maintenance scripts and system notes for one Ubuntu 24.04 (KDE Plasma) laptop.
Shell only. No build, no test suite, no package manager.

## Things you cannot see from the code

- `~/bin` is a **symlink to `bin/` in this repo**. Editing `bin/foo.sh` here
  changes what runs as `foo.sh` on `$PATH`. There is no install or copy step.
- `~/.bashrc.local` is a symlink to `shell/bashrc.local`, same deal.
- Paths are hardcoded to `/home/dror` throughout, in the scripts and in the
  `.service` units. Do not replace them with `$HOME`: the updaters run as root
  from systemd, where `$HOME` is `/root`.
- The `.service` units live in `bin/` but are **not** run from there. They are
  copied to `/etc/systemd/system/`. Editing a unit here has no effect until it
  is copied over and `systemctl daemon-reload` runs.
- The updaters assume root. They `chown dror:dror` what they download so the
  files are usable from a normal login.

## Conventions

- Every script is `#!/bin/bash` with `set -e`.
- Scripts are mode 755. A new script in `bin/` needs `chmod +x`, or it silently
  fails as "permission denied" on `$PATH`.
- The once-per-day updaters guard themselves with a marker file under
  `~/.cache/`. Their names (`chrome_updater_last_run`, `cursor_updater_last_run`,
  `zoom_updater_last_run`) are load-bearing — renaming one resets the state and
  causes a redundant download.
- Updaters append to `~/.cache/updates.log`.

## Before changing an updater

Compare versions *before* downloading. `update-cursor.sh` pulls a ~300 MB
`.deb`; the version check exists to avoid that download, not to avoid the
install.

## Docs

- `docs/DISK_ENCRYPTION_LUKS.md` — LUKS notes for this machine.
- `docs/wifi-doctor/` — full docs for `bin/wifi-doctor.sh`, including its own
  `CLAUDE.md` from when it was a separate repo. That file governs
  `wifi-doctor.sh` only.

`wifi-doctor.sh` is deliberately self-contained and read-only. Keep it that
way: it is meant to be copied to another machine and run, and it prints fixes
rather than applying them.

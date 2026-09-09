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

## This repo is public. There is a private one beside it.

Anything that names this machine, or the work done on it, belongs in the
private repo at `~/.private` (`~/projects/ubuntu-toolbox-private`), not here.
That means project or client aliases, `~/venv/...` and `~/projects/...` paths,
and notes on hardware, partitions or security posture.

The two meet at one block, the last in `shell/bashrc.local`:

```bash
if [ -f ~/.bashrc.private ]; then
    . ~/.bashrc.private
fi
```

Keep it an `if`. As `[ -f ... ] && . ...` the file returns 1 when the private
half is absent, which aborts any script that sources it under `set -e`.

Never remove the guard, and never add anything else here that
names the private repo. This repo must work on a machine that has no private
half. `~/.private/bin` goes on `$PATH` from `bashrc.private`, not from
`bashrc.local`.

The hardcoded `/home/dror` paths are a portability problem, not a privacy one.
Do not move a script to the private repo on account of them.

## Docs

- `docs/wifi-doctor/` — full docs for `bin/wifi-doctor.sh`, including its own
  `CLAUDE.md` from when it was a separate repo. That file governs
  `wifi-doctor.sh` only.

`wifi-doctor.sh` is deliberately self-contained and read-only. Keep it that
way: it is meant to be copied to another machine and run, and it prints fixes
rather than applying them.

# ubuntu-toolbox

Maintenance scripts for an Ubuntu 24.04 (KDE Plasma) desktop. Shell only. No
build, no test suite, no package manager.

**This is a public repo meant for other people to use.** That is the constraint
behind most of what follows. It was originally one person's dotfiles and still
reads that way in places; when in doubt, write for a stranger's machine.

## Things you cannot see from the code

- `~/bin` is a **symlink to `bin/` in this repo**. Editing `bin/foo.sh` here
  changes what runs as `foo.sh` on `$PATH`. There is no install or copy step.
- `~/.bashrc.local` is a symlink to `shell/bashrc.local`, same deal.
- Nothing may hardcode a username or a checkout path. `bin/toolbox-env.sh`
  resolves both; see below.
- `systemd/*.service.in` are **templates**, not units. `install.sh` substitutes
  `@BIN@` and writes the result to `/etc/systemd/system/`. Editing a template
  has no effect until install.sh runs again and `systemctl daemon-reload` fires.
- The updaters assume root, because they install packages.

## Never hardcode a user or a path

The updaters run as root but write into a desktop user's `~/Downloads` and
`~/.cache`. `bin/toolbox-env.sh` is sourced at the top of each one and exports
`TOOLBOX_USER`, `TOOLBOX_HOME`, `TOOLBOX_DOWNLOADS`, `TOOLBOX_CACHE`,
`TOOLBOX_LOG` and `TOOLBOX_BIN`, plus an `own()` helper that hands a file to
that user and no-ops when unprivileged.

Use those. In particular:

- `own "$FILE"`, never `chown someuser:someuser "$FILE"`.
- `"$TOOLBOX_BIN/install-deb.sh"`, never an absolute path to another script.
- Do not substitute `$HOME` for `$TOOLBOX_HOME`. Under systemd the scripts run
  as root, where `$HOME` is `/root` — that is the bug this exists to prevent.

`toolbox-env.sh` resolves the user from `$TOOLBOX_USER`, then `$SUDO_USER`, then
the current user if unprivileged. Root with none of them set is a hard error on
purpose: guessing would write into `/root`.

## Conventions

- Every script is `#!/bin/bash` with `set -e`.
- Scripts are mode 755. A new script in `bin/` needs `chmod +x`, or it silently
  fails as "permission denied" on `$PATH`. `install.sh` chmods them too.
- A new updater sources `toolbox-env.sh` on the line after `set -e`, gets a
  `systemd/<name>.service.in` template if it should run at boot, and a row in
  the README's script table.
- The once-per-day updaters guard themselves with a marker file under
  `~/.cache/`. Their names (`chrome_updater_last_run`, `cursor_updater_last_run`,
  `zoom_updater_last_run`) are load-bearing — renaming one resets the state and
  causes a redundant download.
- Updaters append to `~/.cache/updates.log`.

## Before changing an updater

Compare versions *before* downloading. `update-cursor.sh` pulls a ~300 MB
`.deb`; the version check exists to avoid that download, not to avoid the
install.

## There is a private repo beside this one

Anything that names the author's machine, or the work done on it, belongs in the
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

Never remove the guard, and never add anything else here that names the private
repo. Most people cloning this have no private half at all. `~/.private/bin`
goes on `$PATH` from `bashrc.private`, not from `bashrc.local`.

## Docs

- `docs/wifi-doctor/` — full docs for `bin/wifi-doctor.sh`, including its own
  `CLAUDE.md` from when it was a separate repo. That file governs
  `wifi-doctor.sh` only.

`wifi-doctor.sh` is deliberately self-contained and read-only. Keep it that
way: it is meant to be copied to another machine and run, and it prints fixes
rather than applying them.

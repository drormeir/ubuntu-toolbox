# ubuntu-toolbox

Personal Ubuntu 24.04 (KDE Plasma) laptop setup: maintenance shell scripts and
system notes, kept under version control so they survive a reinstall.

## Layout

```
ubuntu-toolbox/
├── bin/                          # the scripts + their systemd units; ~/bin points here
├── shell/
│   └── bashrc.local              # symlinked to ~/.bashrc.local
├── docs/
│   └── wifi-doctor/              # docs for bin/wifi-doctor.sh (see below)
├── CLAUDE.md                     # notes for Claude Code
└── README.md
```

Docs stay out of `bin/` so that `~/bin` — which is on `$PATH` — holds only
things that are run. The `.service` units are the exception; see below.

## `~/bin` is a symlink into this repo

The scripts and the systemd units reference each other by absolute path
(`/home/dror/bin/...`), and `~/bin` is on `$PATH`, so the repo is the real
location and `~/bin` is a symlink to `bin/` here:

```bash
mv ~/bin ~/bin.backup
ln -s ~/projects/ubuntu-toolbox/bin ~/bin
chmod +x ~/projects/ubuntu-toolbox/bin/*.sh
```

Nothing else has to change: `/home/dror/bin/update-zoom.sh` still resolves.

## `shell/`

Files symlinked into `$HOME`, stored here without the leading dot:

```bash
ln -s ~/projects/ubuntu-toolbox/shell/bashrc.local ~/.bashrc.local
```

`~/.bashrc` sources `~/.bashrc.local`, which puts `~/bin` on `$PATH` and defines
the `update_all` alias. That alias chains the system updates — apt, grub, snap,
firmware — with `chrome-sources-fix.sh`, `update-zoom.sh` and
`nvidia-version-check.sh`. The chrome and cursor updaters are not in it; they
run from their systemd units at boot.

## The private half

Anything naming this specific machine — or the work done on it — lives in a
separate private repo, symlinked at `~/.private`. That is where the
project aliases and the disk-encryption notes went.

The two repos meet at one place, the last block in `shell/bashrc.local`:

```bash
if [ -f ~/.bashrc.private ]; then
    . ~/.bashrc.private
fi
```

An `if` rather than `[ -f ... ] && ...` so a missing private half does not make
this file return 1 and abort any script that sources it under `set -e`.

The guard is the contract. This repo has to keep working on a machine with no
private half, so nothing here may name anything in there — no path, no alias,
no script. `~/.private/bin` is added to `$PATH` from the private file, not
from this one.

## Scripts

| Script | What it does |
|---|---|
| `update-zoom.sh` | Downloads the latest Zoom `.deb` (once per day), installs it if newer than what's installed. |
| `update-chrome.sh` | Refreshes only the Chrome apt source, upgrades `google-chrome-stable` if a newer candidate exists. |
| `chrome-sources-fix.sh` | Re-adds `Architectures: amd64` to Chrome's `.sources` file after Chrome's postinst drops it. Called by `update-chrome.sh` and an apt hook. |
| `update-cursor.sh` | Same idea for Cursor. Cursor's own Linux updater is broken (unsigned AppImage fails validation and rolls back), so this asks Cursor's download API for the latest stable `.deb`, compares versions *before* downloading (~300 MB), and installs when newer. |
| `install-deb.sh` | `dpkg -i` a package, offer `apt-get install -f` on failure. Shared helper. |
| `select-apt-mirror.sh` | Times a list of Ubuntu mirrors (Israel first, then EU) and points `ubuntu.sources` at the fastest reachable one. |
| `nvidia-version-check.sh` | Compares the loaded NVIDIA kernel module against the on-disk version — catches "driver updated, needs reboot". Exit 0 match / 1 mismatch / 2 error. |
| `wifi-doctor.sh` | Diagnoses the current connection *toward a chosen server* (path MTU, IPv6 health, resets) and prints the `nmcli` commands that would fix it. Read-only; changes nothing. Full docs in [`docs/wifi-doctor/`](docs/wifi-doctor/). |
| `os-info.sh` | `cat /etc/os-release`. |
| `desktop-info.sh` | Display manager, OpenGL renderer, desktop session vars, icon theme, OS release. |
| `toggle-sddm-keyboard.sh` | Toggles the SDDM on-screen keyboard at the login screen. |

## systemd units

`update-zoom.service`, `update-chrome.service` and `update-cursor.service` each
run the matching script **once at boot** — they are not daily timers; the "once
per day" guard lives in the scripts themselves. The three units are identical
apart from the `ExecStart` path. They live in `bin/` next to the scripts they
call, and install to `/etc/systemd/system/`:

```bash
sudo cp ~/projects/ubuntu-toolbox/bin/update-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable update-zoom.service update-chrome.service update-cursor.service
```

The units are the one exception to "`bin/` holds only executables" — they sit
there so a unit and its script stay together.

They used to declare only `After=network-online.target`, which orders the unit
against that target but does not pull it into the boot. The script could
therefore start before the network was up, fail its connectivity probe and exit
0 silently — the reason they seemed not to work. All three units now also
declare `Wants=network-online.target`, and use `Type=oneshot` (they run to
completion and exit rather than staying resident).

This still requires `NetworkManager-wait-online.service` to be enabled, and
still only runs at boot. A `systemd` timer with `OnCalendar=daily` and
`Persistent=true` would be the way to make it genuinely daily on a laptop that
suspends rather than reboots.

## wifi-doctor

`wifi-doctor.sh` used to live in its own repo. It was folded in here; its
user guide, design rationale (`TECHNICAL_NOTES.md`), Claude Code instructions
and MIT license moved to `docs/wifi-doctor/` unchanged. It is still a
self-contained single-file tool — copy it anywhere and run it.

## Notes

- Paths are hardcoded to `/home/dror`. Adjust before using this anywhere else.
- The updaters expect root (they `chown dror:dror` what they download);
  `install-deb.sh` and a few others call `sudo` directly.
- The `.cache` marker filenames (`chrome_updater_last_run`, `cursor_updater_last_run`)
  keep their old names so the once-per-day state isn't reset.

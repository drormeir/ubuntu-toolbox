# ubuntu-toolbox

Maintenance scripts for an Ubuntu desktop: keeping Zoom, Chrome and Cursor up
to date without their own broken updaters, picking a fast apt mirror, catching
an NVIDIA driver that needs a reboot, and diagnosing a bad Wi-Fi connection.

Written for Ubuntu 24.04 on KDE Plasma, which is what it is tested on. Most of
it is plain `dpkg`/`apt` work and should hold on any Debian derivative; the two
desktop scripts (`desktop-info.sh`, `toggle-sddm-keyboard.sh`) assume SDDM.

## Install

```bash
git clone https://github.com/drormeir/ubuntu-toolbox.git ~/projects/ubuntu-toolbox
cd ~/projects/ubuntu-toolbox
./install.sh
```

Run it as yourself, not as root. It symlinks `~/bin` and `~/.bashrc.local` into
the repo, makes `bin/*.sh` executable, and appends the `~/.bashrc.local` source
line to `~/.bashrc` if it isn't there. Anything it would overwrite is renamed to
`*.backup.<timestamp>` first.

To also have the updaters run daily on their own:

```bash
./install.sh --systemd
```

That part calls `sudo`. See [systemd units and
timers](#systemd-units-and-timers) below for what it writes and why.

The repo is the real location and `~/bin` is a symlink to `bin/` — so editing a
script here changes what runs, with no install step in between.

## Scripts

| Script | What it does |
|---|---|
| `update-zoom.sh` | Downloads the latest Zoom `.deb` (at most once per day), installs it if newer than what's installed. Uses `If-Modified-Since` so an unchanged `.deb` transfers nothing. |
| `update-chrome.sh` | Refreshes only the Chrome apt source, upgrades `google-chrome-stable` if a newer candidate exists. |
| `chrome-sources-fix.sh` | Re-adds `Architectures: amd64` to Chrome's `.sources` file after Chrome's postinst drops it. Called by `update-chrome.sh` and an apt hook. |
| `update-cursor.sh` | Same idea for Cursor. Cursor's own Linux updater is broken (unsigned AppImage fails validation and rolls back), so this asks Cursor's download API for the latest stable `.deb`, compares versions *before* downloading (~300 MB), and installs when newer. |
| `install-deb.sh` | `dpkg -i` a package, offer `apt-get install -f` on failure. Shared helper. |
| `toolbox-env.sh` | Sourced by the updaters, not run. Works out whose `~/Downloads` and `~/.cache` to write to. See [Who the updaters write for](#who-the-updaters-write-for). |
| `select-apt-mirror.sh` | Times a list of Ubuntu mirrors (Israel first, then EU) and points `ubuntu.sources` at the fastest reachable one. Edit the list for your region. |
| `nvidia-version-check.sh` | Compares the loaded NVIDIA kernel module against the on-disk version — catches "driver updated, needs reboot". Exit 0 match / 1 mismatch / 2 error. |
| `wifi-doctor.sh` | Diagnoses the current connection *toward a chosen server* (path MTU, IPv6 health, resets) and prints the `nmcli` commands that would fix it. Read-only; changes nothing. Full docs in [`docs/wifi-doctor/`](docs/wifi-doctor/). |
| `os-info.sh` | `cat /etc/os-release`. |
| `desktop-info.sh` | Display manager, OpenGL renderer, desktop session vars, icon theme, OS release. |
| `toggle-sddm-keyboard.sh` | Toggles the SDDM on-screen keyboard at the login screen. |
| `set-turbo.sh` | `set-turbo.sh 1` turns CPU turbo boost on, `0` turns it off, until the next reboot. Calls `sudo`. |
| `get-turbo.sh` | Prints `1` if CPU turbo boost is on, `0` if off. |

## Who the updaters write for

The updaters run as root — they install packages — but the things they leave
behind belong to a desktop user: the `.deb` in `~/Downloads`, the once-per-day
marker and the log in `~/.cache`. `bin/toolbox-env.sh` decides who that is,
taking the first of:

1. `$TOOLBOX_USER`, if set. This is how the systemd units say who they are for.
2. `$SUDO_USER`, when you ran the script with `sudo`.
3. The current user, when running unprivileged.

Running as root with neither set is an error, not a guess — it exits saying so
rather than writing into `/root`.

Nothing is hardcoded to a username or a checkout path. Run it from wherever you
cloned it.

## `shell/bashrc.local`

`~/.bashrc` sources `~/.bashrc.local`, which puts `~/bin` on `$PATH` and defines
the `update_all` alias. That alias chains the system updates — apt, grub, snap,
firmware — with `chrome-sources-fix.sh`, `update-zoom.sh` and
`nvidia-version-check.sh`. The chrome and cursor updaters are not in it; they
run from their systemd units at boot.

Its last block sources `~/.bashrc.private` if that file exists, which is where
machine-specific aliases can go without ending up in this repo. Nothing here
depends on it.

## systemd units and timers

Each updater has a `.service` that runs it once and a `.timer` that starts the
service daily. Only the timers are enabled; the services are started by them.

The timers set `Persistent=true`, which is the part that matters on a laptop.
A machine that suspends instead of rebooting is asleep at the scheduled hour,
and a plain timer would simply skip that day. `Persistent=true` records the last
run and fires a missed one on the next resume. `RandomizedDelaySec=30m` keeps
the three from waking and hitting the network together.

The scripts still keep their own once-per-day marker, so a catch-up run plus a
scheduled run on the same day does no duplicate work.

```bash
systemctl list-timers 'update-*'
```

The services are kept as templates in `systemd/*.service.in`, because two
things in them are per-machine. `./install.sh --systemd` fills both in:

- `@BIN@` becomes your checkout's `bin/` directory, since `ExecStart` needs an
  absolute path.
- `/etc/default/ubuntu-toolbox` gets `TOOLBOX_USER=<you>`. A root unit has no
  invoking user, so this is the only way it can know whose `~/Downloads` to use.

The timers need no substitution and are installed as they are.

The services declare both `Wants=` and `After=network-online.target`. They once
declared only `After=`, which orders a unit against that target but does not
pull it into the boot — so a script could start before the network was up, fail
its connectivity probe and exit 0 silently. That was the reason they seemed not
to work. This still requires `NetworkManager-wait-online.service` to be enabled
for the catch-up run right after boot; `install.sh` warns if it isn't.

If you installed an earlier version of this repo, `./install.sh --systemd`
migrates you: it disables the services from `multi-user.target`, where they ran
at boot, before enabling the timers.

## Layout

```
ubuntu-toolbox/
├── install.sh                    # symlinks, and optionally the systemd units
├── bin/                          # the scripts; ~/bin points here
├── shell/
│   └── bashrc.local              # symlinked to ~/.bashrc.local
├── systemd/                      # .service.in templates (@BIN@) + .timer units
├── tests/
│   └── check-conventions.sh      # asserts the repo follows its own rules
├── docs/
│   └── wifi-doctor/              # docs for bin/wifi-doctor.sh
├── CLAUDE.md                     # notes for Claude Code
├── LICENSE
└── README.md
```

Docs and unit templates stay out of `bin/` so that `~/bin` — which is on
`$PATH` — holds only things you can run.

## wifi-doctor

`wifi-doctor.sh` used to live in its own repo. It was folded in here; its user
guide, design rationale (`TECHNICAL_NOTES.md`), Claude Code instructions and
MIT license moved to `docs/wifi-doctor/` unchanged. It is still a
self-contained single-file tool — copy it anywhere and run it.

## Notes

- The `.cache` marker filenames (`zoom_updater_last_run`,
  `chrome_updater_last_run`, `cursor_updater_last_run`) are load-bearing.
  Renaming one resets the once-per-day state and causes a redundant download.
- `install-deb.sh` and a few others call `sudo` directly.
- All three updaters append to `~/.cache/updates.log`.

## License

MIT — see [LICENSE](LICENSE).

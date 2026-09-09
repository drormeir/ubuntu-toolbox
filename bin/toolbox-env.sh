#!/bin/bash
# Sourced by the updaters. Not run on its own.
#
# The updaters run as root but write into a desktop user's ~/Downloads and
# ~/.cache. This resolves which user that is, and hands new files back to them.
#
# No `set -e` on purpose. This file is sourced, so any shell option set here
# would leak into the calling script and change its behaviour. The callers set
# their own. Failures here are reported and exited explicitly instead.

# Most explicit source first.
if [ -n "${TOOLBOX_USER:-}" ]; then
    :                                   # set by the caller or the systemd unit
elif [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TOOLBOX_USER="$SUDO_USER"           # invoked as `sudo update-zoom.sh`
elif [ "$(id -u)" -ne 0 ]; then
    TOOLBOX_USER="$(id -un)"            # running unprivileged; it is us
else
    # Root with no caller to infer from — a systemd unit missing its config.
    echo "toolbox: running as root, and neither TOOLBOX_USER nor SUDO_USER is set." >&2
    echo "toolbox: there is no way to tell whose ~/Downloads to write to." >&2
    echo "toolbox: set TOOLBOX_USER in /etc/default/ubuntu-toolbox — see install.sh." >&2
    exit 1
fi

TOOLBOX_HOME=$(getent passwd "$TOOLBOX_USER" | cut -d: -f6)
if [ -z "$TOOLBOX_HOME" ] || [ ! -d "$TOOLBOX_HOME" ]; then
    echo "toolbox: user '$TOOLBOX_USER' has no home directory on this system." >&2
    exit 1
fi

TOOLBOX_GROUP=$(id -gn "$TOOLBOX_USER")
TOOLBOX_DOWNLOADS="$TOOLBOX_HOME/Downloads"
TOOLBOX_CACHE="$TOOLBOX_HOME/.cache"
TOOLBOX_LOG="$TOOLBOX_CACHE/updates.log"

# Where the other scripts are. Resolved from this file rather than hardcoded,
# so a clone works wherever it is checked out. readlink -f because ~/bin is
# usually a symlink into the repo.
TOOLBOX_BIN=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)

# Hand a file to the target user. A no-op when we are already that user, so the
# updaters can be run unprivileged without every chown failing.
own() {
    [ "$(id -u)" -eq 0 ] || return 0
    chown "$TOOLBOX_USER:$TOOLBOX_GROUP" "$@" 2>/dev/null || true
}

# Both are assumed to exist by the download and marker paths below. Downloads
# in particular is absent on a fresh server install.
mkdir -p "$TOOLBOX_DOWNLOADS" "$TOOLBOX_CACHE"
own "$TOOLBOX_DOWNLOADS" "$TOOLBOX_CACHE"

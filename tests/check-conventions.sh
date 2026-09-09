#!/bin/bash
# Checks that the conventions CLAUDE.md states are actually true of the tree.
#
# It exists because the claims drifted: CLAUDE.md asserted every script had
# `set -e` when six did not, and that every script was `#!/bin/bash` when two
# were not. A convention nobody verifies becomes a lie that misleads whoever
# reads it next. Run this after changing anything in bin/.
#
#   tests/check-conventions.sh
#
# Exit 0 = every claim holds. Exit 1 = at least one is stale; the output names
# which. When a claim fails, decide whether the script is wrong or the rule is
# — then fix that one, and the list here, together.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")/.." && pwd)
BIN="$ROOT/bin"

# Scripts that change system state. These must stop on the first failure.
STATE_CHANGING="install-deb.sh chrome-sources-fix.sh toggle-sddm-keyboard.sh
                select-apt-mirror.sh update-chrome.sh update-cursor.sh update-zoom.sh"

# Scripts that deliberately do not use `set -e`, and why:
#   read-only probes  — a failed probe is a result to print, not a reason to abort
#   toolbox-env.sh    — sourced; a shell option here would leak into the caller
NO_SET_E="desktop-info.sh os-info.sh nvidia-version-check.sh wifi-doctor.sh toolbox-env.sh"

# Meant to be copied to another machine, so they do not assume /bin/bash.
ENV_BASH="nvidia-version-check.sh wifi-doctor.sh"

fail=0
note() { echo "  FAIL: $*"; fail=1; }

echo "state-changing scripts use 'set -e'"
for f in $STATE_CHANGING; do
    grep -q "^set -e" "$BIN/$f" || note "$f does not"
done
grep -q "^set -euo pipefail" "$ROOT/install.sh" || note "install.sh does not"

echo "the read-only and sourced scripts do not, and say why"
for f in $NO_SET_E; do
    grep -q "^set -e" "$BIN/$f" && note "$f has set -e"
    grep -qi "no \`set -e\`\|read-only" "$BIN/$f" || note "$f does not explain why"
done

echo "no other script is missing 'set -e'"
for f in "$BIN"/*.sh; do
    b=$(basename "$f")
    grep -q "^set -e" "$f" && continue
    case " $NO_SET_E " in *" $b "*) ;; *) note "$b lacks set -e and is not on the list" ;; esac
done

echo "only the portable scripts use 'env bash'"
for f in "$BIN"/*.sh "$ROOT/install.sh"; do
    b=$(basename "$f")
    if head -1 "$f" | grep -q "env bash"; then
        case " $ENV_BASH " in *" $b "*) ;; *) note "$b uses env bash" ;; esac
    else
        case " $ENV_BASH " in *" $b "*) note "$b should use env bash" ;; esac
    fi
done

echo "bin/ scripts are mode 755"
for f in "$BIN"/*.sh; do
    m=$(stat -c %a "$f")
    [ "$m" = 755 ] || note "$(basename "$f") is $m"
done

echo "the once-per-day marker filenames are unchanged"
for m in zoom_updater_last_run chrome_updater_last_run cursor_updater_last_run; do
    grep -rq "$m" "$BIN" || note "$m is no longer referenced"
done

echo "the updaters report failures instead of exiting 0"
grep -q "^die()" "$BIN/toolbox-env.sh" || note "toolbox-env.sh no longer defines die()"
for f in update-zoom.sh update-chrome.sh update-cursor.sh; do
    grep -q "die " "$BIN/$f" || note "$f never calls die — check its error paths"
    # The pattern that hid the broken Cursor API: an error-worded log line
    # followed by exit 0. "no network" and "already ran today" are sanctioned
    # skips and are worded so they do not match.
    if grep -A2 -E 'log "[^"]*(failed|unreachable|could not|error|no \.deb)' "$BIN/$f" \
        | grep -q "exit 0"; then
        note "$f logs an error then exits 0 — use die"
    fi
done

echo "nothing hardcodes a user or a home directory"
if grep -rn "/home/[a-z]" "$BIN" "$ROOT/install.sh" "$ROOT/systemd" >/dev/null 2>&1; then
    grep -rn "/home/[a-z]" "$BIN" "$ROOT/install.sh" "$ROOT/systemd"
    note "a hardcoded home directory is back"
fi

echo
[ "$fail" -eq 0 ] && echo "ALL CLAIMS HOLD" || echo "SOME CLAIMS FAILED"
exit "$fail"

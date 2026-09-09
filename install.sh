#!/bin/bash
# Installs ubuntu-toolbox for the user running it.
#
#   ./install.sh              symlinks only
#   ./install.sh --systemd    also install and enable the boot-time updaters
#
# Run as yourself, not as root. The systemd part calls sudo where it needs to.

set -euo pipefail

REPO=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
WITH_SYSTEMD=0

for arg in "$@"; do
    case "$arg" in
        --systemd) WITH_SYSTEMD=1 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "install.sh: unknown option '$arg'" >&2; exit 2 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "install.sh: run this as your normal user, not root." >&2
    echo "install.sh: it symlinks into \$HOME, and root's \$HOME is /root." >&2
    exit 1
fi

# A symlink whose target is already correct is left alone. An existing file or
# a symlink pointing elsewhere is moved aside rather than clobbered.
link() {
    local target=$1 name=$2
    if [ -L "$name" ] && [ "$(readlink -f -- "$name")" = "$(readlink -f -- "$target")" ]; then
        echo "  ok      $name"
        return
    fi
    if [ -e "$name" ] || [ -L "$name" ]; then
        mv -- "$name" "$name.backup.$(date +%Y%m%d%H%M%S)"
        echo "  backup  $name -> $name.backup.*"
    fi
    ln -s -- "$target" "$name"
    echo "  link    $name -> $target"
}

echo "Installing from $REPO"

chmod +x "$REPO"/bin/*.sh
link "$REPO/bin" "$HOME/bin"
link "$REPO/shell/bashrc.local" "$HOME/.bashrc.local"

# ~/.bashrc does not source ~/.bashrc.local on a stock Ubuntu.
if ! grep -qs 'bashrc\.local' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'

if [ -f ~/.bashrc.local ]; then
    . ~/.bashrc.local
fi
EOF
    echo "  append  ~/.bashrc now sources ~/.bashrc.local"
else
    echo "  ok      ~/.bashrc already sources ~/.bashrc.local"
fi

if [ "$WITH_SYSTEMD" -eq 1 ]; then
    echo
    echo "Installing systemd units (they run as root, daily):"

    # Earlier versions enabled the .service units directly against
    # multi-user.target, so they ran at boot. The timers drive them now.
    # Disable the old wiring first, while those unit files still have the
    # [Install] section that `systemctl disable` needs to undo.
    for svc in update-zoom update-chrome update-cursor; do
        if systemctl is-enabled --quiet "$svc.service" 2>/dev/null; then
            sudo systemctl disable "$svc.service" >/dev/null 2>&1 || true
            echo "  migrate $svc.service no longer runs at boot; its timer will"
        fi
    done

    # The units need to know whose ~/Downloads and ~/.cache to write to. As
    # root there is nobody to infer it from, so it is recorded here.
    sudo tee /etc/default/ubuntu-toolbox >/dev/null <<EOF
# Which desktop user the updaters download for. Read by the update-*.service
# units; see bin/toolbox-env.sh.
TOOLBOX_USER=$USER
EOF
    echo "  write   /etc/default/ubuntu-toolbox (TOOLBOX_USER=$USER)"

    # @BIN@ is the only substitution; the timers need none.
    for unit in "$REPO"/systemd/*.service.in; do
        name=$(basename -- "$unit" .in)
        sed "s|@BIN@|$REPO/bin|g" "$unit" | sudo tee "/etc/systemd/system/$name" >/dev/null
        sudo chmod 644 "/etc/systemd/system/$name"
        echo "  write   /etc/systemd/system/$name"
    done

    for unit in "$REPO"/systemd/*.timer; do
        name=$(basename -- "$unit")
        sudo install -m 644 "$unit" "/etc/systemd/system/$name"
        echo "  write   /etc/systemd/system/$name"
    done

    sudo systemctl daemon-reload
    sudo systemctl enable --now update-zoom.timer update-chrome.timer update-cursor.timer

    # The services order themselves after network-online.target, which matters
    # for the catch-up run right after boot. That target is only reached if
    # something pulls it in.
    if ! systemctl is-enabled --quiet NetworkManager-wait-online.service 2>/dev/null; then
        echo
        echo "  NOTE: NetworkManager-wait-online.service is not enabled. Without it a"
        echo "        catch-up run at boot may start before the network is up and skip."
        echo "        Enable it with:"
        echo "          sudo systemctl enable NetworkManager-wait-online.service"
    fi

    echo
    echo "  Timers are daily with Persistent=true, so a run missed while the"
    echo "  machine was off or suspended fires on the next resume. Check with:"
    echo "    systemctl list-timers 'update-*'"
fi

echo
echo "Done. Open a new shell, or run: . ~/.bashrc.local"

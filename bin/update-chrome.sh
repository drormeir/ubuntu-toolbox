#!/bin/bash
# The system calls this script automatically on reboot in the background before any login
# sudo nano /etc/systemd/system/update-chrome.service

set -e

SOURCES_FILE="/etc/apt/sources.list.d/google-chrome.sources"
MARKER_FILE="/home/dror/.cache/chrome_updater_last_run"
LOG="/home/dror/.cache/updates.log"

log() {
    echo "Chrome Updater: $*"
    mkdir -p "$(dirname "$LOG")"
    printf '%s  chrome  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
    chown dror:dror "$LOG" 2>/dev/null || true
}

# Only run once per day
if [ -f "$MARKER_FILE" ]; then
    file_date=$(date -r "$MARKER_FILE" +%F)
    today=$(date +%F)
    if [ "$file_date" = "$today" ]; then
        echo "Chrome Updater: Already ran today ($file_date). Skipping."
        exit 0
    fi
fi

# Check for network connectivity
if ! wget -q --spider --timeout=5 https://google.com >/dev/null 2>&1; then
    log "no network — skipped"
    exit 0
fi

# Refresh only the Chrome apt source (not the whole system)
echo "Chrome Updater: Refreshing Chrome apt source..."
apt-get update \
    -o Dir::Etc::sourcelist="sources.list.d/google-chrome.list" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"

# Compare installed vs candidate version
INSTALLED_VER=$(dpkg-query -W -f='${Version}' google-chrome-stable 2>/dev/null || echo "")
CANDIDATE_VER=$(apt-cache policy google-chrome-stable | awk '/Candidate:/ {print $2}')

if [ -z "$CANDIDATE_VER" ] || [ "$CANDIDATE_VER" = "(none)" ]; then
    log "could not determine candidate version — skipped"
    exit 0
fi

if [ -n "$INSTALLED_VER" ] && dpkg --compare-versions "$INSTALLED_VER" ge "$CANDIDATE_VER"; then
    log "already at $INSTALLED_VER"
else
    echo "Chrome Updater: Upgrading Chrome from ${INSTALLED_VER:-not installed} to $CANDIDATE_VER..."
    if DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade google-chrome-stable; then
        log "installed $CANDIDATE_VER (was ${INSTALLED_VER:-not installed})"
    else
        log "UPGRADE FAILED to $CANDIDATE_VER"
        exit 1
    fi
fi

# Fix the .sources file if Chrome's postinst overwrote it (missing Architectures line)
/home/dror/bin/chrome-sources-fix.sh

# Update marker
mkdir -p "$(dirname "$MARKER_FILE")"
touch "$MARKER_FILE"
chown dror:dror "$MARKER_FILE"

echo "Chrome Updater: Done."

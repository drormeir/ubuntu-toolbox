#!/bin/bash

# The system call this script automatically on reboot in the background before any login
# sudo nano /etc/systemd/system/update-zoom.service

set -e

. "$(dirname -- "$(readlink -f -- "$0")")/toolbox-env.sh"

LATEST_URL="https://zoom.us/client/latest/zoom_amd64.deb"
DEST="$TOOLBOX_DOWNLOADS/zoom_amd64.deb"
STAMP="$TOOLBOX_CACHE/zoom_deb.stamp"     # carries the server date of the last .deb we fetched
MARKER_FILE="$TOOLBOX_CACHE/zoom_updater_last_run"
LOG="$TOOLBOX_LOG"

log() {
    echo "Zoom Updater: $*"
    mkdir -p "$(dirname "$LOG")"
    printf '%s  zoom    %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
    own "$LOG"
}

touch_marker() {
    mkdir -p "$(dirname "$MARKER_FILE")"
    touch "$MARKER_FILE"
    own "$MARKER_FILE"
}

# Only run once per day
if [ -f "$MARKER_FILE" ] && [ "$(date -r "$MARKER_FILE" +%F)" = "$(date +%F)" ]; then
    echo "Zoom Updater: Already ran today. Skipping."
    exit 0
fi

# Check for network connectivity
if ! wget -q --spider --timeout=5 https://google.com >/dev/null 2>&1; then
    log "no network — skipped"
    exit 0
fi

# Conditional download: -z sends If-Modified-Since from the stamp file's date,
# so nothing transfers unless Zoom published a newer .deb. -R stamps the
# downloaded file with the server's Last-Modified.
REF="$STAMP"
[ -f "$REF" ] || REF="$DEST"

if [ -f "$REF" ]; then
    http_code=$(curl -sS -L -R -z "$REF" -o "$DEST" -w '%{http_code}' "$LATEST_URL") || {
        log "download failed"
        exit 0
    }
else
    http_code=$(curl -sS -L -R -o "$DEST" -w '%{http_code}' "$LATEST_URL") || {
        log "download failed"
        exit 0
    }
fi

if [ "$http_code" = "304" ]; then
    log "remote .deb unchanged — nothing to do"
    touch_marker
    exit 0
fi

if [ ! -s "$DEST" ]; then
    log "no .deb on disk after download (HTTP $http_code)"
    exit 0
fi

own "$DEST"

DEB_VER=$(dpkg-deb -f "$DEST" Version)
INSTALLED_VER=$(dpkg-query -W -f='${Version}' zoom 2>/dev/null || echo "")

if [ -n "$INSTALLED_VER" ] && dpkg --compare-versions "$INSTALLED_VER" ge "$DEB_VER"; then
    log "already at $INSTALLED_VER (downloaded $DEB_VER)"
    mkdir -p "$(dirname "$STAMP")"
    touch -r "$DEST" "$STAMP"; own "$STAMP"
    rm -f "$DEST"
    touch_marker
    exit 0
fi

if "$TOOLBOX_BIN/install-deb.sh" "$DEST"; then
    log "installed $DEB_VER (was ${INSTALLED_VER:-not installed})"
    # Keep only the server date, not the 90MB file — the stamp is what the
    # next If-Modified-Since compares against.
    mkdir -p "$(dirname "$STAMP")"
    touch -r "$DEST" "$STAMP"; own "$STAMP"
    rm -f "$DEST"
else
    log "INSTALL FAILED for $DEB_VER — .deb kept at $DEST"
    exit 1
fi

touch_marker

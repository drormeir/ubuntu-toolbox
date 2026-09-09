#!/bin/bash

# The system calls this script automatically on reboot in the background before any login
# sudo nano /etc/systemd/system/update-cursor.service
#
# Cursor's in-app updater is broken on Linux (unsigned AppImage -> validation fails
# and rolls back), and the official .deb has no auto-update either, so we do it here.
# The .deb is ~300MB, so the remote version is checked BEFORE downloading.

set -e

. "$(dirname -- "$(readlink -f -- "$0")")/toolbox-env.sh"

API_URL="https://cursor.com/api/download?platform=linux-x64-deb&releaseTrack=stable"
DEST="$TOOLBOX_DOWNLOADS/cursor_amd64.deb"
MARKER_FILE="$TOOLBOX_CACHE/cursor_updater_last_run"
PKG_NAME="cursor"
LOG="$TOOLBOX_LOG"

log() {
    echo "Cursor Updater: $*"
    mkdir -p "$(dirname "$LOG")"
    printf '%s  cursor  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
    own "$LOG"
}

# Only run once per day
if [ -f "$MARKER_FILE" ]; then
    file_date=$(date -r "$MARKER_FILE" +%F)
    today=$(date +%F)
    if [ "$file_date" = "$today" ]; then
        echo "Cursor Updater: Already ran today ($file_date). Skipping."
        exit 0
    fi
fi

# Check for network connectivity.
#
# Exit 0, not die: booting or resuming without a network yet is expected, not a
# failure, and the timer will come round again. Everything below this point is
# a real error and exits non-zero.
if ! wget -q --spider --timeout=5 https://google.com >/dev/null 2>&1; then
    log "no network — skipped"
    exit 0
fi

# Ask Cursor's download API for the latest stable .deb.
#
# curl rather than wget so the HTTP status is available: this API answers a
# server-side problem with a 500, and a log line saying "returned nothing"
# would leave you guessing whose fault it is.
echo "Cursor Updater: Querying $API_URL ..."
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

http_code=$(curl -sS --max-time 20 -o "$BODY" -w '%{http_code}' "$API_URL") \
    || die "could not reach the download API — $API_URL"

JSON=$(cat "$BODY")

if [ "$http_code" != "200" ]; then
    printf 'Cursor Updater: response body: %s\n' "$(head -c 500 "$BODY")" >&2
    die "download API returned HTTP $http_code — this is Cursor's end, not yours"
fi

LATEST_URL=$(printf '%s' "$JSON" | grep -oP '"(downloadUrl|url)"\s*:\s*"\K[^"]+' | head -n1 || true)

if [ -z "$LATEST_URL" ]; then
    # A 200 with no URL in it. The body is the only clue, so record it.
    printf 'Cursor Updater: response body: %s\n' "$(head -c 500 "$BODY")" >&2
    die "no download URL in the API response"
fi

# Version, preferably from the JSON, otherwise from the URL
# (e.g. .../updates/download/golden/linux-x64-deb/cursor/3.19)
REMOTE_VER=$(printf '%s' "$JSON" | grep -oP '"version"\s*:\s*"\K[^"]+' | head -n1 || true)
if [ -z "$REMOTE_VER" ]; then
    REMOTE_VER=$(printf '%s' "$LATEST_URL" | grep -oP '[0-9]+(\.[0-9]+)+' | tail -n1 || true)
fi

INSTALLED_VER=$(dpkg-query -W -f='${Version}' "$PKG_NAME" 2>/dev/null || echo "")

if [ -n "$INSTALLED_VER" ] && [ -n "$REMOTE_VER" ]; then
    if dpkg --compare-versions "$INSTALLED_VER" ge "$REMOTE_VER"; then
        log "already at $INSTALLED_VER (latest $REMOTE_VER) — no download"
        mkdir -p "$(dirname "$MARKER_FILE")"
        touch "$MARKER_FILE"
        own "$MARKER_FILE"
        exit 0
    fi
fi

echo "Cursor Updater: Downloading Cursor ${REMOTE_VER:-latest} to $DEST ..."
wget --no-use-server-timestamps -O "$DEST" "$LATEST_URL" \
    || die "download failed from $LATEST_URL"
own "$DEST"
echo "Cursor Updater: Downloaded to $DEST"

# The .deb itself is the authority on the version we just fetched
DEB_VER=$(dpkg-deb -f "$DEST" Version 2>/dev/null || echo "")

if [ -n "$INSTALLED_VER" ] && [ -n "$DEB_VER" ]; then
    if dpkg --compare-versions "$INSTALLED_VER" ge "$DEB_VER"; then
        echo "Cursor Updater: Installed Cursor ($INSTALLED_VER) is up to date or newer than the downloaded version ($DEB_VER)."
        mkdir -p "$(dirname "$MARKER_FILE")"
        touch "$MARKER_FILE"
        own "$MARKER_FILE"
        exit 0
    fi
fi

echo "Cursor Updater: Installing Cursor version ${DEB_VER:-unknown} (was ${INSTALLED_VER:-not installed})..."
if "$TOOLBOX_BIN/install-deb.sh" "$DEST"; then
    log "installed ${DEB_VER:-unknown} (was ${INSTALLED_VER:-not installed})"
    rm -f "$DEST"          # ~300MB; the API version check makes keeping it pointless
else
    log "INSTALL FAILED for ${DEB_VER:-unknown} — .deb kept at $DEST"
    exit 1
fi

# Update marker
mkdir -p "$(dirname "$MARKER_FILE")"
touch "$MARKER_FILE"
own "$MARKER_FILE"

echo "Cursor Updater: Done."

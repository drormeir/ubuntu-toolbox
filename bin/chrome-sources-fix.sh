#!/bin/bash
# Patches Chrome's .sources file to add 'Architectures: amd64'
# Called by: update-chrome.sh and the apt hook (99fix-chrome-sources)

set -e

FILE=/etc/apt/sources.list.d/google-chrome.sources
if [ -f "$FILE" ] && ! grep -q "^Architectures:" "$FILE"; then
    sudo sed -i '/^Components:/a Architectures: amd64' "$FILE"
    echo "Chrome patch: Added Architectures: amd64 to $FILE"
fi

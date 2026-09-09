#!/bin/bash

CONF_DIR="/etc/sddm.conf.d"
CONF_FILE="$CONF_DIR/00-virtualkeyboard.conf"

# Ensure the target directory exists
sudo mkdir -p "$CONF_DIR"

if [ -f "$CONF_FILE" ] && grep -q 'InputMethod=qtvirtualkeyboard' "$CONF_FILE"; then
    echo "Disabling virtual keyboard"
    echo -e '[General]\nInputMethod=' | sudo tee "$CONF_FILE"
else
    echo "Enabling virtual keyboard"
    echo -e '[General]\nInputMethod=qtvirtualkeyboard' | sudo tee "$CONF_FILE"
fi


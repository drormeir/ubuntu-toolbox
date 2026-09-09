#!/bin/bash
# Install a .deb, fixing broken dependencies if dpkg complains.
# Interactive when run from a terminal; automatic when there is no TTY
# (systemd units, cron) — where a prompt would silently receive EOF.

set -e

filename="${1:-}"

if [ -z "$filename" ]; then
  echo "Usage: $0 package_file.deb"
  exit 1
fi

if sudo dpkg -i "$filename"; then
  echo "Package installed successfully."
  exit 0
fi

echo "dpkg install failed."

if [ -t 0 ]; then
  read -r -p "Fix broken packages? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Not fixing broken packages."
    exit 1
  fi
else
  echo "No terminal attached — fixing broken packages automatically."
fi

if sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y; then
  echo "Broken packages fixed."
  exit 0
fi

echo "apt-get install -f failed."
exit 1

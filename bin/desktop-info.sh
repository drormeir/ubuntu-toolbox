#!/bin/bash
# Prints what it can about the desktop session.
#
# No `set -e` on purpose. Several of these probes are expected to fail on some
# machines — glxinfo may be absent or match nothing, gsettings is a GNOME tool
# being asked on KDE — and aborting there would truncate the report at the
# first gap, which is the opposite of what an info dump is for.

echo "Display Manager:"
cat /etc/X11/default-display-manager
echo ""
echo "glxinfo | grep OpenGL renderer:"
glxinfo | grep "OpenGL renderer"
echo ""
echo "Desktop Environment:"
echo "XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP"
echo "DESKTOP_SESSION=$DESKTOP_SESSION"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo "Icons theme: $(gsettings get org.gnome.desktop.interface icon-theme)"
echo
echo "================================"
echo "Operating system info:"
cat /etc/os-release


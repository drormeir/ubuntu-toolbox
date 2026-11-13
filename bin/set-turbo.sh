#!/bin/bash
# Turns CPU turbo boost on or off, until the next reboot.
#   set-turbo.sh 1   # on
#   set-turbo.sh 0   # off

set -e

case "$1" in
    0|1) ;;
    *) echo "usage: $(basename "$0") 0|1   (0 = off, 1 = on)" >&2; exit 2 ;;
esac

INTEL=/sys/devices/system/cpu/intel_pstate/no_turbo
BOOST=/sys/devices/system/cpu/cpufreq/boost

if [ -f "$INTEL" ]; then
    # no_turbo counts the other way: 1 means off.
    echo $((1 - $1)) | sudo tee "$INTEL" >/dev/null
elif [ -f "$BOOST" ]; then
    echo "$1" | sudo tee "$BOOST" >/dev/null
else
    echo "This CPU driver exposes no turbo switch." >&2
    exit 1
fi

"$(dirname -- "$(readlink -f -- "$0")")/get-turbo.sh"

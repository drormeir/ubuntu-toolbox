#!/bin/bash
# Prints 1 if CPU turbo boost is on, 0 if it is off.
# Read-only. No `set -e`: a missing switch is a result to print.

INTEL=/sys/devices/system/cpu/intel_pstate/no_turbo
BOOST=/sys/devices/system/cpu/cpufreq/boost

if [ -f "$INTEL" ]; then
    # no_turbo counts the other way: 1 means off.
    echo $((1 - $(cat "$INTEL")))
elif [ -f "$BOOST" ]; then
    cat "$BOOST"
else
    echo "This CPU driver exposes no turbo switch." >&2
    exit 1
fi

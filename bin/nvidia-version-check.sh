#!/usr/bin/env bash
# nvidia-version-check: verify loaded NVIDIA kernel module matches on-disk version.
# Usage: nvidia-version-check [-q|--quiet]
# Exit codes: 0 = match, 1 = mismatch (reboot needed), 2 = error.

set -u

quiet=0
[[ "${1:-}" == "-q" || "${1:-}" == "--quiet" ]] && quiet=1

if [[ ! -r /proc/driver/nvidia/version ]]; then
    echo "Cannot read /proc/driver/nvidia/version (nvidia module not loaded?)" >&2
    exit 2
fi

# Pull the first token that looks like a version number from the "Kernel Module" line.
loaded=$(awk '/Kernel Module/ {
    for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+\.[0-9]+/) { print $i; exit }
}' /proc/driver/nvidia/version)

ondisk=$(modinfo -F version nvidia 2>/dev/null) || {
    echo "modinfo failed for the nvidia module." >&2; exit 2; }

if [[ -z "$loaded" || -z "$ondisk" ]]; then
    echo "Could not parse versions (loaded='$loaded' ondisk='$ondisk')." >&2
    exit 2
fi

# Compare major.minor — robust to a missing/extra patch suffix (e.g. 580.142 vs 580.142.07).
mm() { cut -d. -f1,2 <<<"$1"; }

if [[ "$(mm "$loaded")" == "$(mm "$ondisk")" ]]; then
    (( quiet )) || echo "OK: NVIDIA driver versions match (loaded=$loaded, on-disk=$ondisk)."
    exit 0
else
    echo "You must reboot (loaded=$loaded, on-disk=$ondisk)."
    exit 1
fi


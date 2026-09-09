#!/bin/bash
set -euo pipefail

SOURCES_FILE="/etc/apt/sources.list.d/ubuntu.sources"
TEST_PATH="dists/noble/Release"
TIMEOUT=5

MIRRORS=(
    "https://mirror.il-ta.kamatera.com/ubuntu/"
    "http://mirror.il-pt.kamatera.com/ubuntu/"
    "https://ubuntu-archive.interhost.co.il/ubuntu/"
    "https://mirror.il-ha.kamatera.com/ubuntu/"
    "https://mirror.il-rh.kamatera.com/ubuntu/"
    "http://il.archive.ubuntu.com/ubuntu/"
    "http://mirror.isoc.org.il/pub/ubuntu/"
    "https://ubuntu.mirrors.ovh.net/ubuntu/"
    "http://mirror.eu.kamatera.com/ubuntu/"
    "http://ftp.fau.de/ubuntu/"
    "https://mirror.dogado.de/ubuntu/"
    "http://ftp.icm.edu.pl/pub/Linux/ubuntu/"
    "http://ftp.belnet.be/ubuntu/"
    "http://ftp.halifax.rwth-aachen.de/ubuntu/"
    "http://mirror.netcologne.de/ubuntu/"
    "https://mirrors.xtom.nl/ubuntu/"
    "http://mirrors.xtom.de/ubuntu/"
    "http://archive.ubuntu.com/ubuntu/"
)

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

if [[ ! -f "$SOURCES_FILE" ]]; then
    echo "Error: $SOURCES_FILE not found"
    exit 1
fi

echo "Testing ${#MIRRORS[@]} mirrors (downloading $TEST_PATH)..."
echo ""

best_mirror=""
best_time=999999

for mirror in "${MIRRORS[@]}"; do
    url="${mirror}${TEST_PATH}"
    host=$(echo "$mirror" | sed 's|https\?://\([^/]*\).*|\1|')

    printf "%-50s " "$host"

    result=$(curl -o /dev/null -s -w "%{time_total} %{http_code}" --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$url" 2>/dev/null) || result=""

    if [[ -z "$result" ]]; then
        echo "TIMEOUT"
        continue
    fi

    time_total=$(echo "$result" | awk '{print $1}')
    http_code=$(echo "$result" | awk '{print $2}')

    if [[ "$http_code" != "200" ]]; then
        echo "HTTP $http_code"
        continue
    fi

    time_ms=$(awk "BEGIN {printf \"%.0f\", $time_total * 1000}")
    echo "${time_ms}ms"

    if awk "BEGIN {exit !($time_total < $best_time)}"; then
        best_time=$time_total
        best_mirror=$mirror
    fi
done

echo ""

if [[ -z "$best_mirror" ]]; then
    echo "No reachable mirror found."
    exit 1
fi

best_host=$(echo "$best_mirror" | sed 's|https\?://\([^/]*\).*|\1|')
best_ms=$(awk "BEGIN {printf \"%.0f\", $best_time * 1000}")
echo "Best: $best_host (${best_ms}ms)"

current=$(grep -oP 'URIs: \K.*' "$SOURCES_FILE" | tr -d '[:space:]')
if [[ "$current" == "$best_mirror" ]]; then
    echo "Already using the best mirror. No changes needed."
    exit 0
fi

current_host=$(echo "$current" | sed 's|https\?://\([^/]*\).*|\1|')
echo "Current: $current_host"
echo ""
read -rp "Switch to $best_host? [y/N] " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    escaped_current=$(sed 's|[&/\]|\\&|g' <<< "$current")
    escaped_best=$(sed 's|[&/\]|\\&|g' <<< "$best_mirror")
    sed -i "s|${escaped_current}|${escaped_best}|" "$SOURCES_FILE"
    echo "Updated. Run 'sudo apt update' to refresh."
else
    echo "No changes made."
fi

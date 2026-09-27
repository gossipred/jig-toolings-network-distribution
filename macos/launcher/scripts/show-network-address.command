#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
. "$SCRIPT_DIR/jig-port.sh"
JIG_PORT="$(jig_read_port "$SCRIPT_DIR/..")"

echo "Local URL:"
echo "http://localhost:$JIG_PORT"
echo
echo "LAN addresses on this Mac:"
echo
for iface in en0 en1 en2; do
    IP="$(ipconfig getifaddr "$iface" 2>/dev/null)"
    if [ -n "$IP" ]; then
        echo "  $iface: $IP"
    fi
done
echo
echo "Other users can open:"
echo "http://SERVER-IP:$JIG_PORT"
echo
read -r -p "Press Enter to close..."

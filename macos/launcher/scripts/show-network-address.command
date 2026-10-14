#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
. "$SCRIPT_DIR/jig-port.sh"
JIG_PORT="$(jig_read_port "$SCRIPT_DIR/..")"
JIG_HTTPS_PORT="$(jig_read_https_port "$SCRIPT_DIR/..")"

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
if [ -n "$JIG_HTTPS_PORT" ]; then
    echo "https://SERVER-IP:$JIG_HTTPS_PORT"
    echo "(http://SERVER-IP:$JIG_PORT also works and switches to HTTPS.)"
else
    echo "http://SERVER-IP:$JIG_PORT"
fi
echo
read -r -p "Press Enter to close..."

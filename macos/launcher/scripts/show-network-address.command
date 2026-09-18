#!/usr/bin/env bash
set -u
echo "Local URL:"
echo "http://localhost:8080"
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
echo "http://SERVER-IP:8080"
echo
read -r -p "Press Enter to close..."

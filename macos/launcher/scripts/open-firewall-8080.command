#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
RUNTIME_JAVA="$PACKAGE_DIR/runtime/bin/java"

echo "Checking macOS Application Firewall for LAN access on port 8080..."
echo "This script needs your Mac login password (sudo)."
echo

FW="/usr/libexec/ApplicationFirewall/socketfilterfw"

if [ -x "$RUNTIME_JAVA" ]; then
    JAVA_BIN="$RUNTIME_JAVA"
else
    JAVA_BIN="$(command -v java || true)"
fi

if [ -z "$JAVA_BIN" ]; then
    echo "[ERROR] Could not find the Java executable used to run this system."
    read -r -p "Press Enter to close..."
    exit 1
fi

STATE="$(sudo "$FW" --getglobalstate 2>/dev/null)"
echo "Firewall state: $STATE"

if echo "$STATE" | grep -qi "disabled"; then
    echo
    echo "macOS Application Firewall is OFF. LAN users on the same network can already"
    echo "reach this Mac on port 8080 — no changes are needed."
    read -r -p "Press Enter to close..."
    exit 0
fi

echo
echo "Allowing incoming connections for:"
echo "$JAVA_BIN"
sudo "$FW" --add "$JAVA_BIN"
sudo "$FW" --unblockapp "$JAVA_BIN"

echo
echo "Done. If LAN users still cannot connect, also check your router/network"
echo "firewall settings."
read -r -p "Press Enter to close..."

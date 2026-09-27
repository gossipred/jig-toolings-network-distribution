#!/usr/bin/env bash
# Changes the web port of the system (server.port in app/application.properties).
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$(cd .. && pwd)"
PROPS="$PACKAGE_DIR/app/application.properties"
. "$SCRIPT_DIR/jig-port.sh"

pause_exit() { echo; read -r -p "Press Enter to close..."; exit "$1"; }

echo "============================================================"
echo " Jig & Toolings Management System - Change Port"
echo "============================================================"
echo

if [ ! -f "$PROPS" ]; then
    echo "[ERROR] Settings file not found: $PROPS"
    pause_exit 1
fi

OLD_PORT="$(jig_read_port "$PACKAGE_DIR")"
echo "Current port : $OLD_PORT"
echo "Recommended  : a number between 8081 and 8099"
echo
read -r -p "Enter the new port number (press Enter to cancel): " NEW_PORT
NEW_PORT="$(printf '%s' "$NEW_PORT" | tr -d '[:space:]')"

if [ -z "$NEW_PORT" ]; then
    echo "Cancelled. Nothing was changed."
    pause_exit 0
fi
case "$NEW_PORT" in
    ''|*[!0-9]*|0*) echo "[ERROR] \"$NEW_PORT\" is not a valid port number. Nothing was changed."; pause_exit 1 ;;
esac
if [ "$NEW_PORT" -lt 1024 ] || [ "$NEW_PORT" -gt 65535 ]; then
    echo "[ERROR] Please use a port from 1024 to 65535. Nothing was changed."
    pause_exit 1
fi
case "$NEW_PORT" in
    3306|3307|8443) echo "[ERROR] Port $NEW_PORT is commonly used by other software (for example MySQL). Please choose another."; pause_exit 1 ;;
esac
if [ "$NEW_PORT" = "$OLD_PORT" ]; then
    echo "The system already uses port $OLD_PORT. Nothing was changed."
    pause_exit 0
fi
IN_USE="$(lsof -nP -iTCP:"$NEW_PORT" -sTCP:LISTEN -t 2>/dev/null | head -n 1)"
if [ -n "$IN_USE" ]; then
    echo "[ERROR] Port $NEW_PORT is already in use by process ID $IN_USE ($(ps -p "$IN_USE" -o comm= 2>/dev/null)). Please choose another port."
    pause_exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
cp "$PROPS" "$PROPS.bak-$TS"
echo "[1/3] Backup saved: app/application.properties.bak-$TS"

if grep -Eq '^[[:space:]]*server\.port[[:space:]]*=' "$PROPS"; then
    sed -i '' -E "s/^[[:space:]]*server\.port[[:space:]]*=.*/server.port=$NEW_PORT/" "$PROPS"
else
    printf '\nserver.port=%s\n' "$NEW_PORT" >> "$PROPS"
fi
if [ "$(jig_read_port "$PACKAGE_DIR")" != "$NEW_PORT" ]; then
    echo "[ERROR] The settings file could not be updated. Restoring the backup..."
    cp "$PROPS.bak-$TS" "$PROPS"
    pause_exit 1
fi
echo "[2/3] Port changed: $OLD_PORT -> $NEW_PORT"
echo "      (macOS firewall allows the program itself, so no firewall change is needed.)"
echo

RUNNING="$(jig_java_pids_on_port "$OLD_PORT")"
if [ -n "$RUNNING" ]; then
    read -r -p "The system is running on the old port $OLD_PORT. Restart it now on port $NEW_PORT? (y/n): " RS
    if [ "$(printf '%s' "$RS" | tr '[:upper:]' '[:lower:]')" = "y" ]; then
        kill $RUNNING 2>/dev/null; sleep 3
        STILL="$(jig_java_pids_on_port "$OLD_PORT")"; [ -n "$STILL" ] && kill -9 $STILL 2>/dev/null
        open "$PACKAGE_DIR/START-JIG-NETWORK-APP.command"
        echo "[3/3] Restarting on port $NEW_PORT..."
    else
        echo "[3/3] To restart later: run scripts/stop-system.command, then START-JIG-NETWORK-APP.command."
    fi
else
    echo "[3/3] The new port is used the next time you start the system."
fi

echo
echo "============================================================"
echo " New address for this Mac    : http://localhost:$NEW_PORT"
echo " New address for other PCs   : http://SERVER-IP:$NEW_PORT"
echo " (Run scripts/show-network-address.command to see SERVER-IP.)"
echo " Please update bookmarks on other computers."
echo "============================================================"
pause_exit 0

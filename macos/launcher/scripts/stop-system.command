#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
. "$SCRIPT_DIR/jig-port.sh"
JIG_PORT="$(jig_read_port "$PACKAGE_DIR")"

# Also check the port recorded at the last start (it differs after change-port).
PORTS="$JIG_PORT"
RUN_PORT="$(tr -d '[:space:]' < "$PACKAGE_DIR/logs/running-port.txt" 2>/dev/null)"
case "$RUN_PORT" in ''|*[!0-9]*) ;; *) [ "$RUN_PORT" != "$JIG_PORT" ] && PORTS="$JIG_PORT $RUN_PORT" ;; esac

echo "Stopping Jig & Toolings Management System (port $PORTS)..."
echo

FOUND=0
for port in $PORTS; do
    PIDS="$(jig_java_pids_on_port "$port")"
    OTHER="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)"
    if [ -n "$PIDS" ]; then
        FOUND=1
        jig_backup_before_stop "$port" "$PACKAGE_DIR"
        kill $PIDS 2>/dev/null
        sleep 3
        STILL="$(jig_java_pids_on_port "$port")"
        [ -n "$STILL" ] && kill -9 $STILL 2>/dev/null
        echo "Stopped (port $port)."
    elif [ -n "$OTHER" ]; then
        FOUND=1
        echo "[WARN] Port $port is used by another program (PID $OTHER), not this system. Not stopped."
    fi
done
[ "$FOUND" -eq 0 ] && echo "The system is not running."

echo "Done."
read -r -p "Press Enter to close..."

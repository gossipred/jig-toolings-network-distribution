#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
APP_DIR="$PACKAGE_DIR/app"
LOG_DIR="$PACKAGE_DIR/logs"
RUNTIME_DIR="$PACKAGE_DIR/runtime"
JAR_FILE="$APP_DIR/jig-management-system.jar"
. "$SCRIPT_DIR/jig-port.sh"
JIG_PORT="$(jig_read_port "$PACKAGE_DIR")"
LOCAL_URL="http://localhost:$JIG_PORT"
LOGIN_URL="http://localhost:$JIG_PORT/login"

mkdir -p "$LOG_DIR"

echo "============================================================"
echo " Jig & Toolings Management System - macOS Network App"
echo "============================================================"
echo

check_login() {
    curl -s -o /dev/null -m 2 -w "%{http_code}" "$LOGIN_URL" 2>/dev/null | grep -qE "^[2-4][0-9][0-9]$"
}

# -- Update check ---------------------------------------------------
# True when version $1 is newer than $2 (numeric, dot-separated).
version_gt() {
    local IFS=.; local a=($1) b=($2) i
    for i in 0 1 2 3; do
        [ "${a[i]:-0}" -gt "${b[i]:-0}" ] 2>/dev/null && return 0
        [ "${a[i]:-0}" -lt "${b[i]:-0}" ] 2>/dev/null && return 1
    done
    return 1
}
UPDATE_URL="https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"
CURRENT_VERSION="$(grep -E '^app\.version=' "$APP_DIR/application.properties" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
if [ -n "$CURRENT_VERSION" ]; then
    LATEST_JSON="$(curl -s -m 5 "$UPDATE_URL" 2>/dev/null)"
    if [ -n "$LATEST_JSON" ]; then
        # plutil is built into macOS; python3 is not (it prompts to install Xcode tools).
        JSON_FILE="$(mktemp)"; printf '%s' "$LATEST_JSON" > "$JSON_FILE"
        LATEST_VERSION="$(plutil -extract latestVersion raw -o - "$JSON_FILE" 2>/dev/null)"
        NOTES_URL="$(plutil -extract notesUrl raw -o - "$JSON_FILE" 2>/dev/null)"
        rm -f "$JSON_FILE"
        if [ -n "$LATEST_VERSION" ] && version_gt "$LATEST_VERSION" "$CURRENT_VERSION"; then
            echo
            echo "*** UPDATE AVAILABLE ***"
            echo "  Current : $CURRENT_VERSION"
            echo "  Latest  : $LATEST_VERSION"
            echo "  Notes   : $NOTES_URL"
            echo "  Run scripts/UPDATE-JIG-NETWORK-APP.command to update."
            echo
        fi
    fi
fi
# ---------------------------------------------------------------------
echo

if [ ! -f "$JAR_FILE" ]; then
    echo "[ERROR] Application JAR not found:"
    echo "$JAR_FILE"
    echo
    echo "Please copy the complete mac-network-app package again."
    read -r -p "Press Enter to close..."
    exit 1
fi

# Find Java: bundled runtime first, then system Java.
if [ -x "$RUNTIME_DIR/bin/java" ]; then
    JAVA_EXE="$RUNTIME_DIR/bin/java"
    echo "[INFO] Using bundled Java runtime."
else
    JAVA_EXE="java"
    echo "[INFO] Bundled Java not found. Using system Java."
    if ! command -v java >/dev/null 2>&1; then
        echo
        echo "[ERROR] Java not found. Please install Java 17 or place the runtime folder."
        read -r -p "Press Enter to close..."
        exit 1
    fi
fi

# Find MySQL client: prefer XAMPP for macOS, fall back to system PATH (Homebrew etc).
MYSQL_EXE=""
for candidate in /Applications/XAMPP/bin/mysql /Applications/XAMPP/xamppfiles/bin/mysql; do
    if [ -x "$candidate" ]; then
        MYSQL_EXE="$candidate"
        break
    fi
done
if [ -z "$MYSQL_EXE" ] && command -v mysql >/dev/null 2>&1; then
    MYSQL_EXE="mysql"
fi

if [ -z "$MYSQL_EXE" ]; then
    echo
    echo "[ERROR] MySQL client not found."
    echo "Please install XAMPP for macOS first, then start MySQL in the XAMPP control panel."
    read -r -p "Press Enter to close..."
    exit 1
fi

if ! "$MYSQL_EXE" -u root -e "SELECT 1" >/dev/null 2>&1; then
    echo
    echo "[ERROR] MySQL is not responding."
    echo "Please open the XAMPP control panel and start MySQL."
    echo "Then run this launcher again."
    read -r -p "Press Enter to close..."
    exit 1
fi

echo "[INFO] MySQL is running."
echo

# After change-port the system may still run on the previous port.
RUN_PORT="$(tr -d '[:space:]' < "$LOG_DIR/running-port.txt" 2>/dev/null)"
case "$RUN_PORT" in ''|*[!0-9]*) RUN_PORT="" ;; esac
if [ -n "$RUN_PORT" ] && [ "$RUN_PORT" != "$JIG_PORT" ]; then
    OLD_PIDS="$(jig_java_pids_on_port "$RUN_PORT")"
    if [ -n "$OLD_PIDS" ]; then
        echo "[INFO] The system is still running on the previous port $RUN_PORT. Stopping it..."
        kill $OLD_PIDS 2>/dev/null; sleep 3
        OLD_PIDS="$(jig_java_pids_on_port "$RUN_PORT")"; [ -n "$OLD_PIDS" ] && kill -9 $OLD_PIDS 2>/dev/null
    fi
fi

if check_login; then
    echo "[INFO] The system is already running."
    open "$LOCAL_URL"
    echo
    echo "Local URL: $LOCAL_URL"
    echo "LAN users can use this Mac's IP address with port $JIG_PORT."
    read -r -p "Press Enter to close..."
    exit 0
fi

EXISTING_PID="$(lsof -nP -iTCP:"$JIG_PORT" -sTCP:LISTEN -t 2>/dev/null || true)"
if [ -n "$EXISTING_PID" ]; then
    echo
    echo "[ERROR] Port $JIG_PORT is already in use by process ID $EXISTING_PID, but the login page is not responding."
    echo "Run scripts/stop-system.command first, or close the other program using port $JIG_PORT."
    echo "To use a different port, run scripts/change-port.command."
    read -r -p "Press Enter to close..."
    exit 1
fi

echo
echo "Starting Jig & Toolings Management System..."
echo

# Remember the port in use, so stop-system still finds the system after the port setting changes.
echo "$JIG_PORT" > "$LOG_DIR/running-port.txt"
cd "$APP_DIR"
nohup "$JAVA_EXE" -jar jig-management-system.jar --spring.config.location=file:application.properties \
    > "$LOG_DIR/jig-system.log" 2>&1 &

echo "Waiting for the web server to become ready..."
echo "(The first start can take 1-2 minutes on slower computers.)"
echo

READY=0
for _ in $(seq 1 180); do
    if check_login; then
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo
    echo "[ERROR] The system did not become ready within 3 minutes."
    echo "Please check:"
    echo "  1. XAMPP MySQL is running"
    echo "  2. Port $JIG_PORT is not blocked"
    echo "  3. Log file: $LOG_DIR/jig-system.log"
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

echo
echo "[OK] The system is ready."
echo "Local URL: $LOCAL_URL"
echo
echo "First login: admin / 123456 (change the password right away)."
echo "A 30-day free trial starts automatically on first launch."
echo
open "$LOCAL_URL"
read -r -p "Press Enter to close..."
exit 0

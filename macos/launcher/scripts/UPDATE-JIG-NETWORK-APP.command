#!/usr/bin/env bash
# The update replaces the files in scripts/, including this one. bash reads a
# script while it runs, so everything lives in main() and the last line calls
# it and exits: bash has already read the whole file before anything changes.
# Standalone on purpose (no jig-port.sh), so it can be copied into an older
# installation to upgrade it. macOS ships bash 3.2 — no bash 4 syntax.

# --auto (used by "Update now" on the web page): no questions, no pauses,
# result written to logs/last-update.txt, system restarted whenever the old or
# new version can run.

main() {
set -u
AUTO=0
[ "${1:-}" = "--auto" ] && AUTO=1
pause_close() { [ "$AUTO" = "1" ] || read -r -p "Press Enter to close..."; }
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$(cd .. && pwd)"
APP_DIR="$PACKAGE_DIR/app"
BACKUP_BASE="$PACKAGE_DIR/backups"
TMP_BASE="${TMPDIR:-/tmp}"
DOWNLOAD_DIR="${TMP_BASE%/}/jig-update"
UPDATE_URL="${JIG_UPDATE_URL:-https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json}"

JIG_PORT="$(grep -E '^[[:space:]]*server\.port[[:space:]]*=' "$APP_DIR/application.properties" 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d '[:space:]')"
case "$JIG_PORT" in ''|*[!0-9]*) JIG_PORT=8080 ;; esac

echo "============================================================"
echo " Jig & Toolings Management System - Semi-Automatic Updater"
echo "============================================================"
echo

CURRENT_VERSION="$(grep -E '^app\.version=' "$APP_DIR/application.properties" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
if [ -z "$CURRENT_VERSION" ]; then
    echo "[ERROR] Cannot read current version from:"
    echo "        $APP_DIR/application.properties"
    echo
    pause_close
    return 1
fi

echo "Installed version : $CURRENT_VERSION"
echo "Checking server   : $UPDATE_URL"
echo

LATEST_JSON="$(curl -s -m 10 "$UPDATE_URL" 2>/dev/null)"
if [ -z "$LATEST_JSON" ]; then
    echo "[ERROR] Update check failed. No response from server."
    pause_close
    return 1
fi

# plutil reads JSON and is built into macOS (python3 is not, on a Mac without Xcode tools).
JSON_FILE="$(mktemp)"
printf '%s' "$LATEST_JSON" > "$JSON_FILE"
json_get() { plutil -extract "$1" raw -o - "$JSON_FILE" 2>/dev/null; }
LATEST_VERSION="$(json_get latestVersion)"
RELEASE_DATE="$(json_get releaseDate)"
NOTES_URL="$(json_get notesUrl)"
DOWNLOAD_ZIP_URL="$(json_get platforms.macos.packageUrl)"
EXPECTED_SHA256="$(json_get platforms.macos.sha256)"
rm -f "$JSON_FILE"

if [ -z "$LATEST_VERSION" ]; then
    echo "[ERROR] Could not parse version information."
    pause_close
    return 1
fi

# True when version $1 is newer than $2 (numeric, dot-separated).
version_gt() {
    local IFS=.; local a=($1) b=($2) i
    for i in 0 1 2 3; do
        [ "${a[i]:-0}" -gt "${b[i]:-0}" ] 2>/dev/null && return 0
        [ "${a[i]:-0}" -lt "${b[i]:-0}" ] 2>/dev/null && return 1
    done
    return 1
}
if ! version_gt "$LATEST_VERSION" "$CURRENT_VERSION"; then
    echo "System is up to date."
    echo "Installed version: $CURRENT_VERSION"
    echo
    pause_close
    return 0
fi

echo "*** UPDATE AVAILABLE ***"
echo
echo "  Installed version : $CURRENT_VERSION"
echo "  Latest version    : $LATEST_VERSION"
echo "  Release date      : $RELEASE_DATE"
echo "  Release notes     : $NOTES_URL"
echo
echo "Before updating, a backup is made of:"
echo "  database, license/, uploads/, app/ (program + settings), scripts/"
echo "Your settings (port, database password) are kept."
echo
echo "[WARNING] The system stops during the update."
echo "          LAN users will be disconnected for a few minutes."
echo
if [ "$AUTO" = "1" ]; then
    CONFIRM=y
else
    read -r -p "Proceed with update? (y to continue / any other key to cancel): " CONFIRM
fi
if [ "$(printf '%s' "$CONFIRM" | tr '[:upper:]' '[:lower:]')" != "y" ]; then
    echo
    echo "Update cancelled."
    pause_close
    return 0
fi

echo
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$BACKUP_BASE/update-backup-$TIMESTAMP"
echo "[1/5] Creating backup in: backups/update-backup-$TIMESTAMP"
mkdir -p "$BACKUP_DIR"
[ -d "$PACKAGE_DIR/license" ] && cp -R "$PACKAGE_DIR/license" "$BACKUP_DIR/license"
[ -d "$PACKAGE_DIR/uploads" ] && cp -R "$PACKAGE_DIR/uploads" "$BACKUP_DIR/uploads"
[ -d "$APP_DIR" ] && cp -R "$APP_DIR" "$BACKUP_DIR/app"
[ -d "$SCRIPT_DIR" ] && cp -R "$SCRIPT_DIR" "$BACKUP_DIR/scripts"
echo "[1/5] Files backed up. (The database is backed up in step 3.)"

PORTS="$JIG_PORT"
RUN_PORT="$(tr -d '[:space:]' < "$PACKAGE_DIR/logs/running-port.txt" 2>/dev/null)"
case "$RUN_PORT" in ''|*[!0-9]*) ;; *) [ "$RUN_PORT" != "$JIG_PORT" ] && PORTS="$JIG_PORT $RUN_PORT" ;; esac
echo "[2/5] Stopping the running system (port $PORTS)..."
TOKEN_FILE="$PACKAGE_DIR/logs/.internal-token"
for port in $PORTS; do
    if [ -f "$TOKEN_FILE" ] && [ -n "$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null)" ]; then
        echo "  Checking today's backup before stopping..."
        curl -s -m 900 -X POST -H "X-Jig-Token: $(tr -d '[:space:]' < "$TOKEN_FILE")" \
            "http://127.0.0.1:$port/internal/backup/before-stop" | sed 's/^/    /'
    fi
done
for port in $PORTS; do
    for pid in $(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null); do
        ps -p "$pid" -o comm= 2>/dev/null | grep -qi java && kill "$pid" 2>/dev/null
    done
done
sleep 3
for port in $PORTS; do
    for pid in $(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null); do
        ps -p "$pid" -o comm= 2>/dev/null | grep -qi java && kill -9 "$pid" 2>/dev/null
    done
done
echo "[2/5] System stopped."

echo "[3/5] Downloading and installing v$LATEST_VERSION..."
echo "       $DOWNLOAD_ZIP_URL"
echo
rm -rf "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

bash "$SCRIPT_DIR/update-download.sh" "$DOWNLOAD_ZIP_URL" "$DOWNLOAD_DIR" "$PACKAGE_DIR" "$BACKUP_DIR" "$EXPECTED_SHA256"
RESULT=$?
RESULT_FILE="$PACKAGE_DIR/logs/last-update.txt"
mkdir -p "$PACKAGE_DIR/logs"
if [ "$RESULT" -eq 1 ]; then
    echo "FAILED_NOCHANGE;$CURRENT_VERSION;$LATEST_VERSION;$TIMESTAMP;Download or verification failed. Nothing was changed." > "$RESULT_FILE"
    echo
    echo "[ERROR] Download or verification failed. Nothing was changed."
    echo "        Restarting the current version..."
    open "$PACKAGE_DIR/START-JIG-NETWORK-APP.command"
    echo
    pause_close
    return 1
elif [ "$RESULT" -eq 3 ]; then
    echo "ROLLED_BACK;$CURRENT_VERSION;$LATEST_VERSION;$TIMESTAMP;The update failed and version $CURRENT_VERSION was restored." > "$RESULT_FILE"
    echo
    echo "[ERROR] The update failed. Version $CURRENT_VERSION and its database were restored."
    echo "        Restarting the previous version..."
    open "$PACKAGE_DIR/START-JIG-NETWORK-APP.command"
    echo
    pause_close
    return 1
elif [ "$RESULT" -ne 0 ]; then
    echo "FAILED;$CURRENT_VERSION;$LATEST_VERSION;$TIMESTAMP;The update stopped part-way and could not be undone automatically." > "$RESULT_FILE"
    echo
    echo "[ERROR] The update stopped part-way and could not be undone automatically."
    echo "        Your backup is in: $BACKUP_DIR"
    echo "        Please send a screenshot of this window to gossipred5598@gmail.com"
    echo "        before starting the system again."
    echo
    pause_close
    return 1
fi
echo "SUCCESS;$CURRENT_VERSION;$LATEST_VERSION;$TIMESTAMP;Updated from $CURRENT_VERSION to $LATEST_VERSION." > "$RESULT_FILE"
echo "[3/5] New version installed."

echo "[4/5] Restarting the system..."
open "$PACKAGE_DIR/START-JIG-NETWORK-APP.command"

echo "[5/5] Update complete."
echo
echo "  Updated from v$CURRENT_VERSION to v$LATEST_VERSION"
echo "  Backup location: backups/update-backup-$TIMESTAMP"
echo
echo "The system is restarting. Please wait for the browser to open."
echo
pause_close
return 0
}

main "$@"; exit $?

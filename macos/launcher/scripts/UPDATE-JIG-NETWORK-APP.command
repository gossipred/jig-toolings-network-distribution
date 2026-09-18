#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
APP_DIR="$PACKAGE_DIR/app"
BACKUP_BASE="$PACKAGE_DIR/backups"
TMP_BASE="${TMPDIR:-/tmp}"
DOWNLOAD_DIR="${TMP_BASE%/}/jig-update"
UPDATE_URL="https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"

echo "============================================================"
echo " Jig & Toolings Management System - Semi-Automatic Updater"
echo "============================================================"
echo

# -- Phase 0: Read current version -----------------------------------
CURRENT_VERSION="$(grep -E '^app\.version=' "$APP_DIR/application.properties" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
if [ -z "$CURRENT_VERSION" ]; then
    echo "[ERROR] Cannot read current version from:"
    echo "        $APP_DIR/application.properties"
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

echo "Installed version : $CURRENT_VERSION"
echo "Checking server   : $UPDATE_URL"
echo

# -- Phase 0: Fetch latest.json and compare ---------------------------
LATEST_JSON="$(curl -s -m 10 "$UPDATE_URL" 2>/dev/null)"
if [ -z "$LATEST_JSON" ]; then
    echo "[ERROR] Update check failed. No response from server."
    read -r -p "Press Enter to close..."
    exit 1
fi

LATEST_VERSION="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("latestVersion",""))' 2>/dev/null)"
RELEASE_DATE="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("releaseDate",""))' 2>/dev/null)"
NOTES_URL="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("notesUrl",""))' 2>/dev/null)"
DOWNLOAD_ZIP_URL="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("platforms",{}).get("macos",{}).get("packageUrl",""))' 2>/dev/null)"
EXPECTED_SHA256="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("platforms",{}).get("macos",{}).get("sha256",""))' 2>/dev/null)"

if [ -z "$LATEST_VERSION" ]; then
    echo "[ERROR] Could not parse version information."
    read -r -p "Press Enter to close..."
    exit 1
fi

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo "System is up to date."
    echo "Installed version: $CURRENT_VERSION"
    echo
    read -r -p "Press Enter to close..."
    exit 0
fi

# -- Phase 1: Show update info and confirm -----------------------------
echo "*** UPDATE AVAILABLE ***"
echo
echo "  Installed version : $CURRENT_VERSION"
echo "  Latest version    : $LATEST_VERSION"
echo "  Release date      : $RELEASE_DATE"
echo "  Release notes     : $NOTES_URL"
echo
echo "The following data will be backed up before the update:"
echo "  license/  uploads/  logs/  app/application.properties"
echo
echo "[WARNING] Stop the running system and update the JAR file."
echo "          LAN users will be disconnected during the update."
echo
read -r -p "Proceed with update? (y to continue / any other key to cancel): " CONFIRM
if [ "${CONFIRM,,}" != "y" ]; then
    echo
    echo "Update cancelled."
    read -r -p "Press Enter to close..."
    exit 0
fi

# -- Phase 1: Create timestamped backup --------------------------------
echo
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$BACKUP_BASE/update-backup-$TIMESTAMP"

echo "[1/5] Creating backup in: backups/update-backup-$TIMESTAMP"
mkdir -p "$BACKUP_DIR/app"
[ -d "$PACKAGE_DIR/license" ] && cp -R "$PACKAGE_DIR/license" "$BACKUP_DIR/license"
[ -d "$PACKAGE_DIR/uploads" ] && cp -R "$PACKAGE_DIR/uploads" "$BACKUP_DIR/uploads"
[ -d "$PACKAGE_DIR/logs" ] && cp -R "$PACKAGE_DIR/logs" "$BACKUP_DIR/logs"
[ -f "$APP_DIR/application.properties" ] && cp "$APP_DIR/application.properties" "$BACKUP_DIR/app/"
echo "[1/5] Backup complete."

# -- Phase 2: Stop running system ---------------------------------------
echo "[2/5] Stopping the running system..."
PID="$(lsof -ti:8080 2>/dev/null || true)"
[ -n "$PID" ] && kill -9 $PID 2>/dev/null
sleep 2
echo "[2/5] System stopped."

# -- Phase 3: Download and extract new JAR -------------------------------
echo "[3/5] Downloading new package..."
echo "       $DOWNLOAD_ZIP_URL"
echo

rm -rf "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

if ! bash "$SCRIPT_DIR/update-download.sh" "$DOWNLOAD_ZIP_URL" "$DOWNLOAD_DIR" "$APP_DIR" "$EXPECTED_SHA256"; then
    echo
    echo "[ERROR] Download or extraction failed."
    echo "        Your data backup is safe in: $BACKUP_DIR"
    echo "        The original JAR has not been replaced."
    echo
    echo "        Restart the system manually with START-JIG-NETWORK-APP.command"
    echo "        or restore from backup if needed."
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

echo "[3/5] New JAR installed."

# -- Phase 4: Restart system -----------------------------------------------
echo "[4/5] Restarting the system..."
open "$PACKAGE_DIR/START-JIG-NETWORK-APP.command"

# -- Phase 5: Done -----------------------------------------------------------
echo "[5/5] Update complete."
echo
echo "  Updated from v$CURRENT_VERSION to v$LATEST_VERSION"
echo "  Backup location: backups/update-backup-$TIMESTAMP"
echo
echo "The system is restarting. Please wait for the browser to open."
echo
read -r -p "Press Enter to close..."
exit 0

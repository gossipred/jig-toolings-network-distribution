#!/usr/bin/env bash
# Runs a full backup (database zip + uploaded files, and the external folder if
# one is set) through the running system, same as "Back up now" in System
# Settings. Settings such as the folder are read from there.
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$(cd .. && pwd)"
. "$SCRIPT_DIR/jig-port.sh"
JIG_PORT="$(jig_read_port "$PACKAGE_DIR")"
TOKEN_FILE="$PACKAGE_DIR/logs/.internal-token"

echo "============================================================"
echo " Jig & Toolings Management System - Back Up Now"
echo "============================================================"
echo

RESULT=""
if [ -f "$TOKEN_FILE" ]; then
    echo "Backing up, please wait..."
    RESULT="$(curl -s -m 900 -X POST -H "X-Jig-Token: $(tr -d '[:space:]' < "$TOKEN_FILE")" \
        "http://127.0.0.1:$JIG_PORT/internal/backup/now")"
fi

if [ -z "$RESULT" ]; then
    echo "[ERROR] The system is not running on port $JIG_PORT."
    echo "        Start it with START-JIG-NETWORK-APP.command, then run this again."
    read -r -p "Press Enter to close..."
    exit 1
fi
echo "$RESULT"
case "$RESULT" in
    FAILED*) echo; echo "[ERROR] The backup failed. See the message above, or System Settings - Data Backup."
             read -r -p "Press Enter to close..."; exit 1 ;;
esac
echo
echo "Backups are in backups/auto (and the external folder, if set)."
read -r -p "Press Enter to close..."
exit 0

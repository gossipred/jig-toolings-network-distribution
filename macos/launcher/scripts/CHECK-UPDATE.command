#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
APP_DIR="$PACKAGE_DIR/app"
UPDATE_URL="https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"

echo "============================================================"
echo " Jig & Toolings Management System - Update Checker"
echo "============================================================"
echo

CURRENT_VERSION="$(grep -E '^app\.version=' "$APP_DIR/application.properties" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
if [ -z "$CURRENT_VERSION" ]; then
    echo "[ERROR] Cannot read current version."
    echo "Expected file: $APP_DIR/application.properties"
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

echo "Installed version : $CURRENT_VERSION"
echo "Checking server   : $UPDATE_URL"
echo

LATEST_JSON="$(curl -s -m 10 "$UPDATE_URL" 2>/dev/null)"
if [ -z "$LATEST_JSON" ]; then
    echo "[ERROR] Cannot reach update server. Please check your internet connection."
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

LATEST_VERSION="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("latestVersion",""))' 2>/dev/null)"
RELEASE_DATE="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("releaseDate",""))' 2>/dev/null)"
NOTES_URL="$(echo "$LATEST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("notesUrl",""))' 2>/dev/null)"

if [ -z "$LATEST_VERSION" ]; then
    echo "[ERROR] Could not parse version information."
    read -r -p "Press Enter to close..."
    exit 1
fi

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "System is up to date (v$CURRENT_VERSION)."
else
    echo "*** UPDATE AVAILABLE ***"
    echo
    echo "  Installed version : $CURRENT_VERSION"
    echo "  Latest version    : $LATEST_VERSION"
    echo "  Release date      : $RELEASE_DATE"
    echo "  Release notes     : $NOTES_URL"
    echo
    echo "How to update:"
    echo "  Run scripts/UPDATE-JIG-NETWORK-APP.command — it will back up your"
    echo "  data, stop the system, download and install the new version, then"
    echo "  restart automatically."
    echo
    echo "Data folders to keep (do NOT delete):"
    echo "  license/  uploads/  backups/  logs/  app/application.properties"
fi

echo
read -r -p "Press Enter to close..."

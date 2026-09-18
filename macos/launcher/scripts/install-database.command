#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
DB_NAME="web_fixture_management"

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
    echo "[ERROR] MySQL not found. Please install XAMPP for macOS first, then run this again."
    echo "Download: https://www.apachefriends.org/download.html"
    echo
    read -r -p "Press Enter to close..."
    exit 1
fi

echo
echo "Installing database: $DB_NAME"
echo "MySQL: $MYSQL_EXE"
echo
echo "NOTE: XAMPP default root password is EMPTY. Just press Enter if asked for a password."
echo

if ! "$MYSQL_EXE" -u root < "$PACKAGE_DIR/database/schema.sql"; then
    echo
    echo "[ERROR] Failed to create database. Is MySQL/MariaDB running in the XAMPP control panel?"
    read -r -p "Press Enter to close..."
    exit 1
fi

if ! "$MYSQL_EXE" -u root < "$PACKAGE_DIR/database/seed.sql"; then
    echo
    echo "[ERROR] Failed to insert seed data."
    read -r -p "Press Enter to close..."
    exit 1
fi

echo
echo "============================================"
echo " Database installation completed!"
echo " Now run: scripts/start-system.command"
echo "============================================"
echo
read -r -p "Press Enter to close..."
exit 0

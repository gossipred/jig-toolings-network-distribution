#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
DB_NAME="web_fixture_management"

echo "DANGER: This will remove the app and local package data."
echo
echo "It will delete:"
echo "- $PACKAGE_DIR/app/jig-management-system.jar"
echo "- $PACKAGE_DIR/uploads"
echo "- $PACKAGE_DIR/backups"
echo "- $PACKAGE_DIR/logs"
echo
echo "It will also try to drop MySQL database:"
echo "- $DB_NAME"
echo
read -r -p "Type DELETE to continue: " CONFIRM
if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cancelled."
    read -r -p "Press Enter to close..."
    exit 0
fi

bash "$SCRIPT_DIR/stop-system.command" < /dev/null

[ -f "$PACKAGE_DIR/app/jig-management-system.jar" ] && rm -f "$PACKAGE_DIR/app/jig-management-system.jar"
[ -d "$PACKAGE_DIR/uploads" ] && rm -rf "$PACKAGE_DIR/uploads"
[ -d "$PACKAGE_DIR/backups" ] && rm -rf "$PACKAGE_DIR/backups"
[ -d "$PACKAGE_DIR/logs" ] && rm -rf "$PACKAGE_DIR/logs"

echo "Dropping database $DB_NAME..."
MYSQL_EXE=""
for candidate in /Applications/XAMPP/bin/mysql /Applications/XAMPP/xamppfiles/bin/mysql; do
    [ -x "$candidate" ] && MYSQL_EXE="$candidate" && break
done
[ -z "$MYSQL_EXE" ] && command -v mysql >/dev/null 2>&1 && MYSQL_EXE="mysql"

if [ -n "$MYSQL_EXE" ] && "$MYSQL_EXE" -u root -p -e "DROP DATABASE IF EXISTS $DB_NAME;"; then
    echo "Database dropped."
else
    echo "Database drop failed. Please check MySQL manually."
fi

echo
echo "Full uninstall completed."
read -r -p "Press Enter to close..."

#!/usr/bin/env bash
# Creates the system's database (first installation) and the dedicated
# database account jig_app; the settings are switched to jig_app.
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$(cd .. && pwd)"
. "$SCRIPT_DIR/jig-db.sh"
. "$SCRIPT_DIR/jig-db-account.sh"

pause_close() { read -r -p "Press Enter to close..." _ || true; }
fail_exit() { echo; echo "[ERROR] $1"; echo; pause_close; exit 1; }

if ! jig_db_load "$PACKAGE_DIR"; then
    echo
    echo "[ERROR] MySQL not found. Please install XAMPP for macOS first, then run this again."
    echo "Download: https://www.apachefriends.org/download.html"
    echo
    pause_close
    exit 1
fi

echo
echo "Installing database: $JIG_DB_NAME"
echo "MySQL: $JIG_DB_BIN"
echo

jig_mysql < "$PACKAGE_DIR/database/schema.sql" \
    || fail_exit "Failed to create database. Is MySQL/MariaDB running?"
jig_mysql < "$PACKAGE_DIR/database/seed.sql" \
    || fail_exit "Failed to insert seed data."

# A fresh schema.sql already contains every migration, so record them all as
# applied; the updater then only runs migrations added in later versions.
jig_mysql -e "CREATE TABLE IF NOT EXISTS \`$JIG_DB_NAME\`.schema_migrations (filename VARCHAR(255) NOT NULL PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)" \
    || fail_exit "Failed to create schema_migrations."
for f in "$PACKAGE_DIR"/database/migration-*.sql; do
    [ -f "$f" ] && jig_mysql -e "INSERT IGNORE INTO \`$JIG_DB_NAME\`.schema_migrations (filename) VALUES ('$(basename "$f")')"
done

jig_db_ensure_app_account "$PACKAGE_DIR" \
    || fail_exit "The database was created, but the dedicated database account could not be set up. Run this script again."

echo
echo "============================================"
echo " Database installation completed!"
echo " Now run: START-JIG-NETWORK-APP.command"
echo "============================================"
echo
pause_close
exit 0

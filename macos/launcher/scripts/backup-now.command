#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."
BACKUP_ROOT="$PACKAGE_DIR/backups"
DB_NAME="web_fixture_management"

MYSQLDUMP_EXE=""
for candidate in /Applications/XAMPP/bin/mysqldump /Applications/XAMPP/xamppfiles/bin/mysqldump; do
    if [ -x "$candidate" ]; then
        MYSQLDUMP_EXE="$candidate"
        break
    fi
done
if [ -z "$MYSQLDUMP_EXE" ] && command -v mysqldump >/dev/null 2>&1; then
    MYSQLDUMP_EXE="mysqldump"
fi

TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/backup-$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

echo "Creating database backup..."
if ! "$MYSQLDUMP_EXE" -u root -p "$DB_NAME" > "$BACKUP_DIR/web_fixture_management.sql"; then
    echo
    echo "Backup failed. Check MySQL service, username, password, and mysqldump command."
    read -r -p "Press Enter to close..."
    exit 1
fi

echo "Copying uploaded files..."
if [ -d "$PACKAGE_DIR/uploads" ]; then
    mkdir -p "$BACKUP_DIR/uploads"
    cp -R "$PACKAGE_DIR/uploads/." "$BACKUP_DIR/uploads/" 2>/dev/null
fi

echo
echo "Backup completed:"
echo "$BACKUP_DIR"
read -r -p "Press Enter to close..."
exit 0

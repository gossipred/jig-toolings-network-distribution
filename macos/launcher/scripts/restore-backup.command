#!/usr/bin/env bash
# Restores the database from a backup zip: pick one from backups/auto, or drag
# a zip (e.g. from the external drive) into the Terminal window when asked.
# The current database is saved first to backups/before-restore-<time>.sql.
# macOS ships bash 3.2 — no bash 4 syntax. JIG_MYSQL_BIN overrides (testing).

main() {
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$(cd .. && pwd)"
AUTO_DIR="$PACKAGE_DIR/backups/auto"
PROPS="$PACKAGE_DIR/app/application.properties"
. "$SCRIPT_DIR/jig-port.sh"
JIG_PORT="$(jig_read_port "$PACKAGE_DIR")"

pause_exit() { echo; read -r -p "Press Enter to close..."; return "$1"; }
prop() {
    awk -v k="$1" '/^[ \t]*[#!]/ { next }
        { key = $0; sub(/=.*/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", key)
          if (key == k && index($0, "=") > 0) { v = substr($0, index($0, "=") + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); val = v } }
        END { print val }' "$PROPS"
}

echo "============================================================"
echo " Jig & Toolings Management System - Restore Backup"
echo "============================================================"
echo

FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(ls -1t "$AUTO_DIR"/jig-backup-*.zip 2>/dev/null | head -n 20)   # newest first by time
if [ "${#FILES[@]}" -eq 0 ]; then
    echo "No backups found in $AUTO_DIR"
else
    i=1
    for f in "${FILES[@]}"; do echo "  $i. $(basename "$f")"; i=$((i + 1)); done
fi
echo
echo "Type the number of the backup to restore, or drag a backup zip file"
echo "(for example from the external drive) into this window, then press Enter."
read -r -p "(Press Enter alone to cancel): " CHOICE
# Terminal escapes spaces in dragged paths ("\ ") and may add quotes.
CHOICE="$(printf '%s' "$CHOICE" | sed -e 's/\\ / /g' -e "s/^[[:space:]'\"]*//" -e "s/[[:space:]'\"]*\$//")"
if [ -z "$CHOICE" ]; then
    echo "Cancelled. Nothing was changed."
    pause_exit 0; return
fi
case "$CHOICE" in
    *[!0-9]*) ZIP="$CHOICE" ;;
    *) if [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#FILES[@]}" ]; then ZIP="${FILES[$((CHOICE - 1))]}"; else ZIP=""; fi ;;
esac
if [ -z "$ZIP" ] || [ ! -f "$ZIP" ] || [ "${ZIP##*.}" != "zip" ]; then
    echo "[ERROR] \"$CHOICE\" is not a backup in the list or a zip file. Nothing was changed."
    pause_exit 1; return
fi

echo
echo "  Backup to restore: $ZIP"
echo
echo "[WARNING] The CURRENT database will be REPLACED by this backup."
echo "          Anything added or changed after the backup is lost."
echo "          The current database is saved first to backups/before-restore-*.sql."
echo "          The system stops during the restore."
echo
read -r -p "Type YES (capital letters) to restore: " OK
if [ "$OK" != "YES" ]; then
    echo "Cancelled. Nothing was changed."
    pause_exit 0; return
fi

DB_USER="$(prop spring.datasource.username)"; [ -z "$DB_USER" ] && DB_USER=root
DB_PASS="$(prop spring.datasource.password)"
DB_NAME="$(prop spring.datasource.url | sed -n 's|^jdbc:mysql://[^/]*/\([^?;]*\).*|\1|p')"
[ -z "$DB_NAME" ] && DB_NAME=web_fixture_management
MYSQL_BIN="${JIG_MYSQL_BIN:-}"
if [ -z "$MYSQL_BIN" ]; then
    for d in /Applications/XAMPP/bin /Applications/XAMPP/xamppfiles/bin; do [ -x "$d/mysql" ] && MYSQL_BIN="$d" && break; done
fi
if [ -z "$MYSQL_BIN" ]; then
    echo "[ERROR] MySQL (XAMPP) not found."
    pause_exit 1; return
fi
[ -n "$DB_PASS" ] && export MYSQL_PWD="$DB_PASS"
if ! "$MYSQL_BIN/mysql" -u "$DB_USER" -e "SELECT 1" >/dev/null 2>&1; then
    echo "[ERROR] MySQL is not responding. Run scripts/setup-mysql-autostart.command, then try again."
    pause_exit 1; return
fi

ENTRY="$(unzip -Z1 "$ZIP" 2>/dev/null | grep -E '^database-.*\.sql$' | head -n 1)"
if [ -z "$ENTRY" ]; then
    echo "[ERROR] This zip does not contain a database backup (database-*.sql). Nothing was changed."
    pause_exit 1; return
fi

echo
echo "[1/3] Stopping the system (port $JIG_PORT)..."
PIDS="$(jig_java_pids_on_port "$JIG_PORT")"
if [ -n "$PIDS" ]; then
    kill $PIDS 2>/dev/null; sleep 3
    PIDS="$(jig_java_pids_on_port "$JIG_PORT")"; [ -n "$PIDS" ] && kill -9 $PIDS 2>/dev/null
fi

echo "[2/3] Restoring the database..."
WORK="$(mktemp -d)"
if ! unzip -p "$ZIP" "$ENTRY" > "$WORK/restore.sql" || [ ! -s "$WORK/restore.sql" ]; then
    rm -rf "$WORK"
    echo "[ERROR] Could not read the backup zip. Nothing was changed."
    pause_exit 1; return
fi
mkdir -p "$PACKAGE_DIR/backups"
SAFETY="$PACKAGE_DIR/backups/before-restore-$(date +%Y-%m-%d_%H%M%S).sql"
if ! "$MYSQL_BIN/mysqldump" -u "$DB_USER" --default-character-set=utf8mb4 --single-transaction \
        --result-file="$SAFETY" "$DB_NAME" || [ ! -s "$SAFETY" ]; then
    rm -rf "$WORK"
    echo "[ERROR] Could not save the current database first, so nothing was restored."
    pause_exit 1; return
fi
echo "    Current database saved: $SAFETY"
if ! ERR="$("$MYSQL_BIN/mysql" -u "$DB_USER" --default-character-set=utf8mb4 "$DB_NAME" < "$WORK/restore.sql" 2>&1)"; then
    rm -rf "$WORK"
    echo "[ERROR] Restore failed: $ERR"
    echo "        Previous data: $SAFETY"
    echo "        Contact gossipred5598@gmail.com for help."
    pause_exit 1; return
fi
rm -rf "$WORK"
echo "    Database restored from $(basename "$ZIP")"

echo "[3/3] Done."
echo
echo "[OK] Restore completed."
echo "     Start the system with START-JIG-NETWORK-APP.command, then sign in and check the data."
pause_exit 0
}

main "$@"; exit $?

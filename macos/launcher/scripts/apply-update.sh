#!/usr/bin/env bash
# Installs an extracted release package over an existing installation.
# Runs from the NEW package (called by update-download.sh).
#   1. Back up the database (mysqldump)
#   2. Replace program files; keep license/, uploads/, logs/, backups/
#   3. Merge app/application.properties: keep the customer's values (port,
#      database password...), take the new app.version, add new settings
#   4. Apply database migrations that have not run yet (schema_migrations)
# Usage: apply-update.sh <new_package_dir> <installed_package_dir> <backup_dir>
# Exit codes: 0 = done, 1 = nothing changed, 2 = failed part-way.
# Only macOS built-ins (bash 3.2, awk, rsync) — no python3 on a clean Mac.
# JIG_MYSQL_BIN overrides the MySQL bin folder (for testing).

main() {
set -u
SRC="$1"
PKG="$2"
BACKUP_DIR="$3"
PROPS="$PKG/app/application.properties"
NEW_PROPS="$SRC/app/application.properties"

prop() {
    awk -v k="$2" '
        /^[ \t]*[#!]/ { next }
        { key = $0; sub(/=.*/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", key)
          if (key == k && index($0, "=") > 0) { v = substr($0, index($0, "=") + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); val = v } }
        END { print val }' "$1"
}

if [ ! -f "$PROPS" ] || [ ! -f "$NEW_PROPS" ]; then
    echo "[ERROR] application.properties not found (installed or new package)."
    return 1
fi

NEW_VERSION="$(prop "$NEW_PROPS" app.version)"
DB_USER="$(prop "$PROPS" spring.datasource.username)"; [ -z "$DB_USER" ] && DB_USER=root
DB_PASS="$(prop "$PROPS" spring.datasource.password)"
DB_NAME="$(prop "$PROPS" spring.datasource.url | sed -n 's|^jdbc:mysql://[^/]*/\([^?;]*\).*|\1|p')"
[ -z "$DB_NAME" ] && DB_NAME=web_fixture_management

MYSQL_BIN="${JIG_MYSQL_BIN:-}"
if [ -z "$MYSQL_BIN" ]; then
    for d in /Applications/XAMPP/bin /Applications/XAMPP/xamppfiles/bin; do
        [ -x "$d/mysql" ] && MYSQL_BIN="$d" && break
    done
fi
if [ -z "$MYSQL_BIN" ] && command -v mysql >/dev/null 2>&1; then
    MYSQL_BIN="$(dirname "$(command -v mysql)")"
fi
if [ -z "$MYSQL_BIN" ]; then
    echo "[ERROR] MySQL (XAMPP) not found."
    return 1
fi
if [ -n "$DB_PASS" ]; then export MYSQL_PWD="$DB_PASS"; fi
sql() { "$MYSQL_BIN/mysql" -u "$DB_USER" --default-character-set=utf8mb4 "$@"; }

# -- 1. Database backup (nothing has changed yet, so failing here is safe) --
echo "    Backing up database $DB_NAME..."
if ! sql -N -B -e "SELECT 1" >/dev/null 2>&1; then
    echo "[ERROR] MySQL is not responding. Start MySQL and run the update again."
    return 1
fi
DUMP="$BACKUP_DIR/database-$DB_NAME.sql"
mkdir -p "$BACKUP_DIR"
if ! "$MYSQL_BIN/mysqldump" -u "$DB_USER" --default-character-set=utf8mb4 --single-transaction \
        --result-file="$DUMP" "$DB_NAME" || [ ! -s "$DUMP" ]; then
    echo "[ERROR] Database backup failed. Nothing was changed."
    return 1
fi
echo "    Database backup: $DUMP"

fail() { echo "[ERROR] $1"; echo "        Backup of files and database: $BACKUP_DIR"; return 2; }

# -- 2. Program files ----------------------------------------------------
echo "    Replacing program files..."
for item in "$SRC"/* ; do
    name="$(basename "$item")"
    case "$name" in license|uploads|logs|backups) continue ;; esac
    if [ -d "$item" ]; then
        [ "$name" = "runtime" ] && rm -rf "$PKG/runtime"
        mkdir -p "$PKG/$name"
        if [ "$name" = "app" ]; then
            rsync -a -I --exclude application.properties "$item/" "$PKG/$name/" || { fail "Could not copy $name/"; return 2; }
        else
            rsync -a -I "$item/" "$PKG/$name/" || { fail "Could not copy $name/"; return 2; }
        fi
    else
        cp -p "$item" "$PKG/$name" || { fail "Could not copy $name"; return 2; }
    fi
done

# -- 3. Settings merge -----------------------------------------------------
echo "    Updating settings (your port and database settings are kept)..."
awk -v ver="$NEW_VERSION" '
    function keyof(line,   k) { k = line; sub(/=.*/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k); return k }
    function iskv(line) { return line !~ /^[ \t]*[#!]/ && index(line, "=") > 1 }
    NR == FNR { if (iskv($0)) old[keyof($0)] = 1; lines[++n] = $0; next }
    iskv($0) { k = keyof($0); if (!(k in old) && !(k in seen)) { add[++m] = $0; seen[k] = 1 } }
    END {
        for (i = 1; i <= n; i++) { l = lines[i]; if (l ~ /^[ \t]*app\.version[ \t]*=/) l = "app.version=" ver; print l }
        if (m > 0) { print ""; print "# Added by update to v" ver; for (i = 1; i <= m; i++) print add[i] }
    }' "$PROPS" "$NEW_PROPS" > "$PROPS.tmp" && mv "$PROPS.tmp" "$PROPS" || { fail "Could not update settings"; return 2; }

# -- 4. Database migrations ----------------------------------------------
HAS_TABLE="$(sql -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='schema_migrations'" 2>&1)" \
    || { fail "Cannot read the database: $HAS_TABLE"; return 2; }
sql -e "CREATE TABLE IF NOT EXISTS \`$DB_NAME\`.schema_migrations (filename VARCHAR(255) NOT NULL PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)" \
    || { fail "Cannot create schema_migrations"; return 2; }
if [ "$HAS_TABLE" != "1" ]; then
    # First run of this mechanism. Migrations dated up to 2026-05-23 predate
    # every customer package: its schema.sql already contains them.
    for f in "$PKG"/database/migration-*.sql; do
        [ -f "$f" ] || continue
        fname="$(basename "$f")"; fdate="${fname#migration-}"; fdate="${fdate:0:10}"
        if [[ "$fdate" < "2026-05-24" ]]; then
            sql -e "INSERT IGNORE INTO \`$DB_NAME\`.schema_migrations (filename) VALUES ('$fname')"
        fi
    done
fi
APPLIED="$(sql -N -B -e "SELECT filename FROM \`$DB_NAME\`.schema_migrations")"
for f in "$PKG"/database/migration-*.sql; do   # glob expands in sorted order; paths may contain spaces
    [ -f "$f" ] || continue
    fname="$(basename "$f")"
    if printf '%s\n' "$APPLIED" | grep -qx "$fname"; then continue; fi
    echo "    Applying database change: $fname"
    ERR="$(sql "$DB_NAME" < "$f" 2>&1)" || { fail "Database change $fname failed: $ERR"; return 2; }
    sql -e "INSERT INTO \`$DB_NAME\`.schema_migrations (filename) VALUES ('$fname')"
done

echo "    Now at version $NEW_VERSION."
return 0
}

main "$@"; exit $?

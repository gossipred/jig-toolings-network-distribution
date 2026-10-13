# Shared database helpers, sourced by the .command/.sh scripts:
#     . "$SCRIPT_DIR/jig-db.sh"
# Every script connects with the account in app/application.properties
# (jig_app since v2.0), never an assumed root without a password, so the
# customer can give root a password. The password reaches MySQL through
# MYSQL_PWD set on that one command only — never on the command line.
# macOS ships bash 3.2: keep this file free of bash 4 syntax.
# JIG_MYSQL_BIN overrides the MySQL bin folder (tests).

# jig_prop <file> <key>: value of a key in a .properties file ("" if absent).
jig_prop() {
    awk -v k="$2" '
        /^[ \t]*[#!]/ { next }
        { key = $0; sub(/=.*/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", key)
          if (key == k && index($0, "=") > 0) { v = substr($0, index($0, "=") + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); val = v } }
        END { print val }' "$1" 2>/dev/null
}

# jig_props_set <file> <key> <value>: replace the key's line (first one; later
# duplicates are dropped) or append it. Values must not contain backslashes.
jig_props_set() {
    awk -v k="$2" -v v="$3" '
        function keyof(line,   x) { x = line; sub(/=.*/, "", x); gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
        !/^[ \t]*[#!]/ && index($0, "=") > 0 && keyof($0) == k { if (!done) print k "=" v; done = 1; next }
        { print }
        END { if (!done) print k "=" v }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

jig_find_mysql_bin() {
    if [ -n "${JIG_MYSQL_BIN:-}" ]; then echo "$JIG_MYSQL_BIN"; return 0; fi
    local d
    for d in /Applications/XAMPP/bin /Applications/XAMPP/xamppfiles/bin; do
        if [ -x "$d/mysql" ]; then echo "$d"; return 0; fi
    done
    if command -v mysql >/dev/null 2>&1; then dirname "$(command -v mysql)"; return 0; fi
    return 1
}

# jig_db_load <package_dir>: read the connection settings. Returns 1 when no
# MySQL client is found.
jig_db_load() {
    local props="$1/app/application.properties" url hostport
    JIG_DB_USER="$(jig_prop "$props" spring.datasource.username)"
    [ -z "$JIG_DB_USER" ] && JIG_DB_USER=root
    JIG_DB_PASS="$(jig_prop "$props" spring.datasource.password)"
    url="$(jig_prop "$props" spring.datasource.url)"
    JIG_DB_NAME="$(printf '%s' "$url" | sed -n 's|^jdbc:[a-z]*://[^/]*/\([^?;]*\).*|\1|p')"
    [ -z "$JIG_DB_NAME" ] && JIG_DB_NAME=web_fixture_management
    hostport="$(printf '%s' "$url" | sed -n 's|^jdbc:[a-z]*://\([^/]*\)/.*|\1|p')"
    JIG_DB_HOST="${hostport%%:*}"
    [ -z "$JIG_DB_HOST" ] && JIG_DB_HOST=localhost
    JIG_DB_PORT=""
    case "$hostport" in *:*) JIG_DB_PORT="${hostport##*:}" ;; esac
    JIG_DB_BIN="$(jig_find_mysql_bin)" || return 1
    return 0
}

# _jig_db_run <tool> [args...]: run mysql/mysqldump with the loaded connection.
_jig_db_run() {
    local tool="$1"; shift
    if [ -n "$JIG_DB_PORT" ]; then set -- -P "$JIG_DB_PORT" "$@"; fi
    MYSQL_PWD="$JIG_DB_PASS" "$JIG_DB_BIN/$tool" -h "$JIG_DB_HOST" -u "$JIG_DB_USER" \
        --default-character-set=utf8mb4 "$@"
}

jig_mysql()     { _jig_db_run mysql "$@"; }
jig_mysqldump() { _jig_db_run mysqldump --no-tablespaces --single-transaction "$@"; }
jig_db_ping()   { jig_mysql -N -B -e "SELECT 1" >/dev/null 2>&1; }

# Shared database helpers, sourced by the .command/.sh scripts:
#     . "$SCRIPT_DIR/jig-db.sh"
# Every script connects with the account in app/application.properties
# (jig_app since v2.0), never an assumed root without a password, so the
# customer can give root a password. The password reaches MySQL through
# MYSQL_PWD set on that one command only — never on the command line.
# The client ignores option files (~/.my.cnf, XAMPP my.cnf: a password there
# would override MYSQL_PWD) and always uses TCP like the Java application, so
# "localhost" never falls back to a Unix socket of some other server.
# macOS ships bash 3.2: keep this file free of bash 4 syntax.
# JIG_MYSQL_BIN overrides the MySQL bin folder (tests).
#
# Properties support is the subset the product writes: key=value lines,
# # and ! comments, CRLF tolerated. No ':' separators, '\' escapes or line
# continuations; values are trimmed (Java keeps trailing spaces).

# jig_prop <file> <key>: value of a key in a .properties file ("" if absent).
jig_prop() {
    awk -v k="$2" '
        { sub(/\r$/, "") }
        /^[ \t]*[#!]/ { next }
        { key = $0; sub(/=.*/, "", key); gsub(/^[ \t]+|[ \t]+$/, "", key)
          if (key == k && index($0, "=") > 0) { v = substr($0, index($0, "=") + 1); gsub(/^[ \t]+|[ \t]+$/, "", v); val = v } }
        END { print val }' "$1" 2>/dev/null
}

# jig_props_set <file> <key> <value>: replace the key's line (first one; later
# duplicates are dropped) or append it. Values must not contain backslashes.
# The file keeps its permissions (it may hold the database password).
jig_props_set() {
    ( umask 077
      awk -v k="$2" -v v="$3" '
        function keyof(line,   x) { x = line; sub(/\r$/, "", x); sub(/=.*/, "", x); gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
        !/^[ \t]*[#!]/ && index($0, "=") > 0 && keyof($0) == k { if (!done) print k "=" v; done = 1; next }
        { print }
        END { if (!done) print k "=" v }' "$1" > "$1.tmp" ) || { rm -f "$1.tmp"; return 1; }
    # Overwrite in place (not mv) so the original mode and owner stay.
    cat "$1.tmp" > "$1" && rm -f "$1.tmp"
}

jig_find_mysql_bin() {
    if [ -n "${JIG_MYSQL_BIN:-}" ]; then
        [ -x "$JIG_MYSQL_BIN/mysql" ] && { echo "$JIG_MYSQL_BIN"; return 0; }
        return 1
    fi
    local d
    for d in /Applications/XAMPP/bin /Applications/XAMPP/xamppfiles/bin; do
        if [ -x "$d/mysql" ]; then echo "$d"; return 0; fi
    done
    if command -v mysql >/dev/null 2>&1; then dirname "$(command -v mysql)"; return 0; fi
    return 1
}

# jig_db_load <package_dir>: read the connection settings. Returns 1 when the
# database URL is not jdbc:mysql://host[:port]/db or no MySQL client is found.
jig_db_load() {
    local props="$1/app/application.properties" url hostport
    JIG_DB_USER="$(jig_prop "$props" spring.datasource.username)"
    [ -z "$JIG_DB_USER" ] && JIG_DB_USER=root
    JIG_DB_PASS="$(jig_prop "$props" spring.datasource.password)"
    url="$(jig_prop "$props" spring.datasource.url)"
    [ -z "$url" ] && url="jdbc:mysql://localhost/web_fixture_management"
    # jdbc:mysql://host[:port]/db[?...] (the form the product writes)
    hostport="$(printf '%s' "$url" | sed -n 's|^jdbc:[a-z]*://\([^/]*\)/.*|\1|p')"
    JIG_DB_NAME="$(printf '%s' "$url" | sed -n 's|^jdbc:[a-z]*://[^/]*/\([^?;]*\).*|\1|p')"
    if [ -z "$hostport" ] || [ -z "$JIG_DB_NAME" ]; then
        echo "[ERROR] Unsupported database URL in $props: $url" >&2
        return 1
    fi
    JIG_DB_HOST="${hostport%%:*}"
    JIG_DB_PORT=""
    case "$hostport" in *:*) JIG_DB_PORT="${hostport##*:}" ;; esac
    JIG_DB_BIN="$(jig_find_mysql_bin)" || return 1
    return 0
}

# jig_db_run_as <user> <password> <tool> [args...]: run mysql/mysqldump against
# the loaded host/port with the given account.
jig_db_run_as() {
    local user="$1" pass="$2" tool="$3"; shift 3
    if [ -n "${JIG_DB_PORT:-}" ]; then set -- -P "$JIG_DB_PORT" "$@"; fi
    MYSQL_PWD="$pass" "$JIG_DB_BIN/$tool" --no-defaults --protocol=TCP \
        -h "$JIG_DB_HOST" -u "$user" --default-character-set=utf8mb4 "$@"
}

jig_mysql()     { jig_db_run_as "$JIG_DB_USER" "$JIG_DB_PASS" mysql "$@"; }
jig_mysqldump() { jig_db_run_as "$JIG_DB_USER" "$JIG_DB_PASS" mysqldump --no-tablespaces --single-transaction "$@"; }
jig_db_ping()   { jig_mysql -N -B -e "SELECT 1" >/dev/null 2>&1; }

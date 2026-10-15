# Minimal helpers for the launcher-script tests. bash 3.2 compatible.
# Source it from a test file:  . "$(dirname "$0")/../lib.sh"
DIST_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_REPO="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
CORE_DB="$CORE_REPO/customer-package/mac-network-app/database"
MAC_SCRIPTS="$DIST_REPO/macos/launcher/scripts"
WIN_SCRIPTS="$DIST_REPO/windows/launcher/scripts"
TEST_BIN="${JIG_TEST_MYSQL_BIN:-/Applications/XAMPP/xamppfiles/bin}"
TEST_PORT=13306
TEST_ROOT_PASS=""
export JIG_MYSQL_BIN="$TEST_BIN"
TESTS_RUN=0
TESTS_FAILED=0
WORK_ROOT="$(mktemp -d)"

root_sql() {
    MYSQL_PWD="$TEST_ROOT_PASS" "$TEST_BIN/mysql" --no-defaults -h 127.0.0.1 -P "$TEST_PORT" -u root -N -B "$@"
}

reset_db() {
    root_sql -e "DROP DATABASE IF EXISTS web_fixture_management;
        DROP USER IF EXISTS 'jig_app'@'localhost'; DROP USER IF EXISTS 'jig_app'@'127.0.0.1'; DROP USER IF EXISTS 'jig_app'@'::1';
        DROP USER IF EXISTS 'custom_user'@'localhost'; DROP USER IF EXISTS 'custom_user'@'127.0.0.1';"
}

# The database exactly as a v1.4.3 customer has it: schema + seed run as root,
# and every shipped migration recorded as applied (what install-database does).
install_v143_db() {
    root_sql < "$CORE_DB/schema.sql" && root_sql < "$CORE_DB/seed.sql" || return 1
    root_sql -e "CREATE TABLE web_fixture_management.schema_migrations (filename VARCHAR(255) NOT NULL PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)" || return 1
    local f
    for f in "$CORE_DB"/migration-*.sql; do
        root_sql -e "INSERT INTO web_fixture_management.schema_migrations (filename) VALUES ('$(basename "$f")')" || return 1
    done
}

# make_install <dir> <db_user> <db_pass> [version]: a fake installation folder
# using the current launcher scripts and the test database.
make_install() {
    mkdir -p "$1/app" "$1/scripts" "$1/database" "$1/logs" "$1/license" "$1/uploads"
    cp "$MAC_SCRIPTS"/* "$1/scripts/"
    cp "$CORE_DB"/*.sql "$1/database/"
    echo "fake jar" > "$1/app/jig-management-system.jar"
    cat > "$1/app/application.properties" <<EOF
spring.datasource.url=jdbc:mysql://127.0.0.1:$TEST_PORT/web_fixture_management?useSSL=false
spring.datasource.username=$2
spring.datasource.password=$3
app.version=${4:-1.4.3}
server.port=18080
EOF
}

prop_of() { grep -E "^$2=" "$1" | tail -n 1 | cut -d= -f2-; }

check() {
    [ "$1" = "$2" ] && return 0
    echo "    $3"; echo "      expected: [$2]"; echo "      actual:   [$1]"
    return 1
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if ( set -u; "$1" ); then echo "PASS $1"; else echo "FAIL $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); fi
}

finish() {
    rm -rf "$WORK_ROOT"
    echo; echo "$TESTS_RUN tests, $TESTS_FAILED failed"
    [ "$TESTS_FAILED" -eq 0 ]
}

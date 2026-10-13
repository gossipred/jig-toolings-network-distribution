#!/usr/bin/env bash
# macOS launcher-script tests for the database account (v2.0 plan 1).
# Needs the test MariaDB:  bash tests/test-mariadb.sh start
. "$(dirname "$0")/../lib.sh"

test_sandbox_is_not_production() {
    check "$(root_sql -e 'SELECT @@port')" "13306" "tests must run on the throwaway MariaDB"
}

test_db_load_parses_props() {
    local d="$WORK_ROOT/load"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"
    jig_db_load "$d" || return 1
    check "$JIG_DB_USER" "root" "user" &&
    check "$JIG_DB_PASS" "" "password" &&
    check "$JIG_DB_NAME" "web_fixture_management" "database name" &&
    check "$JIG_DB_HOST" "127.0.0.1" "host" &&
    check "$JIG_DB_PORT" "13306" "port" &&
    check "$JIG_DB_BIN" "$TEST_BIN" "mysql bin"
}

test_db_load_defaults_for_old_props() {
    local d="$WORK_ROOT/old"; mkdir -p "$d/app"
    printf 'spring.datasource.url=jdbc:mysql://localhost/web_fixture_management\n' > "$d/app/application.properties"
    . "$MAC_SCRIPTS/jig-db.sh"
    jig_db_load "$d" || return 1
    check "$JIG_DB_USER" "root" "missing username means root" &&
    check "$JIG_DB_HOST" "localhost" "host" &&
    check "$JIG_DB_PORT" "" "no port"
}

test_ping_with_root_no_password() {
    reset_db; local d="$WORK_ROOT/ping"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; jig_db_load "$d" && jig_db_ping
}

test_ping_custom_password_special_chars() {
    reset_db
    root_sql <<'SQL'
CREATE DATABASE web_fixture_management;
CREATE USER 'custom_user'@'127.0.0.1' IDENTIFIED BY 'p@ss w$rd"x';
GRANT ALL PRIVILEGES ON web_fixture_management.* TO 'custom_user'@'127.0.0.1';
SQL
    local d="$WORK_ROOT/special"; make_install "$d" custom_user 'p@ss w$rd"x'
    . "$MAC_SCRIPTS/jig-db.sh"; jig_db_load "$d" || return 1
    check "$JIG_DB_PASS" 'p@ss w$rd"x' "password read verbatim" && jig_db_ping
}

test_props_set_replaces_and_appends() {
    local f="$WORK_ROOT/p.properties"
    printf 'a=1\n# a=comment\nb=2\na=3\n' > "$f"
    . "$MAC_SCRIPTS/jig-db.sh"
    jig_props_set "$f" a 9 && jig_props_set "$f" c 7 || return 1
    check "$(cat "$f")" "$(printf 'a=9\n# a=comment\nb=2\nc=7')" "a replaced once, duplicate removed, c appended"
}

test_password_not_on_command_line() {
    grep -n 'mysql.*-p' "$MAC_SCRIPTS/jig-db.sh" | grep -v -- '-P' && return 1
    grep -q 'MYSQL_PWD="$JIG_DB_PASS"' "$MAC_SCRIPTS/jig-db.sh"
}

run_test test_sandbox_is_not_production
run_test test_db_load_parses_props
run_test test_db_load_defaults_for_old_props
run_test test_ping_with_root_no_password
run_test test_ping_custom_password_special_chars
run_test test_props_set_replaces_and_appends
run_test test_password_not_on_command_line
finish

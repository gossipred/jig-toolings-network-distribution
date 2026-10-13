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
CREATE USER 'custom_user'@'127.0.0.1' IDENTIFIED BY 'p@ss w$rd"x''y#z';
GRANT ALL PRIVILEGES ON web_fixture_management.* TO 'custom_user'@'127.0.0.1';
SQL
    local d="$WORK_ROOT/special"; make_install "$d" custom_user "p@ss w\$rd\"x'y#z"
    . "$MAC_SCRIPTS/jig-db.sh"; jig_db_load "$d" || return 1
    check "$JIG_DB_PASS" "p@ss w\$rd\"x'y#z" "password read verbatim" && jig_db_ping
}

test_props_set_replaces_and_appends() {
    local f="$WORK_ROOT/p.properties"
    printf 'a=1\n# a=comment\nb=2\na=3\n' > "$f"
    . "$MAC_SCRIPTS/jig-db.sh"
    jig_props_set "$f" a 9 && jig_props_set "$f" c 7 || return 1
    check "$(cat "$f")" "$(printf 'a=9\n# a=comment\nb=2\nc=7')" "a replaced once, duplicate removed, c appended"
}

# A stub mysql that records how it was called.
make_stub_bin() {
    mkdir -p "$1"
    cat > "$1/mysql" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" > "$(dirname "$0")/args"
printf '%s' "${MYSQL_PWD-<unset>}" > "$(dirname "$0")/pwd"
STUB
    chmod +x "$1/mysql"
}

test_password_only_in_env_of_that_command() {
    local d="$WORK_ROOT/stub" bin="$WORK_ROOT/stubbin"; make_install "$d" someone 'S3cret-Pw'
    make_stub_bin "$bin"
    . "$MAC_SCRIPTS/jig-db.sh"
    JIG_MYSQL_BIN="$bin" jig_db_load "$d" || return 1
    unset MYSQL_PWD
    jig_mysql -e "SELECT 1"
    ! grep -q 'S3cret-Pw' "$bin/args" || { echo "    password found in argv"; return 1; }
    check "$(cat "$bin/pwd")" "S3cret-Pw" "password passed via MYSQL_PWD" &&
    check "${MYSQL_PWD-<unset>}" "<unset>" "MYSQL_PWD not left in the caller" &&
    check "$(head -n 2 "$bin/args" | tr '\n' ' ')" "--no-defaults --protocol=TCP " "option files ignored, TCP forced"
}

test_localhost_uses_tcp_port() {
    # "localhost" must not fall back to the Unix socket (that would be the
    # production server on port 3306); the query is read-only either way.
    reset_db; local d="$WORK_ROOT/lh"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"
    jig_props_set "$d/app/application.properties" spring.datasource.url "jdbc:mysql://localhost:$TEST_PORT/web_fixture_management"
    jig_db_load "$d" || return 1
    check "$(jig_mysql -N -B -e 'SELECT @@port')" "$TEST_PORT" "localhost reached the test server over TCP"
}

test_client_option_files_ignored() {
    reset_db; local d="$WORK_ROOT/cnf"; make_install "$d" root ""
    local fakehome="$WORK_ROOT/home"; mkdir -p "$fakehome"
    printf '[client]\npassword=wrongpw\nuser=nobody\n' > "$fakehome/.my.cnf"
    . "$MAC_SCRIPTS/jig-db.sh"; jig_db_load "$d" || return 1
    HOME="$fakehome" jig_db_ping || { echo "    ~/.my.cnf overrode the settings file"; return 1; }
}

test_props_set_keeps_file_mode() {
    local f="$WORK_ROOT/mode.properties"; printf 'a=1\n' > "$f"; chmod 600 "$f"
    . "$MAC_SCRIPTS/jig-db.sh"; jig_props_set "$f" a 2 || return 1
    check "$(stat -f %Lp "$f")" "600" "mode kept" && check "$(cat "$f")" "a=2" "value"
}

test_props_crlf() {
    local d="$WORK_ROOT/crlf"; mkdir -p "$d/app"
    printf 'spring.datasource.url=jdbc:mysql://127.0.0.1:13306/web_fixture_management\r\nspring.datasource.username=u1\r\nspring.datasource.password=abc\r\n' > "$d/app/application.properties"
    . "$MAC_SCRIPTS/jig-db.sh"; JIG_MYSQL_BIN="$TEST_BIN" jig_db_load "$d" || return 1
    check "$JIG_DB_USER" "u1" "user" && check "$JIG_DB_PASS" "abc" "password without CR" && check "$JIG_DB_NAME" "web_fixture_management" "db"
}

url_case() {  # url_case <url> <host> <port> <db>
    local d="$WORK_ROOT/url"; mkdir -p "$d/app"
    printf 'spring.datasource.url=%s\n' "$1" > "$d/app/application.properties"
    jig_db_load "$d" || { echo "    load failed for $1"; return 1; }
    check "$JIG_DB_HOST|$JIG_DB_PORT|$JIG_DB_NAME" "$2|$3|$4" "$1"
}

test_jdbc_url_variants() {
    . "$MAC_SCRIPTS/jig-db.sh"
    url_case "jdbc:mysql://localhost:3306/web_fixture_management?useSSL=false&serverTimezone=Asia/Taipei" localhost 3306 web_fixture_management &&
    url_case "jdbc:mysql://db.local/other_db" db.local "" other_db &&
    url_case "jdbc:mariadb://127.0.0.1:3310/z;a=b" 127.0.0.1 3310 z
}

test_unparseable_url_fails() {
    local d="$WORK_ROOT/bad"; mkdir -p "$d/app"
    printf 'spring.datasource.url=jdbc:h2:file:./data/x\n' > "$d/app/application.properties"
    . "$MAC_SCRIPTS/jig-db.sh"
    if jig_db_load "$d" 2>/dev/null; then echo "    expected failure"; return 1; fi
}

test_mysql_bin_override_must_exist() {
    local d="$WORK_ROOT/nobin"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"
    if JIG_MYSQL_BIN="$WORK_ROOT/does-not-exist" jig_db_load "$d"; then echo "    expected failure"; return 1; fi
}

app_user_count() { root_sql -e "SELECT COUNT(*) FROM mysql.user WHERE User='jig_app'"; }

test_ensure_account_switches_root_install() {
    reset_db; install_v143_db
    local d="$WORK_ROOT/acct"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" || return 1
    local pw; pw="$(prop_of "$d/app/application.properties" spring.datasource.password)"
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "jig_app" "username switched" &&
    check "${#pw}" "24" "24-char password" &&
    check "$(printf '%s' "$pw" | tr -d 'A-Za-z0-9')" "" "password is alphanumeric" &&
    check "$JIG_DB_ACCOUNT_CREATED" "1" "created flag" &&
    check "$JIG_DB_USER" "root" "loaded connection still root" &&
    check "$(app_user_count)" "3" "jig_app@localhost, @127.0.0.1 and @::1" &&
    check "$(MYSQL_PWD="$pw" "$TEST_BIN/mysql" --no-defaults -h 127.0.0.1 -P "$TEST_PORT" -u jig_app -N -B -e 'SELECT COUNT(*) FROM users' web_fixture_management)" "4" "jig_app reads the data" &&
    check "$(stat -f %Lp "$d/app/application.properties")" "600" "settings file readable by owner only"
}

test_ensure_account_has_no_global_privileges() {
    reset_db; install_v143_db
    local d="$WORK_ROOT/priv"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" || return 1
    check "$(root_sql -e "SELECT COUNT(*) FROM mysql.user WHERE User='jig_app' AND (Super_priv='Y' OR Create_user_priv='Y' OR File_priv='Y')")" "0" "no global privileges"
}

test_ensure_account_keeps_custom_user() {
    reset_db; install_v143_db
    local d="$WORK_ROOT/custom"; make_install "$d" custom_user "secret"
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" || return 1
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "custom_user" "custom user kept" &&
    check "$(app_user_count)" "0" "no jig_app created"
}

test_ensure_account_when_user_already_exists() {
    reset_db; install_v143_db
    root_sql -e "CREATE USER 'jig_app'@'localhost' IDENTIFIED BY 'old'; CREATE USER 'jig_app'@'127.0.0.1' IDENTIFIED BY 'old'; CREATE USER 'jig_app'@'::1' IDENTIFIED BY 'old';"
    local d="$WORK_ROOT/rerun"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" || return 1
    local pw; pw="$(prop_of "$d/app/application.properties" spring.datasource.password)"
    check "$JIG_DB_ACCOUNT_CREATED" "0" "not marked as created" &&
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "jig_app" "username switched" &&
    check "$(MYSQL_PWD="$pw" "$TEST_BIN/mysql" --no-defaults -h 127.0.0.1 -P "$TEST_PORT" -u jig_app -N -B -e 'SELECT COUNT(*) FROM users' web_fixture_management)" "4" "password was reset and the data is readable"
}

test_new_password_not_on_command_line() {
    # A stub mysql records every call's arguments; the new jig_app password
    # must never be among them (others could see it with ps).
    local d="$WORK_ROOT/argv" bin="$WORK_ROOT/argvbin"; make_install "$d" root ""
    mkdir -p "$bin"
    printf '#!/bin/bash\nprintf "%%s\\n" "$@" >> "$(dirname "$0")/args"\necho 0\n' > "$bin/mysql"; chmod +x "$bin/mysql"
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    JIG_MYSQL_BIN="$bin" jig_db_ensure_app_account "$d" > /dev/null || return 1
    local pw; pw="$(prop_of "$d/app/application.properties" spring.datasource.password)"
    check "${#pw}" "24" "password saved" &&
    ! grep -q -- "$pw" "$bin/args" || { echo "    new password found in mysql arguments"; return 1; }
}

test_ensure_account_failure_leaves_settings() {
    reset_db   # no database: the account check (SELECT FROM users) must fail
    local d="$WORK_ROOT/fail"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    if jig_db_ensure_app_account "$d"; then echo "    expected failure"; return 1; fi
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "root" "settings unchanged" &&
    check "$(app_user_count)" "0" "new account removed again"
}

run_test test_sandbox_is_not_production
run_test test_db_load_parses_props
run_test test_db_load_defaults_for_old_props
run_test test_ping_with_root_no_password
run_test test_ping_custom_password_special_chars
run_test test_props_set_replaces_and_appends
run_test test_password_only_in_env_of_that_command
run_test test_localhost_uses_tcp_port
run_test test_client_option_files_ignored
run_test test_props_set_keeps_file_mode
run_test test_props_crlf
run_test test_jdbc_url_variants
run_test test_unparseable_url_fails
run_test test_mysql_bin_override_must_exist
run_test test_ensure_account_switches_root_install
run_test test_ensure_account_has_no_global_privileges
run_test test_ensure_account_keeps_custom_user
run_test test_ensure_account_when_user_already_exists
run_test test_ensure_account_failure_leaves_settings
run_test test_new_password_not_on_command_line
finish

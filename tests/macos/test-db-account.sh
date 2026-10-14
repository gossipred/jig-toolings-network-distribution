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
    reset_db || return 1; local d="$WORK_ROOT/ping"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; jig_db_load "$d" && jig_db_ping
}

test_ping_custom_password_special_chars() {
    reset_db || return 1
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
    reset_db || return 1; local d="$WORK_ROOT/lh"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"
    jig_props_set "$d/app/application.properties" spring.datasource.url "jdbc:mysql://localhost:$TEST_PORT/web_fixture_management"
    jig_db_load "$d" || return 1
    check "$(jig_mysql -N -B -e 'SELECT @@port')" "$TEST_PORT" "localhost reached the test server over TCP"
}

test_client_option_files_ignored() {
    reset_db || return 1; local d="$WORK_ROOT/cnf"; make_install "$d" root ""
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
    reset_db || return 1; install_v143_db || return 1
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
    reset_db || return 1; install_v143_db || return 1
    local d="$WORK_ROOT/priv"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" || return 1
    check "$(root_sql -e "SELECT COUNT(*) FROM mysql.user WHERE User='jig_app' AND (Super_priv='Y' OR Create_user_priv='Y' OR File_priv='Y')")" "0" "no global privileges"
}

test_ensure_account_keeps_custom_user() {
    reset_db || return 1; install_v143_db || return 1
    local d="$WORK_ROOT/custom"; make_install "$d" custom_user "secret"
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" || return 1
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "custom_user" "custom user kept" &&
    check "$(app_user_count)" "0" "no jig_app created"
}

test_ensure_account_when_user_already_exists() {
    reset_db || return 1; install_v143_db || return 1
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
    reset_db || return 1   # no database: the account check (SELECT FROM users) must fail
    local d="$WORK_ROOT/fail"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    if jig_db_ensure_app_account "$d"; then echo "    expected failure"; return 1; fi
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "root" "settings unchanged" &&
    check "$(app_user_count)" "0" "new account removed again"
}

test_install_database_creates_app_account() {
    reset_db || return 1
    local d="$WORK_ROOT/fresh"; make_install "$d" root ""
    bash "$d/scripts/install-database.command" < /dev/null > "$WORK_ROOT/install.out" 2>&1 || { cat "$WORK_ROOT/install.out"; return 1; }
    local migrations; migrations="$(ls "$d"/database/migration-*.sql | wc -l | tr -d ' ')"
    check "$(prop_of "$d/app/application.properties" spring.datasource.username)" "jig_app" "settings use jig_app" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.users')" "4" "seed users" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.schema_migrations')" "$migrations" "all migrations recorded"
}

# make_update <name>: a v1.4.3 install using root, plus a v2.0.0 package, plus
# the file backup UPDATE-JIG-NETWORK-APP.command makes before apply-update.
make_update() {
    PKG="$WORK_ROOT/$1/installed"; SRC="$WORK_ROOT/$1/new"; BK="$WORK_ROOT/$1/backup"
    make_install "$PKG" root "" 1.4.3
    make_install "$SRC" root "" 2.0.0
    mkdir -p "$BK"; cp -R "$PKG/app" "$BK/app"; cp -R "$PKG/scripts" "$BK/scripts"
}

test_update_switches_to_app_account() {
    reset_db || return 1; install_v143_db || return 1; make_update upd
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/upd.out" 2>&1
    local code=$?
    check "$code" "0" "exit code (log: $WORK_ROOT/upd.out)" &&
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.username)" "jig_app" "switched to jig_app" &&
    check "$(prop_of "$PKG/app/application.properties" app.version)" "2.0.0" "version updated" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.users')" "4" "data kept" &&
    [ -s "$BK/database-web_fixture_management.sql" ]
}

test_update_rollback_removes_new_account() {
    reset_db || return 1; install_v143_db || return 1; make_update rb
    echo "THIS IS NOT SQL;" > "$SRC/database/migration-2099-01-01-broken.sql"
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/rb.out" 2>&1
    local code=$?
    check "$code" "3" "exit code 3 = rolled back (log: $WORK_ROOT/rb.out)" &&
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.username)" "root" "settings back to root" &&
    check "$(prop_of "$PKG/app/application.properties" app.version)" "1.4.3" "version back" &&
    check "$(app_user_count)" "0" "jig_app removed" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.users')" "4" "data intact"
}

test_update_keeps_existing_app_account() {
    reset_db || return 1; install_v143_db || return 1; make_update keep
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$PKG" > /dev/null || return 1
    cp "$PKG/app/application.properties" "$BK/app/application.properties"
    local before; before="$(prop_of "$PKG/app/application.properties" spring.datasource.password)"
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/keep.out" 2>&1 || return 1
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.password)" "$before" "password unchanged on a second update"
}

test_second_update_success_migration() {
    reset_db || return 1; install_v143_db || return 1; make_update second_success
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$PKG" > /dev/null || return 1
    cp "$PKG/app/application.properties" "$BK/app/application.properties" || return 1
    local before; before="$(prop_of "$PKG/app/application.properties" spring.datasource.password)"
    echo "CREATE TABLE web_fixture_management.v21_probe (id INT);" > "$SRC/database/migration-2099-02-01-success.sql"
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/second_success.out" 2>&1
    local code=$?
    check "$code" "0" "second update exit code" &&
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.username)" "jig_app" "account kept" &&
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.password)" "$before" "password kept" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.users')" "4" "data intact" &&
    jig_db_load "$PKG" && jig_db_ping &&
    check "$(root_sql -e "SELECT COUNT(*) FROM web_fixture_management.schema_migrations WHERE filename='migration-2099-02-01-success.sql'")" "1" "migration record" &&
    check "$(root_sql -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='web_fixture_management' AND table_name='v21_probe'")" "1" "new table exists"
}

test_second_update_broken_migration() {
    reset_db || return 1; install_v143_db || return 1; make_update second_broken
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$PKG" > /dev/null || return 1
    cp "$PKG/app/application.properties" "$BK/app/application.properties" || return 1
    local before; before="$(prop_of "$PKG/app/application.properties" spring.datasource.password)"
    echo "THIS IS NOT SQL;" > "$SRC/database/migration-2099-02-01-broken.sql"
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/second_broken.out" 2>&1
    local code=$?
    check "$code" "3" "second update exit code" &&
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.username)" "jig_app" "account kept" &&
    check "$(prop_of "$PKG/app/application.properties" spring.datasource.password)" "$before" "password kept" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.users')" "4" "data intact" &&
    jig_db_load "$PKG" && jig_db_ping &&
    check "$(root_sql -e "SELECT COUNT(*) FROM web_fixture_management.schema_migrations WHERE filename='migration-2099-02-01-broken.sql'")" "0" "migration record"
}

test_no_script_uses_root_except_full_uninstall() {
    local hits
    hits="$(grep -ln -- '-u root' "$MAC_SCRIPTS"/* | grep -v 'uninstall-and-delete-data.command')"
    check "$hits" "" "only the full uninstall (which drops the database) may use root"
}

test_ping_when_root_has_password() {
    reset_db || return 1; install_v143_db || return 1
    local d="$WORK_ROOT/rootpw"; make_install "$d" root ""
    . "$MAC_SCRIPTS/jig-db.sh"; . "$MAC_SCRIPTS/jig-db-account.sh"
    jig_db_ensure_app_account "$d" > /dev/null || return 1
    root_sql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'RootPass123', 'root'@'127.0.0.1' IDENTIFIED BY 'RootPass123'" || return 1
    TEST_ROOT_PASS=RootPass123
    local rc=0
    # Prove root really needs the password now, then that jig_app does not.
    if MYSQL_PWD="" "$TEST_BIN/mysql" --no-defaults -h 127.0.0.1 -P "$TEST_PORT" -u root -e "SELECT 1" >/dev/null 2>&1; then
        echo "    root still connects without a password"; rc=1
    fi
    jig_db_load "$d" && jig_db_ping || rc=1
    root_sql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '', 'root'@'127.0.0.1' IDENTIFIED BY ''" || { echo "    could not reset the root password"; rc=1; }
    return $rc
}

test_restore_backup_uses_settings_account() {
    grep -q 'jig_db_load' "$MAC_SCRIPTS/restore-backup.command" &&
    grep -q 'jig_mysqldump' "$MAC_SCRIPTS/restore-backup.command" &&
    ! grep -q 'MYSQL_PWD=' "$MAC_SCRIPTS/restore-backup.command"
}

test_update_sets_taipei_for_old_install() {
    reset_db || return 1; install_v143_db || return 1; make_update tzold
    echo "app.timezone=" >> "$SRC/app/application.properties"   # the v2.0 template ships it blank
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/tzold.out" 2>&1 || { cat "$WORK_ROOT/tzold.out"; return 1; }
    check "$(prop_of "$PKG/app/application.properties" app.timezone)" "Asia/Taipei" "old install keeps Taipei time" &&
    check "$(grep -c '^app.timezone=' "$PKG/app/application.properties")" "1" "only one app.timezone line"
}

test_update_keeps_existing_timezone() {
    reset_db || return 1; install_v143_db || return 1; make_update tzkeep
    echo "app.timezone=Europe/Berlin" >> "$PKG/app/application.properties"
    cp "$PKG/app/application.properties" "$BK/app/application.properties"
    echo "app.timezone=" >> "$SRC/app/application.properties"
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/tzkeep.out" 2>&1 || { cat "$WORK_ROOT/tzkeep.out"; return 1; }
    check "$(prop_of "$PKG/app/application.properties" app.timezone)" "Europe/Berlin" "customer's own zone kept"
}

test_timezone_write_failure_rolls_back() {
    reset_db || return 1; install_v143_db || return 1; make_update tzfail
    echo "app.timezone=" >> "$SRC/app/application.properties"
    # Inject failure only into this throwaway installation's property writer.
    cat >> "$SRC/scripts/jig-db.sh" <<'STUB'
jig_props_set() { return 1; }
STUB
    bash "$SRC/scripts/apply-update.sh" "$SRC" "$PKG" "$BK" > "$WORK_ROOT/tzfail.out" 2>&1
    local code=$?
    grep -q "Could not set the time zone" "$WORK_ROOT/tzfail.out" &&
    check "$code" "3" "timezone write failure rolls back" &&
    check "$(prop_of "$PKG/app/application.properties" app.version)" "1.4.3" "old version restored" &&
    check "$(prop_of "$PKG/app/application.properties" app.timezone)" "" "old settings restored" &&
    check "$(root_sql -e 'SELECT COUNT(*) FROM web_fixture_management.users')" "4" "data intact"
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
run_test test_install_database_creates_app_account
run_test test_update_switches_to_app_account
run_test test_update_rollback_removes_new_account
run_test test_update_keeps_existing_app_account
run_test test_no_script_uses_root_except_full_uninstall
run_test test_ping_when_root_has_password
run_test test_restore_backup_uses_settings_account
run_test test_second_update_success_migration
run_test test_second_update_broken_migration
run_test test_update_sets_taipei_for_old_install
run_test test_update_keeps_existing_timezone
run_test test_timezone_write_failure_rolls_back
finish

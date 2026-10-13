#!/usr/bin/env bash
# macOS launcher-script tests for the database account (v2.0 plan 1).
# Needs the test MariaDB:  bash tests/test-mariadb.sh start
. "$(dirname "$0")/../lib.sh"

test_sandbox_is_not_production() {
    check "$(root_sql -e 'SELECT @@port')" "13306" "tests must run on the throwaway MariaDB"
}

run_test test_sandbox_is_not_production
finish

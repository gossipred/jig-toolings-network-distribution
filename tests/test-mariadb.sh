#!/usr/bin/env bash
# Throwaway MariaDB for the script tests: XAMPP's own binaries, a temporary
# data folder, 127.0.0.1:13306. It never touches the real XAMPP MySQL on port
# 3306 (on JJ's M4 that one is the live production server).
#   bash tests/test-mariadb.sh start | stop
set -u
BASE="/Applications/XAMPP/xamppfiles"
BIN="${JIG_TEST_MYSQL_BIN:-$BASE/bin}"
SBIN="${JIG_TEST_MYSQLD_DIR:-$BASE/sbin}"   # XAMPP keeps mysqld in sbin/, not bin/
DIR="${TMPDIR:-/tmp}"; DIR="${DIR%/}/jig-test-mariadb"
PORT=13306
SOCK="$DIR/mysql.sock"

ping_socket() { "$BIN/mysql" --no-defaults -S "$SOCK" -u root -e "SELECT 1" >/dev/null 2>&1; }

case "${1:-}" in
start)
    if ping_socket; then echo "test MariaDB already running on 127.0.0.1:$PORT"; exit 0; fi
    rm -rf "$DIR"; mkdir -p "$DIR/data"
    if ! "$BIN/mysql_install_db" --no-defaults --basedir="$BASE" --datadir="$DIR/data" \
            --auth-root-authentication-method=normal > "$DIR/install.log" 2>&1; then
        echo "mysql_install_db failed; see $DIR/install.log"; exit 1
    fi
    "$SBIN/mysqld" --no-defaults --basedir="$BASE" --datadir="$DIR/data" --port="$PORT" \
        --bind-address=127.0.0.1 --socket="$SOCK" --pid-file="$DIR/mysqld.pid" \
        --log-error="$DIR/error.log" > /dev/null 2>&1 &
    for _ in $(seq 1 30); do
        if ping_socket; then
            # XAMPP-like starting point: root over TCP with no password.
            "$BIN/mysql" --no-defaults -S "$SOCK" -u root -e \
                "CREATE USER IF NOT EXISTS 'root'@'127.0.0.1'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;"
            echo "test MariaDB ready on 127.0.0.1:$PORT"; exit 0
        fi
        sleep 1
    done
    echo "test MariaDB did not start; see $DIR/error.log"; exit 1 ;;
stop)
    [ -f "$DIR/mysqld.pid" ] && kill "$(cat "$DIR/mysqld.pid")" 2>/dev/null
    sleep 2; rm -rf "$DIR"; echo "test MariaDB stopped" ;;
*)
    echo "usage: $0 start|stop"; exit 2 ;;
esac

#!/usr/bin/env bash
# Checks jig-control.command in a temporary package: skip the menu with
# JIG_CONTROL_ACTION and stub all external commands, including admin calls.
set -u
DIST="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$DIST/macos/launcher/scripts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
checks=0; failed=0
check() { checks=$((checks + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $*"; }

# A fake package: real jig-control.command and jig-port.sh, stub start/stop scripts.
mkdir -p "$WORK/pkg/scripts" "$WORK/pkg/app" "$WORK/bin"
cp "$SRC/jig-control.command" "$SRC/jig-port.sh" "$WORK/pkg/scripts/"
printf 'server.port=18099\n' > "$WORK/pkg/app/application.properties"
printf '#!/usr/bin/env bash\necho START-SYSTEM-RAN\n' > "$WORK/pkg/scripts/start-system.command"
printf '#!/usr/bin/env bash\necho STOP-SYSTEM-RAN\n' > "$WORK/pkg/scripts/stop-system.command"
# Fake mysqladmin: "up" or "down" decided by a file.
printf '#!/usr/bin/env bash\n[ -f "%s/mysql-up" ]\n' "$WORK" > "$WORK/bin/mysqladmin"
cat > "$WORK/bin/mysql.server" <<'STUB'
#!/usr/bin/env bash
[ "${USER:-}" = root ] || exit 81
[ "$#" -eq 2 ] && [ "$1" = stop ] && [ "$2" = --user=root ] || exit 82
echo mysql-server >> "$JIG_CONTROL_TEST_WORK/events"
rm -f "$JIG_CONTROL_TEST_WORK/mysql-up"
STUB
chmod +x "$WORK/bin/mysqladmin" "$WORK/pkg/scripts/"*.command
# Isolate every process/network probe, even in the original dry-run cases.
export JIG_CONTROL_TEST_WORK="$WORK"
cat > "$WORK/bin/lsof" <<'STUB'
#!/usr/bin/env bash
[ -f "$JIG_CONTROL_TEST_WORK/listener" ] || exit 1
for arg do
    if [ "$arg" = "-iTCP:$(cat "$JIG_CONTROL_TEST_WORK/listener")" ]; then
        echo 43210
        exit 0
    fi
done
exit 1
STUB
printf '#!/usr/bin/env bash\necho java\n' > "$WORK/bin/ps"
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/bin/ipconfig"
cat > "$WORK/bin/osascript" <<'STUB'
#!/usr/bin/env bash
# Never execute the requested command or invoke the real macOS authorizer.
for arg do command_text="$arg"; done
[ "$command_text" = "USER=root /Applications/XAMPP/xamppfiles/bin/mysql.server stop --user=root" ] || exit 97
echo admin >> "$JIG_CONTROL_TEST_WORK/events"
case "$(cat "$JIG_CONTROL_TEST_WORK/admin-mode")" in
    stopped) USER=root "$JIG_CONTROL_TEST_WORK/bin/mysql.server" stop --user=root ;;
    alive) ;;
    cancelled) exit 1 ;;
    failed) exit 42 ;;
    *) exit 98 ;;
esac
STUB
chmod +x "$WORK/bin/mysql.server" "$WORK/bin/lsof" "$WORK/bin/ps" "$WORK/bin/ipconfig" "$WORK/bin/osascript"
export PATH="$WORK/bin:$PATH"
run() { JIG_MYSQLADMIN="$WORK/bin/mysqladmin" JIG_MYSQL_PLIST="$WORK/plist" JIG_MYSQL_WAIT=1 DRY_RUN=1 \
        JIG_CONTROL_ACTION="$1" bash "$WORK/pkg/scripts/jig-control.command" < /dev/null 2>&1; }

# Start, MySQL already up: no admin command, start-system runs.
touch "$WORK/mysql-up"
out="$(run start)"
check; case "$out" in *START-SYSTEM-RAN*) ;; *) fail "start: start-system not run: $out" ;; esac
check; case "$out" in *"[dry-run]"*) fail "start: admin command although MySQL is up" ;; esac

# Start, MySQL down, auto-start installed: kickstarts the LaunchDaemon.
rm -f "$WORK/mysql-up"; touch "$WORK/plist"
out="$(run start)"
check; case "$out" in *"[dry-run] launchctl kickstart -k system/studio.aurastudio.jig-mysql"*) ;; *) fail "start: no kickstart: $out" ;; esac

# Start, MySQL down, auto-start not installed: tells the user, does not start the system.
rm -f "$WORK/plist"
out="$(run start)"
check; case "$out" in *setup-mysql-autostart.command*) ;; *) fail "start: no hint to run setup-mysql-autostart: $out" ;; esac
check; case "$out" in *START-SYSTEM-RAN*) fail "start: system started without MySQL" ;; esac

# Stop, MySQL up: stops the system, then MySQL.
touch "$WORK/mysql-up"
out="$(run stop)"
check; case "$out" in *STOP-SYSTEM-RAN*) ;; *) fail "stop: stop-system not run: $out" ;; esac
check; case "$out" in *"[dry-run] USER=root /Applications/XAMPP/xamppfiles/bin/mysql.server stop --user=root"*) ;; *) fail "stop: MySQL not stopped: $out" ;; esac

# Status: names both parts and the port from application.properties.
out="$(run status)"
check; case "$out" in *MySQL*18099*|*18099*MySQL*) ;; *) fail "status: missing MySQL or port 18099: $out" ;; esac

check; bash -n "$SRC/jig-control.command" || fail "syntax"
# Real stop branch, with all external actions stubbed (DRY_RUN=0).
printf '#!/usr/bin/env bash\necho stop-system >> "%s/events"\necho STOP-SYSTEM-RAN\n' "$WORK" > "$WORK/pkg/scripts/stop-system.command"
reset_stop() {
    rm -f "$WORK/listener" "$WORK/mysql-up" "$WORK/events" "$WORK/pkg/logs/running-port.txt"
    printf 'server.port=18099\n' > "$WORK/pkg/app/application.properties"
    printf '%s\n' "$1" > "$WORK/admin-mode"
    touch "$WORK/mysql-up"
}
run_stop() {
    rc=0
    out="$(JIG_MYSQLADMIN="${1:-$WORK/bin/mysqladmin}" JIG_MYSQL_WAIT=1 DRY_RUN=0 \
        JIG_CONTROL_ACTION=stop bash "$WORK/pkg/scripts/jig-control.command" < /dev/null 2>&1)" || rc=$?
}
result() {
    check; [ "$rc" -eq "$1" ] || fail "$scenario: exit $rc, expected $1: $out"
    check; case "$out" in *"$2"*) ;; *) fail "$scenario: missing '$2': $out" ;; esac
    check
    if [ "$3" = yes ]; then
        echo "$out" | grep -qx '已停止。Stopped.' || fail "$scenario: no success message: $out"
    else
        if echo "$out" | grep -qx '已停止。Stopped.'; then fail "$scenario: false success: $out"; fi
    fi
}
no_admin() {
    check; [ "$(cat "$WORK/events")" = stop-system ] || fail "$scenario: admin was called"
}

scenario="XAMPP exits zero but MySQL stays alive (missing PID)"
reset_stop alive
run_stop
result 1 'MySQL is still running after 1 seconds.' no
check; [ "$(cat "$WORK/events")" = "$(printf 'stop-system\nadmin')" ] || fail "$scenario: wrong stop order when MySQL remains alive"

scenario="normal stop"
reset_stop stopped
run_stop
result 0 '已停止。Stopped.' yes
check; [ "$(cat "$WORK/events")" = "$(printf 'stop-system\nadmin\nmysql-server')" ] || fail "$scenario: wrong stop order or mysql.server arguments"

for mode in cancelled failed; do
    scenario="admin $mode"
    reset_stop "$mode"
    run_stop
    result 1 'the MySQL stop command failed or was cancelled.' no
done

scenario="MySQL already stopped"
reset_stop stopped
rm -f "$WORK/mysql-up"
run_stop
result 0 '已停止。Stopped.' yes
no_admin

for port in 18099 18443 18100; do
    scenario="Jig listener remains on $port"
    reset_stop stopped
    case "$port" in
        18443) printf 'app.https.enabled=true\napp.https.port=18443\n' >> "$WORK/pkg/app/application.properties" ;;
        18100) mkdir -p "$WORK/pkg/logs"; echo 18100 > "$WORK/pkg/logs/running-port.txt" ;;
    esac
    echo "$port" > "$WORK/listener"
    run_stop
    result 1 'the Jig system is still running.' no
    no_admin
done

for probe in missing non-executable; do
    scenario="mysqladmin $probe"
    reset_stop stopped
    printf 'not executable\n' > "$WORK/$probe"
    [ "$probe" = missing ] && rm -f "$WORK/$probe"
    run_stop "$WORK/$probe"
    result 1 'Cannot verify MySQL status: mysqladmin is unavailable.' no
    no_admin
done

scenario="dry run"
reset_stop alive
rc=0
out="$(run stop)" || rc=$?
result 0 'Dry run complete; the MySQL stop command was not executed.' no
no_admin
echo "$checks checks, $failed failed"
[ "$failed" -eq 0 ]

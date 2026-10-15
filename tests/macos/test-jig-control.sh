#!/usr/bin/env bash
# Checks jig-control.command without a real MySQL or system: menu skipped with
# JIG_CONTROL_ACTION, privileged commands only printed with DRY_RUN=1.
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
chmod +x "$WORK/bin/mysqladmin" "$WORK/pkg/scripts/"*.command
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
check; case "$out" in *"[dry-run] /Applications/XAMPP/xamppfiles/xampp stopmysql"*) ;; *) fail "stop: MySQL not stopped: $out" ;; esac

# Status: names both parts and the port from application.properties.
out="$(run status)"
check; case "$out" in *MySQL*18099*|*18099*MySQL*) ;; *) fail "status: missing MySQL or port 18099: $out" ;; esac

check; bash -n "$SRC/jig-control.command" || fail "syntax"
echo "$checks checks, $failed failed"
[ "$failed" -eq 0 ]

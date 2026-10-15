#!/usr/bin/env bash
# Checks the LaunchDaemon that setup-mysql-autostart.command installs, without
# running the script: launchd must not kill MySQL when the boot helper exits.
set -u
DIST="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$DIST/macos/launcher/scripts/setup-mysql-autostart.command"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
checks=0; failed=0
check() { checks=$((checks + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $*"; }

LABEL=studio.aurastudio.jig-mysql HELPER=/tmp/helper.sh LOG=/tmp/log
sed -n '/^cat > "\$TMP\/\$LABEL.plist" <<EOF$/,/^EOF$/p' "$SCRIPT" | sed '1d;$d' |
    sed -e "s#\$LABEL#$LABEL#g" -e "s#\$HELPER#$HELPER#g" -e "s#\$LOG#$LOG#g" > "$WORK/job.plist"

check; plutil -lint "$WORK/job.plist" >/dev/null 2>&1 || fail "LaunchDaemon plist is not valid"
# The helper only starts mysqld_safe and exits; without this launchd kills MySQL with it.
check; [ "$(plutil -extract AbandonProcessGroup raw "$WORK/job.plist" 2>/dev/null)" = true ] ||
    fail "AbandonProcessGroup is not true: launchd stops MySQL when the helper exits"
check; [ "$(plutil -extract RunAtLoad raw "$WORK/job.plist" 2>/dev/null)" = true ] || fail "RunAtLoad is not true"

echo "$checks checks, $failed failed"
[ "$failed" -eq 0 ]

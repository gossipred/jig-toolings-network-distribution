#!/usr/bin/env bash
# set-app-icon.sh gives START-JIG-NETWORK-APP.command the network app icon. bash 3.2.
set -u
DIST="$(cd "$(dirname "$0")/../.." && pwd)"
CORE="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
ICNS="$CORE/customer-package/mac-network-app/app/jig-network.icns"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
RUN=0
FAILED=0
fail() { echo "FAIL: $*"; FAILED=$((FAILED + 1)); }
check() { RUN=$((RUN + 1)); }

make_pkg() { # make_pkg <dir> [with-icon]
    mkdir -p "$1/app" "$1/scripts"
    cp "$DIST/macos/launcher/START-JIG-NETWORK-APP.command" "$1/"
    cp "$DIST/macos/launcher/scripts/set-app-icon.sh" "$1/scripts/"
    [ "${2:-}" = "with-icon" ] && cp "$ICNS" "$1/app/"
    return 0
}
has_icon() { xattr -p com.apple.ResourceFork "$1/START-JIG-NETWORK-APP.command" >/dev/null 2>&1; }

# 1. The icon file exists and is an icns.
check; [ "$(file -b "$ICNS" 2>/dev/null | cut -c1-14)" = "Mac OS X icon," ] || fail "jig-network.icns missing or not an icns: $ICNS"

# 2. Sets the icon.
check
make_pkg "$WORK/a" with-icon
bash "$WORK/a/scripts/set-app-icon.sh"; rc=$?
[ "$rc" -eq 0 ] || fail "exit $rc"
has_icon "$WORK/a" || fail "icon not set"

# 3. Already set: still exit 0, icon kept.
check
bash "$WORK/a/scripts/set-app-icon.sh" || fail "second run failed"
has_icon "$WORK/a" || fail "icon lost on second run"

# 4. No icns (older package): exit 0, nothing changed.
check
make_pkg "$WORK/b"
bash "$WORK/b/scripts/set-app-icon.sh" || fail "missing icns made it fail"
has_icon "$WORK/b" && fail "icon set without an icns"

# 5. start-system.command calls it.
check; grep -qF 'bash "$SCRIPT_DIR/set-app-icon.sh"' "$DIST/macos/launcher/scripts/start-system.command" || fail "start-system.command does not call set-app-icon.sh"

echo "$RUN checks, $FAILED failed"
[ "$FAILED" -eq 0 ]

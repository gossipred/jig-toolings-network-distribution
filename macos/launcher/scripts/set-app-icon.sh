#!/usr/bin/env bash
# Shows the network app icon on START-JIG-NETWORK-APP.command in Finder.
# Cosmetic, best effort, never fails. start-system.command calls it, so new
# installs and online updates (which replace the .command file) both get it.
PKG="$(cd "$(dirname "$0")/.." && pwd)"
ICON="$PKG/app/jig-network.icns"
TARGET="$PKG/START-JIG-NETWORK-APP.command"
[ -f "$ICON" ] && [ -f "$TARGET" ] || exit 0
# A custom icon lives in the file's resource fork; already there means done.
xattr -p com.apple.ResourceFork "$TARGET" >/dev/null 2>&1 && exit 0
osascript -l JavaScript \
    -e 'ObjC.import("AppKit")' \
    -e 'function run(argv) { $.NSWorkspace.sharedWorkspace.setIconForFileOptions($.NSImage.alloc.initWithContentsOfFile(argv[0]), argv[1], 0) }' \
    "$ICON" "$TARGET" >/dev/null 2>&1 || true
exit 0

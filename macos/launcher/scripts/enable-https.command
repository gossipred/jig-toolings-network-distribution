#!/usr/bin/env bash
# Turns HTTPS on when nobody can log in to the Admin page (v2.0 WP4).
# Same as System Settings > HTTPS. Restart the system afterwards.
# macOS ships bash 3.2 — no bash 4 syntax.
cd "$(dirname "$0")/../app" || exit 1
JAVA_EXE="../runtime/bin/java"
[ -x "$JAVA_EXE" ] || JAVA_EXE="java"
"$JAVA_EXE" -jar jig-management-system.jar enable-https application.properties
RC=$?
echo
read -r -p "Press Enter to close..." || true
exit $RC

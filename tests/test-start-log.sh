#!/usr/bin/env bash
# v2.0.1: start-system.bat must keep earlier runs in logs\jig-system.log (the first-login 403
# evidence was lost because each start overwrote it). Text checks only, no Windows needed. bash 3.2.
#   bash tests/test-start-log.sh
set -u
DIST="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
BAT="$DIST/windows/launcher/scripts/start-system.bat"
COPY="$CORE/customer-package/windows-network-app/scripts/start-system.bat"
RUN=0
FAILED=0

fail() { echo "FAIL: $*"; FAILED=$((FAILED + 1)); }
check() { RUN=$((RUN + 1)); }

# 1. Java output is appended, never truncated.
check
grep -qF -- '-jar jig-management-system.jar --spring.config.location=file:application.properties >> "%LOG_DIR%\jig-system.log" 2>&1' "$BAT" ||
    fail "java output is not appended to jig-system.log"
check
! grep -qE '[^>]> "%LOG_DIR%\\jig-system\.log"' "$BAT" || fail "jig-system.log is still overwritten with a single >"

# 2. Each start writes a dated separator first, so runs can be told apart.
check
grep -qF '>>"%LOG_DIR%\jig-system.log" echo ===== Jig start %date% %time% =====' "$BAT" ||
    fail "no start separator line"

# 3. cmd.exe needs ASCII with CRLF line endings.
check
perl -ne 'exit 1 if /[^\x09\x0a\x0d\x20-\x7e]/' "$BAT" || fail "non-ASCII in $BAT"
check
perl -ne 'exit 1 if /(?<!\r)\n/' "$BAT" || fail "bare LF in $BAT"

# 4. The CORE customer-package copy stays identical.
check
cmp -s "$BAT" "$COPY" || fail "CORE copy differs: $COPY"

echo "$RUN checks, $FAILED failed"
[ "$FAILED" -eq 0 ]

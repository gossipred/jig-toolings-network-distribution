#!/usr/bin/env bash
# v2.0.1: start-system.bat and start-system.command must keep earlier runs in logs\jig-system.log (the first-login 403
# evidence was lost because each start overwrote it). Text checks only, no Windows needed. bash 3.2.
#   bash tests/test-start-log.sh
set -u
DIST="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
BAT="$DIST/windows/launcher/scripts/start-system.bat"
COPY="$CORE/customer-package/windows-network-app/scripts/start-system.bat"
MAC="$DIST/macos/launcher/scripts/start-system.command"
MAC_COPY="$CORE/customer-package/mac-network-app/scripts/start-system.command"
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
grep -qF '>>"%LOG_DIR%\jig-system.log" echo ===== Jig start %JIG_NOW% =====' "$BAT" ||
    fail "no start separator line"
# %date% follows the Windows locale (zh-TW adds a weekday in Big5), so the log line is not ASCII.
check
grep -qF "for /f \"delims=\" %%t in ('powershell -NoProfile -Command \"Get-Date -Format 'yyyy-MM-dd HH:mm:ss'\"') do set \"JIG_NOW=%%t\"" "$BAT" ||
    fail "separator time is not taken from a fixed yyyy-MM-dd HH:mm:ss format"
check
! grep -qF '%date%' "$BAT" || fail "start-system.bat still uses the locale-dependent %date%"

# 3. cmd.exe needs ASCII with CRLF line endings.
check
perl -ne 'exit 1 if /[^\x09\x0a\x0d\x20-\x7e]/' "$BAT" || fail "non-ASCII in $BAT"
check
perl -ne 'exit 1 if /(?<!\r)\n/' "$BAT" || fail "bare LF in $BAT"

# 4. The CORE customer-package copy stays identical.
check
cmp -s "$BAT" "$COPY" || fail "CORE copy differs: $COPY"

# 5. macOS: same append + separator; bash, LF only, executable, CORE copy identical.
check
grep -qF -- '> "$LOG_DIR/jig-system.log" 2>&1 &' "$MAC" && ! grep -qF -- '>> "$LOG_DIR/jig-system.log" 2>&1 &' "$MAC" &&
    fail "macOS java output is still overwritten with a single >"
check
grep -qF -- '>> "$LOG_DIR/jig-system.log" 2>&1 &' "$MAC" || fail "macOS java output is not appended to jig-system.log"
check
grep -qF 'echo "===== Jig start $(date '"'"'+%Y-%m-%d %H:%M:%S'"'"') =====" >> "$LOG_DIR/jig-system.log"' "$MAC" ||
    fail "macOS: no start separator line"
check
bash -n "$MAC" || fail "macOS script has a syntax error"
check
! grep -q $'\r' "$MAC" || fail "CR in $MAC"
check
[ -x "$MAC" ] && [ -x "$MAC_COPY" ] || fail "macOS start script lost its executable bit"
check
cmp -s "$MAC" "$MAC_COPY" || fail "CORE copy differs: $MAC_COPY"

echo "$RUN checks, $FAILED failed"
[ "$FAILED" -eq 0 ]

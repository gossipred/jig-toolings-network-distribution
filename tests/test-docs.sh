#!/usr/bin/env bash
# Documentation and packaging text checks (no database needed). bash 3.2.
#   bash tests/test-docs.sh
set -u
DIST="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${JIG_CORE_REPO:-$HOME/Documents/Codex/jig-and-toolings-management-system}"
GUIDES="$DIST/docs/install-guides"
EMAIL="aurastudio.studio.service@gmail.com"
OLD_EMAIL_USER="gossipred""5598"   # split so this file does not match its own search
FIRST_LOGIN="First login: admin / 123456 - you will be asked to set a new password."
RUN=0
FAILED=0

fail() { echo "FAIL: $*"; FAILED=$((FAILED + 1)); }
check() { RUN=$((RUN + 1)); }

# 1. The old support address is gone (the spec and plans keep it as history).
check
old="$( (cd "$DIST" && git grep -l "$OLD_EMAIL_USER"); (cd "$CORE" && git grep -l "$OLD_EMAIL_USER" -- . ':!docs/superpowers') )"
[ -z "$old" ] || fail "old support address still in: $old"

# 2. Batch files are ASCII only (cmd.exe breaks on anything else).
check
bad="$(find "$DIST/windows" "$CORE/customer-package/windows-network-app" -name '*.bat' -print0 |
    xargs -0 perl -ne 'if (/[^\x09\x0a\x0d\x20-\x7e]/) { print "$ARGV:$.\n"; } close ARGV if eof')"
[ -z "$bad" ] || fail "non-ASCII in batch files: $bad"

# 3. Copies of the guides match the originals in docs/install-guides.
for f in "$GUIDES"/*-Windows*.txt; do
    check; cmp -s "$f" "$CORE/customer-package/windows-network-app/$(basename "$f")" || fail "copy differs: $(basename "$f") (windows-network-app)"
done
for f in "$GUIDES"/*-macOS*.txt; do
    check; cmp -s "$f" "$CORE/customer-package/mac-network-app/$(basename "$f")" || fail "copy differs: $(basename "$f") (mac-network-app)"
done
# The in-app copies may differ only in BOM and line endings.
plain() { perl -pe 's/^\xef\xbb\xbf// if $. == 1; s/\r$//' "$1"; }
for os in Windows macOS; do
    check
    [ "$(plain "$GUIDES/RESTORE-GUIDE-$os.txt")" = "$(plain "$CORE/src/main/resources/guides/RESTORE-GUIDE-$os.txt")" ] ||
        fail "in-app RESTORE-GUIDE-$os.txt differs from docs/install-guides"
done

# 4. Start scripts tell new users they will set a new password.
for f in "$DIST/windows/launcher/scripts/start-system.bat" "$DIST/macos/launcher/scripts/start-system.command"; do
    check; grep -qF "$FIRST_LOGIN" "$f" || fail "first-login line missing: $f"
done

# 5. Every guide names the support address.
for f in "$GUIDES"/*.txt; do
    check; grep -qF "$EMAIL" "$f" || fail "support address missing: $(basename "$f")"
done

echo "$RUN checks, $FAILED failed"
[ "$FAILED" -eq 0 ]

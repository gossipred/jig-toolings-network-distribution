#!/usr/bin/env bash
# Documentation and packaging text checks (no database needed). bash 3.2.
#   bash tests/test-docs.sh
set -u
DIST="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
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

# 6. Guides describe the v2.0 sign-in and database account (facts in the plan's Global Constraints).
need() { # need <file> <text>...
    local f="$1"; shift
    local t
    for t in "$@"; do
        check; grep -qF -- "$t" "$GUIDES/$f" || fail "$f: missing \"$t\""
    done
}
for os in Windows macOS; do
    need "INSTALL-GUIDE-$os-en.txt" "supervisor" "asks for a new password" "at least 8 characters" \
        "locked for 15 minutes" "Unlock" "jig_app" "Time Zone" "HTTPS" "English"
    need "INSTALL-GUIDE-$os-zh-TW.txt" "supervisor" "要求設定新密碼" "至少 8 碼" "鎖 15 分鐘" "解鎖" \
        "jig_app" "時區" "HTTPS" "简体中文"
    need "UPDATE-GUIDE-$os.txt" "v2.0" "jig_app" "invalid signature" "were restored" "Taipei" "台北"
done

# 7. Release scripts copy the guides into the package, so the zip always has the originals.
check; grep -qF 'cp "$DIST_REPO/docs/install-guides/"*-Windows*.txt "$PACKAGE_DIR/"' "$DIST/windows/installer/release-windows.sh" ||
    fail "release-windows.sh does not copy the guides"
check; grep -qF 'cp "$DIST_REPO/docs/install-guides/"*-macOS*.txt "$PACKAGE_DIR/"' "$DIST/macos/installer/release-macos.sh" ||
    fail "release-macos.sh does not copy the guides"

# 7. v2.0.0 version everywhere the release reads it.
for f in "$CORE/src/main/resources/application.properties" \
         "$CORE/customer-package/mac-network-app/app/application.properties" \
         "$CORE/customer-package/windows-network-app/app/application.properties" \
         "$CORE/customer-package/mysql-windows/app/application.properties"; do
    check; grep -qx 'app.version=2.0.0' <(tr -d '\r' < "$f") || fail "app.version is not 2.0.0: $f"
done

# 8. Every batch file in CORE customer-package is ASCII (old packages too).
check
bad="$(find "$CORE/customer-package" -name '*.bat' -not -path '*/runtime/*' -print0 |
    xargs -0 perl -ne 'if (/[^\x09\x0a\x0d\x20-\x7e]/) { print "$ARGV:$.\n"; } close ARGV if eof')"
[ -z "$bad" ] || fail "non-ASCII in CORE batch files: $bad"

# 9. Customer README files carry no internal notes.
check
notes="$(grep -l 'Notes For JJ' "$CORE"/customer-package/*/README-FIRST.md || true)"
[ -z "$notes" ] || fail "internal notes in: $notes"

# 10. Installer notes name the real shortcut.
check
grep -q 'desktop shortcut starting with "Jig Toolings"' "$DIST/windows/installer/installer-notes-en.txt" ||
    fail "installer-notes-en.txt shortcut wording"

# 11. zh-TW guides use the on-screen HTTPS section title.
for f in "$GUIDES"/INSTALL-GUIDE-*-zh-TW.txt; do
    check; grep -q '系統設定 → HTTPS 加密連線 → 開啟 HTTPS' "$f" || fail "HTTPS path wording: $(basename "$f")"
done

# 12. Manuals: CORE copies match DIST, and both carry the v2.0 sections.
for f in "$DIST"/docs/manuals/*.docx; do
    check; cmp -s "$f" "$CORE/docs/manuals/$(basename "$f")" || fail "manual copy differs: $(basename "$f")"
    for phrase in '第一次登入時，系統一定會先帶你到「修改密碼」頁' 'On the first sign-in the system always opens the Change Password page first' \
                  '連續輸入錯誤密碼 5 次，帳號會鎖定 15 分鐘' 'The Language menu is on the sign-in page'; do
        check; python3 - "$f" "$phrase" <<'EOF' || fail "$(basename "$f") lacks: $phrase"
import sys, docx
text = "\n".join(p.text for p in docx.Document(sys.argv[1]).paragraphs)
sys.exit(0 if sys.argv[2] in text else 1)
EOF
    done
done
admin="$DIST/docs/manuals/治具及模具管理系統＿管理人員說明書（中英）.docx"
for phrase in 'Admin 按該帳號的「解鎖」即可立即解除' 'System Settings → Time Zone' 'https://（伺服器 IP）:8443' 'From v2.0 the update list is digitally signed'; do
    check; python3 - "$admin" "$phrase" <<'EOF' || fail "admin manual lacks: $phrase"
import sys, docx
text = "\n".join(p.text for p in docx.Document(sys.argv[1]).paragraphs)
sys.exit(0 if sys.argv[2] in text else 1)
EOF
done
for f in "$CORE"/customer-package/{mac,windows}-network-app/documents/admin-operation-guide.md \
         "$CORE"/customer-package/{mac,windows}-network-app/documents/user-quick-guide.md \
         "$CORE"/customer-package/{mac,windows}-network-app/USER-GUIDE-zh-TW.txt; do
    check; grep -q '連續輸入錯誤密碼 5 次，帳號會鎖定 15 分鐘' "$f" || fail "v2.0 account text missing: $f"
done

echo "$RUN checks, $FAILED failed"
[ "$FAILED" -eq 0 ]

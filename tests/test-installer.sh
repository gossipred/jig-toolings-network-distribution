#!/usr/bin/env bash
# Builds the setup wizard from a tiny fake package and checks its languages,
# names and shortcuts. Needs makensis (brew install makensis). bash 3.2.
set -u
DIST="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${JIG_CORE_REPO:-$HOME/Documents/Codex/jig-and-toolings-management-system}"
NSI="$DIST/windows/installer/jig-setup.nsi"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
RUN=0
FAILED=0
fail() { echo "FAIL: $*"; FAILED=$((FAILED + 1)); }
check() { RUN=$((RUN + 1)); }

# 1. It compiles with warnings treated as errors (a LangString missing in
#    one language is a warning).
check
mkdir -p "$WORK/pkg/app"
cp "$CORE/customer-package/windows-network-app/app/jig-network.ico" "$WORK/pkg/app/"
echo "placeholder" > "$WORK/pkg/START-JIG-NETWORK-APP.bat"
if ! makensis -WX -V2 -DVERSION=9.9.9 -DPACKAGE_DIR="$WORK/pkg" -DOUTFILE="$WORK/JigToolingsTest.exe" "$NSI" > "$WORK/build.log" 2>&1; then
    fail "makensis failed:"; cat "$WORK/build.log"
fi

# 2. English is the first language (Windows in other languages gets English).
check
first="$(grep -m1 -E '^!insertmacro MUI_LANGUAGE ' "$NSI")"
[ "$first" = '!insertmacro MUI_LANGUAGE "English"' ] || fail "first language is not English: $first"
check; grep -q '^!insertmacro MUI_LANGUAGE "TradChinese"' "$NSI" || fail "TradChinese missing"

# 3. Chinese appears only in comments, Traditional Chinese strings and the shortcut names.
check
bad="$(perl -CSD -ne '
    next unless /\p{Han}/;
    next if /^\s*;/ || /\$\{LANG_TRADCHINESE\}/ || /^!define (OLD_)?SHORTCUT_NAME\s/;
    (my $code = $_) =~ s/\s;\s.*$//;
    print "$.: $_" if $code =~ /\p{Han}/;' "$NSI")"
[ -z "$bad" ] || fail "Chinese outside LangString:
$bad"

# 4. Names and publisher from the spec.
check; grep -qF '!define SHORTCUT_NAME     "Jig Toolings 治具管理系統"' "$NSI" || fail "SHORTCUT_NAME"
check; grep -qF '!define PRODUCT_PUBLISHER "Aura Studio"' "$NSI" || fail "PRODUCT_PUBLISHER"
check; grep -qF 'WriteRegStr   HKLM "${REG_KEY}" "DisplayName"     "${PRODUCT_NAME}"' "$NSI" || fail "DisplayName"
check; grep -qF '!define PRODUCT_NAME      "Jig & Toolings Management System"' "$NSI" || fail "PRODUCT_NAME"

# 5. Upgrades and uninstall remove the v1.x shortcuts; shortcuts use the network icon.
check; [ "$(grep -c 'OLD_SHORTCUT_NAME}' "$NSI")" -ge 4 ] || fail "old shortcuts are not removed on upgrade and uninstall"
check
icons="$(grep -E '^[[:space:]]*CreateShortcut .*START-JIG-NETWORK-APP\.bat' "$NSI")"
[ "$(printf '%s\n' "$icons" | grep -c 'jig-network.ico')" -eq 2 ] || fail "start shortcuts must use jig-network.ico: $icons"

# 6. The English installer notes are ASCII and name the support address.
check
perl -ne 'exit 1 if /[^\x09\x0a\x0d\x20-\x7e]/' "$DIST/windows/installer/installer-notes-en.txt" || fail "installer-notes-en.txt is not ASCII"
for f in installer-notes.txt installer-notes-en.txt; do
    check; grep -qF "aurastudio.studio.service@gmail.com" "$DIST/windows/installer/$f" || fail "$f: support address"
done

echo "$RUN checks, $FAILED failed"
[ "$FAILED" -eq 0 ]

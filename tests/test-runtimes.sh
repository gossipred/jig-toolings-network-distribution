#!/usr/bin/env bash
# Checks the bundled Java runtimes: Eclipse Temurin 21, no Oracle license,
# every module the app needs, no numbered iCloud conflict copies.
set -u
CORE="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
MODULES="java.base java.datatransfer java.xml java.prefs java.desktop java.instrument java.logging java.management java.security.sasl java.naming java.net.http java.rmi java.security.jgss java.transaction.xa java.sql java.sql.rowset jdk.charsets jdk.crypto.ec jdk.crypto.cryptoki jdk.localedata jdk.naming.dns jdk.unsupported jdk.zipfs"
checks=0; failed=0
check() { checks=$((checks + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $*"; }

for platform in mac-network-app windows-network-app; do
    rt="$CORE/customer-package/$platform/runtime"
    check; grep -q '^IMPLEMENTOR="Eclipse Adoptium"' "$rt/release" 2>/dev/null || fail "$platform: not Temurin"
    check; grep -q '^JAVA_VERSION="21\.' "$rt/release" 2>/dev/null || fail "$platform: not Java 21"
    check; ! grep -qi 'oracle no-fee\|NFTC' "$rt/legal/java.base/LICENSE" 2>/dev/null || fail "$platform: Oracle license"
    check; [ -f "$rt/legal/java.base/LICENSE" ] || fail "$platform: legal/java.base/LICENSE missing"
    want="$MODULES"
    [ "$platform" = windows-network-app ] && want="$want jdk.crypto.mscapi"
    have=" $(sed -n 's/^MODULES="\(.*\)"/\1/p' "$rt/release" 2>/dev/null) "
    for m in $want; do
        check; case "$have" in *" $m "*) ;; *) fail "$platform: module $m missing" ;; esac
    done
    check; dup="$(find "$rt" -name '* [0-9]*' 2>/dev/null | head -3)"; [ -z "$dup" ] || fail "$platform: duplicate files: $dup"
done

check; file "$CORE/customer-package/mac-network-app/runtime/bin/java" | grep -q 'arm64' || fail "mac java is not arm64"
check; "$CORE/customer-package/mac-network-app/runtime/bin/java" -version 2>&1 | grep -q 'Temurin-21' || fail "mac java does not run"
for exe in java.exe javaw.exe; do
    check; file "$CORE/customer-package/windows-network-app/runtime/bin/$exe" 2>/dev/null | grep -q 'x86-64' || fail "windows $exe is not x64"
done

echo "$checks checks, $failed failed"
[ "$failed" -eq 0 ]

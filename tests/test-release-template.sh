#!/usr/bin/env bash
# Load only the validation function, never execute a release script.
set -eu
DIST="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
count=0
for script in macos/installer/release-macos.sh windows/installer/release-windows.sh; do
    fn="$(sed -n '/^check_release_template() {/,/^}/p' "$DIST/$script")"
    for kind in clean crlf password custom missing duplicate; do
        mkdir -p "$WORK/$kind/app"
        props="$WORK/$kind/app/application.properties"
        printf 'spring.datasource.username=root\nspring.datasource.password=\n' > "$props"
        expected=1
        case "$kind" in
            clean) expected=0 ;;
            crlf) printf 'spring.datasource.username=root\r\nspring.datasource.password=\r\n' > "$props"; expected=0 ;;
            password) printf 'spring.datasource.password=do-not-ship\n' >> "$props" ;;
            custom) printf 'spring.datasource.username=jig_app\nspring.datasource.password=\n' > "$props" ;;
            missing) printf 'spring.datasource.username=root\n' > "$props" ;;
            duplicate) printf 'spring.datasource.username=root\n' >> "$props" ;;
        esac
        rc=0
        bash -c "$fn
check_release_template \"\$1\"" check "$props" > "$WORK/output" 2>&1 || rc=$?
        if [ "$rc" -ne "$expected" ]; then echo "FAIL $script $kind: expected $expected, got $rc"; exit 1; fi
        if grep -q 'do-not-ship' "$WORK/output"; then echo 'FAIL password leaked'; exit 1; fi
        count=$((count + 1))
    done
done
# Packaging contracts: inspect text only; never execute the packaging scripts.
CORE="${JIG_CORE_REPO:-$HOME/Developer/jig-and-toolings-management-system}"
failed=0
count=$((count + 1))
if grep -qF 'RUNTIME_SRC=' "$DIST/windows/installer/release-windows.sh"; then
    echo 'FAIL: release-windows.sh must preserve the network-app runtime'
    failed=$((failed + 1))
fi
for platform in mac windows; do
    count=$((count + 1))
    if grep -qF 'MYSQL_PACKAGE_DIR/documents' "$CORE/customer-package/$platform-network-app/scripts/build-$platform-network-app-package.sh"; then
        echo "FAIL: $platform assembly must preserve network-app documents"
        failed=$((failed + 1))
    fi
done
for script in macos/installer/release-macos.sh windows/installer/release-windows.sh; do
    count=$((count + 1))
    if ! grep -qF 'JIG_UPLOAD:-0' "$DIST/$script"; then
        echo "FAIL: $script must default to a local build"
        failed=$((failed + 1))
    fi
    count=$((count + 1))
    if ! grep -qF 'Duplicate files (iCloud sync conflict copies)' "$DIST/$script"; then
        echo "FAIL: $script must reject iCloud duplicate files"
        failed=$((failed + 1))
    fi
done
echo "$count template checks, $failed failed"
[ "$failed" -eq 0 ]

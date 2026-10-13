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
echo "$count template checks, 0 failed"

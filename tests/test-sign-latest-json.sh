#!/usr/bin/env bash
# v2.0 plan 4: tools/sign-latest-json.sh with throwaway keys and a fake core repo.
set -u
DIST="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
RUN=0; FAILED=0
CORE="$WORK/core"; PUB="$CORE/src/main/resources/update-signing"; mkdir -p "$PUB" "$WORK/keys"
for k in update-signing update-signing-backup stranger; do
    openssl genrsa -out "$WORK/keys/$k-private.pem" 2048 2>/dev/null
done
openssl rsa -in "$WORK/keys/update-signing-private.pem" -pubout -out "$PUB/update-signing-public.pem" 2>/dev/null
openssl rsa -in "$WORK/keys/update-signing-backup-private.pem" -pubout -out "$PUB/update-signing-backup-public.pem" 2>/dev/null

run_test() {
    RUN=$((RUN + 1))
    if ( "$1" ); then echo "PASS $1"; else echo "FAIL $1"; FAILED=$((FAILED + 1)); fi
}
new_json() { mkdir -p "$1"; printf '{\n  "latestVersion": "2.0.0"\n}\n' > "$1/latest.json"; }
sign_with() { JIG_UPDATE_SIGNING_KEY="$WORK/keys/$1-private.pem" bash "$DIST/tools/sign-latest-json.sh" "$2/latest.json" "$CORE"; }
# The customer side: /usr/bin/openssl, key from the package, signature from the .sig file.
customer_accepts() {
    tr -d ' \r\n' < "$1/latest.json.sig" | /usr/bin/openssl base64 -d -A > "$1/sig.bin"
    /usr/bin/openssl dgst -sha256 -verify "$PUB/$2" -signature "$1/sig.bin" "$1/latest.json" > /dev/null 2>&1
}

test_main_key_signs() {
    local d="$WORK/main"; new_json "$d"
    sign_with update-signing "$d" > /dev/null || { echo "    signing failed"; return 1; }
    customer_accepts "$d" update-signing-public.pem || { echo "    customer check failed"; return 1; }
    [ "$(tail -c 1 "$d/latest.json.sig" | od -An -c | tr -d ' ')" != '\n' ] || { echo "    .sig ends with a newline"; return 1; }
}
test_backup_key_signs() {
    local d="$WORK/backup"; new_json "$d"
    sign_with update-signing-backup "$d" > /dev/null || { echo "    signing failed"; return 1; }
    customer_accepts "$d" update-signing-backup-public.pem || { echo "    customer check failed"; return 1; }
}
test_unknown_key_is_refused() {
    local d="$WORK/stranger" rc=0; new_json "$d"
    sign_with stranger "$d" > /dev/null 2>&1 || rc=$?
    [ "$rc" -eq 1 ] || { echo "    exit code $rc"; return 1; }
    [ ! -e "$d/latest.json.sig" ] || { echo "    a .sig was left behind"; return 1; }
}
test_missing_key_is_refused() {
    local d="$WORK/nokey" rc=0; new_json "$d"
    JIG_UPDATE_SIGNING_KEY="$WORK/keys/none.pem" bash "$DIST/tools/sign-latest-json.sh" "$d/latest.json" "$CORE" > /dev/null 2>&1 || rc=$?
    [ "$rc" -eq 1 ] || { echo "    exit code $rc"; return 1; }
    [ ! -e "$d/latest.json.sig" ] || { echo "    a .sig was written"; return 1; }
}
# Both release scripts sign right after writing the manifests, before anything is uploaded.
test_release_scripts_sign() {
    local s
    for s in macos/installer/release-macos.sh windows/installer/release-windows.sh; do
        awk '/^PYEOF$/ { done = NR } /tools\/sign-latest-json\.sh/ && done && NR > done { ok = 1 } END { exit !ok }' "$DIST/$s" \
            || { echo "    $s does not sign after writing latest.json"; return 1; }
        grep -q 'latest.json.sig' "$DIST/$s" || { echo "    $s next steps miss latest.json.sig"; return 1; }
    done
}
test_gitattributes_keep_bytes() {
    git -C "$DIST" check-attr text -- shared/latest.json shared/latest.json.sig | grep -c ': text: unset' | grep -q '^2$' \
        || { echo "    shared/latest.json(.sig) must be -text"; return 1; }
}

run_test test_main_key_signs
run_test test_backup_key_signs
run_test test_unknown_key_is_refused
run_test test_missing_key_is_refused
run_test test_release_scripts_sign
run_test test_gitattributes_keep_bytes
echo; echo "$RUN tests, $FAILED failed"
[ "$FAILED" -eq 0 ]

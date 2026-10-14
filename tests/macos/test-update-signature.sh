#!/usr/bin/env bash
# v2.0 plan 4: the macOS updater refuses unsigned or wrongly signed update
# information before it backs up or stops anything. No database or network:
# latest.json is read from a file:// URL. Every case serves the installed
# version 1.4.3, so even a broken check can only end at "up to date" — it can
# never reach the backup / stop-system steps. Rejected = refused although up to date.
. "$(dirname "$0")/../lib.sh"
KEYS="$WORK_ROOT/keys"
mkdir -p "$KEYS"
for k in primary backup stranger; do
    openssl genrsa -out "$KEYS/$k.pem" 2048 2>/dev/null
    openssl rsa -in "$KEYS/$k.pem" -pubout -out "$KEYS/$k-public.pem" 2>/dev/null
done

# serve <dir> <version> <primary|backup|stranger|none>: latest.json (+ .sig) in <dir>
serve() {
    mkdir -p "$1"
    printf '{\n  "latestVersion": "%s",\n  "platforms": {"macos": {"packageUrl": "file:///nonexistent.zip", "sha256": ""}},\n  "notesUrl": "https://example.invalid/notes"\n}\n' "$2" > "$1/latest.json"
    rm -f "$1/latest.json.sig"
    [ "$3" = "none" ] && return 0
    openssl dgst -sha256 -sign "$KEYS/$3.pem" "$1/latest.json" | openssl base64 -A | tr -d '\n' > "$1/latest.json.sig"
}
# install_with_keys <dir>: a v1.4.3-numbered installation whose app/ has the test public keys
install_with_keys() {
    make_install "$1" root "" 1.4.3
    cp "$KEYS/primary-public.pem" "$1/app/update-signing-public.pem"
    cp "$KEYS/backup-public.pem" "$1/app/update-signing-backup-public.pem"
}
run_update() { JIG_UPDATE_URL="file://$2/latest.json" bash "$1/scripts/UPDATE-JIG-NETWORK-APP.command" --auto 2>&1; }

expect_accepted() {
    local out rc=0
    out="$(run_update "$1" "$2")" || rc=$?
    check "$rc" 0 "updater exit code" || { echo "$out"; return 1; }
    echo "$out" | grep -q "System is up to date" || { echo "    no 'up to date' message"; echo "$out"; return 1; }
    [ ! -f "$1/logs/last-update.txt" ] || { echo "    last-update.txt was written"; return 1; }
}
expect_rejected() {
    local out rc=0
    out="$(run_update "$1" "$2")" || rc=$?
    check "$rc" 1 "updater exit code" || { echo "$out"; return 1; }
    echo "$out" | grep -q "invalid signature" || { echo "    no signature message"; echo "$out"; return 1; }
    check "$(cut -d';' -f1-3 "$1/logs/last-update.txt")" "FAILED_NOCHANGE;1.4.3;" "result line" || return 1
    grep -q "aurastudio.studio.service@gmail.com" "$1/logs/last-update.txt" || { echo "    no support address"; return 1; }
    [ ! -d "$1/backups" ] || { echo "    a backup was started: the update went past the check"; return 1; }
}

test_signed_by_main_key_is_accepted() {
    local d="$WORK_ROOT/main"; install_with_keys "$d/inst"; serve "$d/srv" 1.4.3 primary
    expect_accepted "$d/inst" "$d/srv"
}
test_signed_by_backup_key_is_accepted() {
    local d="$WORK_ROOT/backup"; install_with_keys "$d/inst"; serve "$d/srv" 1.4.3 backup
    expect_accepted "$d/inst" "$d/srv"
}
test_signature_with_line_break_is_accepted() {
    local d="$WORK_ROOT/newline"; install_with_keys "$d/inst"; serve "$d/srv" 1.4.3 primary
    printf '\r\n' >> "$d/srv/latest.json.sig"
    expect_accepted "$d/inst" "$d/srv"
}
test_signed_by_unknown_key_is_rejected() {
    local d="$WORK_ROOT/stranger"; install_with_keys "$d/inst"; serve "$d/srv" 1.4.3 stranger
    expect_rejected "$d/inst" "$d/srv"
}
test_changed_after_signing_is_rejected() {
    local d="$WORK_ROOT/changed"; install_with_keys "$d/inst"; serve "$d/srv" 1.4.3 primary
    printf '{\n  "latestVersion": "1.4.3",\n  "platforms": {"macos": {"packageUrl": "file:///nonexistent.zip", "sha256": ""}},\n  "notesUrl": "https://example.invalid/changed"\n}\n' > "$d/srv/latest.json"
    expect_rejected "$d/inst" "$d/srv"
}
test_missing_signature_is_rejected() {
    local d="$WORK_ROOT/unsigned"; install_with_keys "$d/inst"; serve "$d/srv" 1.4.3 none
    expect_rejected "$d/inst" "$d/srv"
}
test_install_without_public_keys_is_rejected() {
    local d="$WORK_ROOT/nokeys"; make_install "$d/inst" root "" 1.4.3; serve "$d/srv" 1.4.3 primary
    expect_rejected "$d/inst" "$d/srv"
}

run_test test_signed_by_main_key_is_accepted
run_test test_signed_by_backup_key_is_accepted
run_test test_signature_with_line_break_is_accepted
run_test test_signed_by_unknown_key_is_rejected
run_test test_changed_after_signing_is_rejected
run_test test_missing_signature_is_rejected
run_test test_install_without_public_keys_is_rejected
finish

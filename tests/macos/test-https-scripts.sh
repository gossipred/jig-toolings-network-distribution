#!/usr/bin/env bash
# v2.0 plan 5: HTTPS helpers in the macOS launcher scripts. No database, no Java:
# a fake runtime/bin/java records how the enable/disable scripts call the program.
. "$(dirname "$0")/../lib.sh"

# props <dir> <lines>: an installation (current scripts) whose settings file ends with <lines>
props() {
    make_install "$1" root "" 2.0.0
    printf "$2" >> "$1/app/application.properties"
}
# fake_java <dir> <exit code>: runtime/bin/java writes "<cwd>|<args>" to <dir>/java-call.txt
fake_java() {
    mkdir -p "$1/runtime/bin"
    printf '#!/bin/sh\necho "$(pwd)|$*" > "%s/java-call.txt"\nexit %s\n' "$1" "$2" > "$1/runtime/bin/java"
    chmod +x "$1/runtime/bin/java"
}

test_https_port_is_empty_when_off() {
    local d="$WORK_ROOT/off"; props "$d" ''
    check "$(. "$MAC_SCRIPTS/jig-port.sh"; jig_read_https_port "$d")" "" "no HTTPS port" || return 1
    props "$d" 'app.https.enabled=false\napp.https.port=9443\n'
    check "$(. "$MAC_SCRIPTS/jig-port.sh"; jig_read_https_port "$d")" "" "disabled" || return 1
}
test_https_port_defaults_to_8443() {
    local d="$WORK_ROOT/default"; props "$d" 'app.https.enabled=true\n'
    check "$(. "$MAC_SCRIPTS/jig-port.sh"; jig_read_https_port "$d")" "8443" "default port" || return 1
}
test_https_port_custom_and_case_insensitive() {
    local d="$WORK_ROOT/custom"; props "$d" 'app.https.enabled = TRUE\napp.https.port = 9443\n'
    check "$(. "$MAC_SCRIPTS/jig-port.sh"; jig_read_https_port "$d")" "9443" "custom port" || return 1
}
test_show_network_address_shows_https() {
    local d="$WORK_ROOT/show"; props "$d" 'app.https.enabled=true\n'
    bash "$d/scripts/show-network-address.command" < /dev/null | grep -q "https://SERVER-IP:8443" \
        || { echo "    no https address"; return 1; }
}
test_show_network_address_without_https() {
    local d="$WORK_ROOT/show-off"; props "$d" ''
    local out; out="$(bash "$d/scripts/show-network-address.command" < /dev/null)"
    echo "$out" | grep -q "http://SERVER-IP:18080" || { echo "    no http address"; return 1; }
    echo "$out" | grep -q "https://" && { echo "    https shown although off"; return 1; }
    return 0
}
test_enable_https_runs_the_program() {
    local d="$WORK_ROOT/enable" rc=0; props "$d" ''; fake_java "$d" 0
    bash "$d/scripts/enable-https.command" < /dev/null > /dev/null || rc=$?
    check "$rc" 0 "exit code" || return 1
    check "$(cat "$d/java-call.txt")" "$(cd "$d/app" && pwd)|-jar jig-management-system.jar enable-https application.properties" "java call" || return 1
}
test_disable_https_reports_failure() {
    local d="$WORK_ROOT/disable" rc=0; props "$d" ''; fake_java "$d" 1
    bash "$d/scripts/disable-https.command" < /dev/null > /dev/null || rc=$?
    check "$rc" 1 "exit code" || return 1
    check "$(cat "$d/java-call.txt")" "$(cd "$d/app" && pwd)|-jar jig-management-system.jar disable-https application.properties" "java call" || return 1
}

run_test test_https_port_is_empty_when_off
run_test test_https_port_defaults_to_8443
run_test test_https_port_custom_and_case_insensitive
run_test test_show_network_address_shows_https
run_test test_show_network_address_without_https
run_test test_enable_https_runs_the_program
run_test test_disable_https_reports_failure
finish

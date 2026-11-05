#!/usr/bin/env bash
# Shared by both release builders; this file has no build or upload side effects.
check_no_xampp_installer() {
    local found
    found="$(find "$1" -name 'XAMPP-installer*' -print -quit)" || return 1
    if [ -n "$found" ]; then
        echo "[ERROR] XAMPP installers must not be packaged or uploaded: $found" >&2
        echo "        Move the installer to private storage; use the official links in the installation guide." >&2
        return 1
    fi
}

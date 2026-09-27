# Shared helpers, sourced by the .command scripts:  . "$SCRIPT_DIR/jig-port.sh"
# macOS ships bash 3.2 — keep this file free of bash 4 syntax.

# Prints server.port from <package>/app/application.properties (default 8080).
jig_read_port() {
    local props="$1/app/application.properties" p=""
    if [ -f "$props" ]; then
        p="$(grep -E '^[[:space:]]*server\.port[[:space:]]*=' "$props" | tail -n 1 | cut -d= -f2- | tr -d '[:space:]')"
    fi
    case "$p" in
        ''|*[!0-9]*) p=8080 ;;
    esac
    echo "$p"
}

# Prints the PIDs of Java processes listening on a port (never other programs).
jig_java_pids_on_port() {
    local pid
    for pid in $(lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null); do
        if ps -p "$pid" -o comm= 2>/dev/null | grep -qi java; then
            echo "$pid"
        fi
    done
}

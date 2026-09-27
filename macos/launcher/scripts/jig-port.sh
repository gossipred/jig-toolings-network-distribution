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

# Asks the running system on a port to back up before it is stopped. The system
# decides: it skips when today's backup is done or the option is off.
jig_backup_before_stop() {
    local port="$1" token_file="$2/logs/.internal-token" token
    [ -n "$port" ] && [ -f "$token_file" ] || return 0
    token="$(tr -d '[:space:]' < "$token_file" 2>/dev/null)"
    echo "Checking today's backup before stopping (this can take a minute)..."
    if ! curl -s -m 900 -X POST -H "X-Jig-Token: $token" "http://127.0.0.1:$port/internal/backup/before-stop" \
            | sed 's/^/  /'; then
        echo "  (Backup check skipped: the system did not answer.)"
    fi
}

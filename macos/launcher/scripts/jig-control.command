#!/usr/bin/env bash
# Jig System Control / 治具系統控制: one menu to start, stop or check the system and its MySQL.
# Start: MySQL (LaunchDaemon from setup-mysql-autostart.command) -> start-system.command.
# Stop:  stop-system.command -> MySQL.
# Tests: JIG_CONTROL_ACTION=start|stop|status skips the menu; DRY_RUN=1 prints admin commands.
# macOS bash 3.2.
set -u
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$(cd .. && pwd)"
. "$SCRIPT_DIR/jig-port.sh"
MYSQL_LABEL="studio.aurastudio.jig-mysql"
MYSQL_PLIST="${JIG_MYSQL_PLIST:-/Library/LaunchDaemons/$MYSQL_LABEL.plist}"
MYSQLADMIN="${JIG_MYSQLADMIN:-/Applications/XAMPP/xamppfiles/bin/mysqladmin}"
WAIT="${JIG_MYSQL_WAIT:-60}"
DRY_RUN="${DRY_RUN:-0}"
TITLE="治具系統控制 Jig System Control"

# mysqladmin ping answers "mysqld is alive" without a password whenever the server runs.
mysql_up() { "$MYSQLADMIN" ping >/dev/null 2>&1; }
admin() {
    if [ "$DRY_RUN" = "1" ]; then echo "  [dry-run] $1"; return 0; fi
    osascript -e 'on run argv' -e 'do shell script (item 1 of argv) with administrator privileges' -e 'end run' "$1" >/dev/null
}
say() { if [ -n "${JIG_CONTROL_ACTION:-}" ]; then echo "$1"; else osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {"OK"} default button 1 with title (item 2 of argv)' -e 'end run' "$1" "$TITLE" >/dev/null; fi; }

status_text() {
    local port https m s
    port="$(jig_read_port "$PACKAGE_DIR")"
    https="$(jig_read_https_port "$PACKAGE_DIR")"
    if mysql_up; then m="✅ MySQL 執行中 running"; else m="❌ MySQL 未執行 not running"; fi
    if [ -n "$(jig_java_pids_on_port "$port")" ]; then s="✅ 治具系統執行中 Jig system running"; else s="❌ 治具系統未執行 Jig system not running"; fi
    printf '%s\n%s\n\nhttp://localhost:%s' "$m" "$s" "$port"
    [ -n "$https" ] && printf '\nhttps://localhost:%s' "$https"
    local ip
    ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
    [ -n "$ip" ] && printf '\n其他電腦 Other computers: http://%s:%s' "$ip" "$port"
    printf '\n'
}

ACTION="${JIG_CONTROL_ACTION:-}"
if [ -z "$ACTION" ]; then
    CHOICE="$(osascript -e 'choose from list {"啟動 Start", "停止 Stop", "查看狀態 Status"} with title "治具系統控制 Jig System Control" with prompt "請選擇動作 Choose an action:" default items {"查看狀態 Status"}')"
    case "$CHOICE" in
        *Start*) ACTION=start ;;
        *Stop*) ACTION=stop ;;
        *Status*) ACTION=status ;;
        *) exit 0 ;;
    esac
fi

case "$ACTION" in
start)
    if ! mysql_up; then
        if [ ! -f "$MYSQL_PLIST" ]; then
            say "MySQL 未執行，也還沒設定自動啟動。請先點兩下 scripts 裡的 setup-mysql-autostart.command。
MySQL is not running and auto-start is not set up. Run scripts/setup-mysql-autostart.command first."
            exit 1
        fi
        echo "Starting MySQL... 正在啟動 MySQL..."
        admin "launchctl kickstart -k system/$MYSQL_LABEL" || exit 1
        i=0
        while ! mysql_up && [ "$i" -lt "$WAIT" ] && [ "$DRY_RUN" != "1" ]; do sleep 1; i=$((i + 1)); done
        if ! mysql_up && [ "$DRY_RUN" != "1" ]; then
            say "MySQL $WAIT 秒內沒有啟動，請看 /Library/Logs/jig-mysql-autostart.log。
MySQL did not start within $WAIT seconds. See /Library/Logs/jig-mysql-autostart.log."
            exit 1
        fi
    fi
    exec bash "$SCRIPT_DIR/start-system.command"
    ;;
stop)
    bash "$SCRIPT_DIR/stop-system.command" < /dev/null
    if mysql_up; then
        echo "Stopping MySQL... 正在停止 MySQL..."
        admin "/Applications/XAMPP/xamppfiles/xampp stopmysql"
    fi
    say "已停止。Stopped.
$(status_text)"
    ;;
status)
    say "$(status_text)"
    ;;
esac

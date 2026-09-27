#!/usr/bin/env bash
# One-time setup: start XAMPP MySQL automatically at every boot.
# Installs a LaunchDaemon (runs as root at boot, before anyone logs in), so the
# customer never has to open XAMPP Control Panel — which newer macOS Gatekeeper
# may refuse to launch at all. Asks for the administrator password once.
# DRY_RUN=1 prints every privileged action instead of running it.
set -u
cd "$(dirname "$0")"

XAMPP="/Applications/XAMPP/xamppfiles/xampp"
LABEL="studio.aurastudio.jig-mysql"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER_DIR="/Library/Application Support/JigSystem"
HELPER="$HELPER_DIR/mysql-autostart.sh"
LOG="/Library/Logs/jig-mysql-autostart.log"
DRY_RUN="${DRY_RUN:-0}"

run() { if [ "$DRY_RUN" = "1" ]; then echo "  [dry-run] sudo $*"; else sudo "$@"; fi; }
pause_exit() { echo; read -r -p "Press Enter to close..."; exit "$1"; }

echo "============================================================"
echo " MySQL auto-start setup (XAMPP for macOS)"
echo " MySQL 開機自動啟動設定"
echo "============================================================"
echo

if [ ! -x "$XAMPP" ]; then
    echo "[ERROR] XAMPP not found in /Applications/XAMPP. Please install XAMPP first."
    echo "[錯誤] 找不到 XAMPP，請先安裝 XAMPP-installer.dmg。"
    pause_exit 1
fi

MYSQL_EXE=""
for c in /Applications/XAMPP/bin/mysql /Applications/XAMPP/xamppfiles/bin/mysql; do
    [ -x "$c" ] && MYSQL_EXE="$c" && break
done

echo "You will be asked for your Mac login password (administrator)."
echo "接下來會要求輸入 Mac 登入密碼（管理員），輸入時畫面不會顯示字元，打完按 Enter。"
echo

# XAMPP for macOS is an Intel (x86_64) build: Apple Silicon Macs need Rosetta 2.
if [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "[INFO] Installing Rosetta 2 (required by XAMPP on Apple Silicon)..."
    if ! run softwareupdate --install-rosetta --agree-to-license; then
        echo "[ERROR] Rosetta 2 installation failed. Check the internet connection and try again."
        pause_exit 1
    fi
fi

TMP="$(mktemp -d)"
cat > "$TMP/mysql-autostart.sh" <<'EOF'
#!/bin/bash
# Boot helper for studio.aurastudio.jig-mysql. Right after boot (or a macOS
# upgrade) Rosetta 2 may not be ready yet and XAMPP's x86_64 binaries fail with
# "Bad CPU type" — wait up to 2 minutes for it before starting MySQL.
if [ "$(uname -m)" = "arm64" ]; then
    for i in $(seq 1 60); do
        arch -x86_64 /usr/bin/true 2>/dev/null && break
        sleep 2
    done
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') starting XAMPP MySQL"
/Applications/XAMPP/xamppfiles/xampp startmysql
EOF

cat > "$TMP/$LABEL.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>/bin/bash</string><string>$HELPER</string></array>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>$LOG</string>
    <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

echo "[1/3] Installing boot helper..."
run mkdir -p "$HELPER_DIR"
run cp "$TMP/mysql-autostart.sh" "$HELPER"
run chmod 755 "$HELPER"
run cp "$TMP/$LABEL.plist" "$PLIST"
run chown root:wheel "$PLIST"
run chmod 644 "$PLIST"
rm -rf "$TMP"

echo "[2/3] Registering auto-start and starting MySQL now..."
run launchctl bootout system "$PLIST" 2>/dev/null || true
if ! run launchctl bootstrap system "$PLIST"; then
    echo "[ERROR] Could not register the auto-start service."
    pause_exit 1
fi

echo "[3/3] Waiting for MySQL..."
if [ "$DRY_RUN" = "1" ] || [ -z "$MYSQL_EXE" ]; then
    echo "  (skipped)"
else
    for i in $(seq 1 30); do
        if "$MYSQL_EXE" -u root -e "SELECT 1" >/dev/null 2>&1; then
            echo
            echo "[OK] MySQL is running and will start automatically at every boot."
            echo "[完成] MySQL 已啟動，以後開機會自動啟動，不需要再開 XAMPP Control Panel。"
            pause_exit 0
        fi
        sleep 2
    done
    echo "[ERROR] MySQL did not respond within 60 seconds. Log: $LOG"
    echo "[錯誤] MySQL 60 秒內沒有回應，請將 $LOG 的內容提供給我們。"
    pause_exit 1
fi
pause_exit 0

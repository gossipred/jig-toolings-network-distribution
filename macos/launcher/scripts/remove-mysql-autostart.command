#!/usr/bin/env bash
# Undo setup-mysql-autostart.command (MySQL itself and its data are not touched).
set -u
LABEL="studio.aurastudio.jig-mysql"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
HELPER_DIR="/Library/Application Support/JigSystem"
DRY_RUN="${DRY_RUN:-0}"
run() { if [ "$DRY_RUN" = "1" ]; then echo "  [dry-run] sudo $*"; else sudo "$@"; fi; }

echo "Removing MySQL auto-start (MySQL data is kept). Mac password may be required."
echo "移除 MySQL 開機自動啟動（資料庫資料保留），可能需要輸入 Mac 登入密碼。"
run launchctl bootout system "$PLIST" 2>/dev/null || true
run rm -f "$PLIST"
run rm -rf "$HELPER_DIR"
echo "[OK] Auto-start removed. / 已移除。"
echo
read -r -p "Press Enter to close..."

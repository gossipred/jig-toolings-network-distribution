## 🔄 如何更新到 v1.4.0（線上更新）/ How to update to v1.4.0 (online)

**已安裝 v1.3.1 的電腦：可以直接線上更新，不用重新安裝。**
**Installed v1.3.1: update online, no reinstall needed.**

1. 選下班或休息時段（更新時系統會停止幾分鐘）/ Pick a quiet time (the system stops for a few minutes)
2. 在伺服器點兩下 / On the server double-click:
   - Windows：`scripts\UPDATE-JIG-NETWORK-APP.bat`
   - macOS：`scripts/UPDATE-JIG-NETWORK-APP.command`
3. 輸入 Y 開始 / Type Y to start → 自動備份、下載、更新、套用資料庫變更、重新啟動 / backs up, downloads, updates, applies database changes and restarts automatically

設定（port、資料庫密碼）、授權、附件與資料全部保留。Settings, license, attachments and data are all kept.

| | 線上更新說明（中英）/ Online update guide |
|---|---|
| Windows | [UPDATE-GUIDE-Windows.txt](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/UPDATE-GUIDE-Windows.txt) |
| macOS | [UPDATE-GUIDE-macOS.txt](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/UPDATE-GUIDE-macOS.txt) |

> **v1.3.0 以前的版本**：舊的更新程式只會換主程式，請先依線上更新說明「從 v1.3.0 或更早版本升級」手動升級一次，之後就能線上更新。
> **v1.3.0 or earlier:** follow "Upgrading from v1.3.0 or earlier" in the update guide once; online updates work from then on.

---

## What's new in v1.4.0 — 自動備份 / Automatic backup

- **每日自動備份資料庫與上傳附件**（預設 18:00，可在「系統設定 → 資料備份」修改）。Daily automatic backup of the database **and uploaded attachments** (18:00 by default).
- **停止系統時備份**：今天還沒備份就先備份再停止；**開機補做**：備份時間電腦沒開，下次開機後自動補做。Backs up before the system stops if today's backup is missing; catches up after start-up if the computer was off.
- **保留 10 份**（可調整），舊的自動刪除。Keeps the latest 10 backups (adjustable).
- **外接裝置同步備份**：指定外接硬碟或 NAS，每次備份會把**資料庫與所有附件**一起存一份。External drive / NAS: every backup also saves the **database and all attachments** there.
- **立即備份**按鈕、最近備份狀態與清單；備份失敗時管理員首頁會提示。"Back up now" button, last-backup status and list; admins see a warning on the home page when a backup fails.
- **還原工具**（`restore-backup`）與**還原說明**（系統設定的「還原說明」按鈕）。還原前自動保存目前資料庫。Restore tool and restore guide; the current database is saved before restoring.
- 修正 Windows 手動備份腳本無法執行的問題。Fixed the Windows manual backup script.

## 說明文件 / Guides

| | 中文 | English | 中英合併 / Bilingual |
|---|---|---|---|
| Windows | [安裝說明](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-zh-TW.txt) | [Install guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-en.txt) | [線上更新](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/UPDATE-GUIDE-Windows.txt) · [還原](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/RESTORE-GUIDE-Windows.txt) · [更改 Port](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/PORT-CHANGE-GUIDE-Windows.txt) |
| macOS | [安裝說明](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-macOS-zh-TW.txt) | [Install guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-macOS-en.txt) | [線上更新](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/UPDATE-GUIDE-macOS.txt) · [還原](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/RESTORE-GUIDE-macOS.txt) · [更改 Port](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/PORT-CHANGE-GUIDE-macOS.txt) |

**新安裝 / New installation:** XAMPP：本頁的 `XAMPP-installer.exe` / `XAMPP-installer.dmg`，或官方網站 https://www.apachefriends.org/download.html

## Packages

| 平台 Platform | 檔案 File |
|------|------|
| Windows（第 1 步 Step 1） | `XAMPP-installer.exe` |
| Windows（第 2 步，建議 Step 2, recommended） | `JigToolingsSetup-1.4.0.exe` |
| Windows（第 2 步，手動版 Step 2, manual） | `jig-toolings-network-windows-1.4.0.zip` |
| macOS（第 1 步 Step 1） | `XAMPP-installer.dmg` |
| macOS（第 2 步 Step 2） | `jig-toolings-network-macos-1.4.0.zip` |
| 說明文件 Guides | `INSTALL-GUIDE-*`、`UPDATE-GUIDE-*`、`RESTORE-GUIDE-*`、`PORT-CHANGE-GUIDE-*` |

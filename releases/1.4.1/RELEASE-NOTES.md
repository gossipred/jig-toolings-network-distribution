## 🔄 如何更新到 v1.4.1（線上更新）/ How to update to v1.4.1 (online)

**已安裝 v1.4.0：用管理員帳號登入，首頁按 Check for Updates → 立即更新 / Update now，系統會自動備份、更新並重新啟動。**
**Installed v1.4.0: sign in as admin, click Check for Updates on the home page → Update now. The system backs up, updates and restarts by itself.**

**已安裝 v1.3.1：**在伺服器點兩下 `scripts\UPDATE-JIG-NETWORK-APP.bat`（Windows）或 `scripts/UPDATE-JIG-NETWORK-APP.command`（macOS），輸入 Y。
**Installed v1.3.1:** on the server double-click `scripts\UPDATE-JIG-NETWORK-APP.bat` (Windows) or `scripts/UPDATE-JIG-NETWORK-APP.command` (macOS) and type Y.

設定（port、資料庫密碼）、授權、附件與資料全部保留。本版沒有資料庫變更。Settings, license, attachments and data are all kept. No database changes in this release.

> **v1.3.0 以前的版本**：請先依線上更新說明「從 v1.3.0 或更早版本升級」手動升級一次。/ **v1.3.0 or earlier:** follow "Upgrading from v1.3.0 or earlier" in the update guide once.

---

## What's new in v1.4.1

- **偵測外接硬碟**：系統設定 → 資料備份會列出伺服器電腦上的外接硬碟、隨身碟與網路磁碟（含剩餘空間），點一下就填入外接備份路徑（`<磁碟>/JigBackup`）。**Detected drives:** Settings → Data Backup lists external drives, USB sticks and network drives on the server computer (with free space); click one to fill in the external backup folder.
- **升級時清除舊檔**：用安裝精靈覆蓋升級時，也會移除舊版留下、已改名的檔案（例如舊的安裝說明）。**Installer upgrades now remove obsolete files** left by older versions (e.g. old install guides).
- 使用說明標題改為 Aura Studio，並附上聯絡信箱；說明文件的版本號與程式一致。User guides now carry the Aura Studio name and contact email; guide headers always match the program version.

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
| Windows（第 2 步，建議 Step 2, recommended） | `JigToolingsSetup-1.4.1.exe` |
| Windows（第 2 步，手動版 Step 2, manual） | `jig-toolings-network-windows-1.4.1.zip` |
| macOS（第 1 步 Step 1） | `XAMPP-installer.dmg` |
| macOS（第 2 步 Step 2） | `jig-toolings-network-macos-1.4.1.zip` |
| 說明文件 Guides | `INSTALL-GUIDE-*`、`UPDATE-GUIDE-*`、`RESTORE-GUIDE-*`、`PORT-CHANGE-GUIDE-*` |

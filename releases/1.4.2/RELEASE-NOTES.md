## 🔄 如何更新到 v1.4.2（線上更新）/ How to update to v1.4.2 (online)

**已安裝 v1.4.0 或 v1.4.1：用管理員帳號登入，首頁按 Check for Updates → 立即更新 / Update now，系統會自動備份、更新並重新啟動。**
**Installed v1.4.0 or v1.4.1: sign in as admin, click Check for Updates on the home page → Update now. The system backs up, updates and restarts by itself.**

**已安裝 v1.3.1：**在伺服器點兩下 `scripts\UPDATE-JIG-NETWORK-APP.bat`（Windows）或 `scripts/UPDATE-JIG-NETWORK-APP.command`（macOS），輸入 Y。
**Installed v1.3.1:** on the server double-click `scripts\UPDATE-JIG-NETWORK-APP.bat` (Windows) or `scripts/UPDATE-JIG-NETWORK-APP.command` (macOS) and type Y.

設定（port、資料庫密碼）、授權、附件與資料全部保留。本版有資料庫變更，更新時會自動套用。Settings, license, attachments and data are all kept. Database changes are applied automatically.

> **v1.3.0 以前的版本**：請先依線上更新說明「從 v1.3.0 或更早版本升級」手動升級一次。/ **v1.3.0 or earlier:** follow "Upgrading from v1.3.0 or earlier" in the update guide once.

---

## What's new in v1.4.2 — 刪除確認與刪除紀錄 / Delete confirmation and Deleted Records

- **刪除前確認**：主管、管理員刪除治具時，必須輸入該治具編號並填寫刪除原因，避免誤刪。**Delete confirmation:** deleting a jig needs the exact Jig No. and a reason.
- **刪除紀錄**：刪除的治具不會真的消失，會連同附件與異動紀錄移到「刪除紀錄」（管理員首頁的 Deleted Records），可搜尋。**Deleted Records:** deleted jigs are kept with their files and change logs, and can be searched (admin home → Deleted Records).
- **還原**：管理員可從刪除紀錄還原，還原時必須填寫原因；刪除與還原都會記在異動紀錄。刪除紀錄無法永久刪除，方便追查。**Restore:** admins restore a jig with a required reason; deletes and restores are logged. Records cannot be removed permanently.
- **編號不重複使用**：已刪除的治具編號會保留，「Get Next」會自動跳過，新增時也會提示。**Jig No. never reused:** Get Next skips deleted numbers.
- 刪除單一附件前會先確認。Deleting an attachment asks for confirmation first.
- 本版有資料庫變更，線上更新時會自動套用（先自動備份資料庫）。This release changes the database; the online update applies it automatically after backing up.

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
| Windows（第 2 步，建議 Step 2, recommended） | `JigToolingsSetup-1.4.2.exe` |
| Windows（第 2 步，手動版 Step 2, manual） | `jig-toolings-network-windows-1.4.2.zip` |
| macOS（第 1 步 Step 1） | `XAMPP-installer.dmg` |
| macOS（第 2 步 Step 2） | `jig-toolings-network-macos-1.4.2.zip` |
| 說明文件 Guides | `INSTALL-GUIDE-*`、`UPDATE-GUIDE-*`、`RESTORE-GUIDE-*`、`PORT-CHANGE-GUIDE-*` |

## 🔄 如何更新到 v1.4.3（線上更新）/ How to update to v1.4.3 (online)

**已安裝 v1.4.0 – v1.4.2：用管理員帳號登入，首頁按 Check for Updates → 立即更新 / Update now，系統會自動備份、更新並重新啟動。**
**Installed v1.4.0 – v1.4.2: sign in as admin, click Check for Updates on the home page → Update now. The system backs up, updates and restarts by itself.**

**已安裝 v1.3.1：**在伺服器點兩下 `scripts\UPDATE-JIG-NETWORK-APP.bat`（Windows）或 `scripts/UPDATE-JIG-NETWORK-APP.command`（macOS），輸入 Y。
**Installed v1.3.1:** on the server double-click `scripts\UPDATE-JIG-NETWORK-APP.bat` (Windows) or `scripts/UPDATE-JIG-NETWORK-APP.command` (macOS) and type Y.

設定（port、資料庫密碼）、授權、附件與資料全部保留。本版沒有資料庫變更。Settings, license, attachments and data are all kept. No database changes in this release.

> **v1.3.0 以前的版本**：請先依線上更新說明「從 v1.3.0 或更早版本升級」手動升級一次。/ **v1.3.0 or earlier:** follow "Upgrading from v1.3.0 or earlier" in the update guide once.

---

## What's new in v1.4.3 — 授權頁說明更新 / License page instructions

- **授權頁說明更正**：原本寫「使用 JIG License Manager 產生授權檔」，但那是發行者內部工具，客戶沒有。現在改為：複製 Machine ID → 到 [aurastudio.studio/license-center](https://aurastudio.studio/license-center/) 登記購買 → 確認收款後授權檔寄到你的 Email → 在授權頁上傳啟用。**License page:** the instructions now say to copy the Machine ID, register it at aurastudio.studio/license-center, and upload the license file that is emailed to you after payment (instead of pointing to the publisher's internal tool).
- 權限規則不變（與單機版 v1.4.1 統一，以網路版為準）。Role permissions are unchanged; the standalone edition v1.4.1 now follows the same rules.

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
| Windows（第 2 步，建議 Step 2, recommended） | `JigToolingsSetup-1.4.3.exe` |
| Windows（第 2 步，手動版 Step 2, manual） | `jig-toolings-network-windows-1.4.3.zip` |
| macOS（第 1 步 Step 1） | `XAMPP-installer.dmg` |
| macOS（第 2 步 Step 2） | `jig-toolings-network-macos-1.4.3.zip` |
| 說明文件 Guides | `INSTALL-GUIDE-*`、`UPDATE-GUIDE-*`、`RESTORE-GUIDE-*`、`PORT-CHANGE-GUIDE-*` |

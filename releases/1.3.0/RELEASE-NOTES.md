## ⚠️ 安裝前請先閱讀 / Read before installing

| | 中文 | English |
|---|---|---|
| **Windows** | [安裝說明](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-zh-TW.txt) | [Install guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-en.txt) |
| **macOS** | [安裝說明](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-macOS-zh-TW.txt) | [Install guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-macOS-en.txt) |

**XAMPP（MySQL 資料庫）**：建議使用本頁的 `XAMPP-installer.exe` / `XAMPP-installer.dmg`（已測試版本），也可以到官方網站下載：https://www.apachefriends.org/download.html
**XAMPP (MySQL database):** use `XAMPP-installer.exe` / `XAMPP-installer.dmg` from this page (tested versions), or download from the official website: https://www.apachefriends.org/download.html

### 🪟 Windows — 兩步驟，順序不可顛倒

1. **先安裝 XAMPP**：執行 `XAMPP-installer.exe`
   - 跳出 UAC 英文警告 → 按「確定」即可
   - Select Components 只需要 **MySQL**，其他可取消勾選
   - 安裝路徑**保持預設 `C:\xampp`**，請勿更改
   - 解壓縮約 5–10 分鐘，請耐心等候
2. **再安裝治具系統**：執行 `JigToolingsSetup-1.3.0.exe`（建議）
   - 自動設定 MySQL 開機啟動、建立資料庫、建立桌面捷徑
   - 或改用手動版 `jig-toolings-network-windows-1.3.0.zip`（步驟見安裝說明）
3. **啟動**：點桌面「治具管理系統」→ 看到 `[OK] The system is ready.` → 瀏覽器開啟登入頁

### 🍎 macOS

1. **安裝 XAMPP**：執行 `XAMPP-installer.dmg`（M 系列晶片若詢問 Rosetta → 安裝）
2. **解壓縮** `jig-toolings-network-macos-1.3.0.zip`，把 `mac-network-app` 放到固定位置
3. **MySQL 開機自動啟動**：`scripts/setup-mysql-autostart.command`（輸入 Mac 密碼一次）
4. **建立資料庫**：`scripts/install-database.command`
5. **啟動**：`START-JIG-NETWORK-APP.command` → 看到 `[OK] The system is ready.`

> 「無法確認開發者」：系統設定 → 隱私權與安全性 → 強制打開。詳見安裝說明。

**預設帳號 `admin` / 密碼 `123456`，登入後請立刻修改。第一次啟動自動開始 30 天免費試用。**

**English summary:** Windows — run `XAMPP-installer.exe` first (keep `C:\xampp`, only MySQL needed), then `JigToolingsSetup-1.3.0.exe`. macOS — install `XAMPP-installer.dmg`, unzip the package, run `setup-mysql-autostart.command`, `install-database.command`, then `START-JIG-NETWORK-APP.command`. Default login `admin` / `123456` (change it immediately). A 30-day trial starts automatically.

---

## What's new

- **Network version now includes an automatic 30-day free trial**, matching the standalone version. No license file needed on first launch — the trial starts automatically, bound to the server's Machine ID.
- Trial status and days remaining are shown on the /license page.
- **XAMPP is now a separate download** (2026-09-27) for both Windows and macOS — packages are much smaller.
- **macOS: new `setup-mysql-autostart.command`** — MySQL starts automatically at boot, no XAMPP control panel needed.
- **macOS: fixed** update and uninstall scripts failing with "bad substitution" on the built-in bash 3.2.

## Packages

| 平台 Platform | 檔案 File |
|------|------|
| Windows（第 1 步 Step 1） | `XAMPP-installer.exe` |
| Windows（第 2 步，建議 Step 2, recommended） | `JigToolingsSetup-1.3.0.exe` |
| Windows（第 2 步，手動版 Step 2, manual） | `jig-toolings-network-windows-1.3.0.zip` |
| macOS（第 1 步 Step 1） | `XAMPP-installer.dmg` |
| macOS（第 2 步 Step 2） | `jig-toolings-network-macos-1.3.0.zip` |
| 安裝說明 Install guides | `INSTALL-GUIDE-*.txt`（中文 / English） |

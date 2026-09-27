## ⚠️ 安裝前請先閱讀 / Read before installing

| | 安裝說明 中文 | Install guide English | 更改 Port 說明（中英）/ Changing the port |
|---|---|---|---|
| **Windows** | [安裝說明](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-zh-TW.txt) | [Install guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-en.txt) | [PORT-CHANGE-GUIDE-Windows.txt](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/PORT-CHANGE-GUIDE-Windows.txt) |
| **macOS** | [安裝說明](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-macOS-zh-TW.txt) | [Install guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-macOS-en.txt) | [PORT-CHANGE-GUIDE-macOS.txt](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/PORT-CHANGE-GUIDE-macOS.txt) |

**XAMPP（MySQL 資料庫）**：建議使用本頁的 `XAMPP-installer.exe` / `XAMPP-installer.dmg`（已測試版本），也可以到官方網站下載：https://www.apachefriends.org/download.html
**XAMPP (MySQL database):** use `XAMPP-installer.exe` / `XAMPP-installer.dmg` from this page (tested versions), or the official website: https://www.apachefriends.org/download.html

## 🔄 從 v1.3.0 或更早版本升級 / Upgrading from v1.3.0 or earlier

舊版的一鍵更新只會換主程式，所以**這一次**要照下面方式升級，之後的版本就能直接用一鍵更新。
Older one-click updaters only replaced the program, so upgrade **this once** as below; later versions update with one click.

| 原本的安裝方式 | 升級步驟 |
|---|---|
| **Windows 安裝精靈 (.exe)** | 執行 `JigToolingsSetup-1.3.1.exe`，安裝資料夾選**原本的資料夾** → 自動升級 |
| **Windows zip 手動版** | 從新的 zip 的 `scripts` 資料夾，把 `UPDATE-JIG-NETWORK-APP.bat`、`update-download.ps1` 複製到原本安裝的 `scripts` 資料夾（覆蓋），再執行 `UPDATE-JIG-NETWORK-APP.bat` |
| **macOS zip** | 從新的 zip 的 `scripts` 資料夾，把 `UPDATE-JIG-NETWORK-APP.command`、`update-download.sh` 複製到原本安裝的 `scripts` 資料夾（覆蓋），再執行 `UPDATE-JIG-NETWORK-APP.command` |

授權、上傳檔案、資料庫資料、port 與資料庫設定都會保留，升級前會自動備份到 `backups` 資料夾。
License, uploaded files, database data, port and database settings are kept; everything is backed up to `backups` first.

---

## What's new in v1.3.1

- **Change the web port** — new `change-port` tool (Windows `.bat` / macOS `.command`) when port 8080 is used by another program. All scripts now read the port from `app/application.properties`. 可更改連線埠：新增更改 Port 小工具，所有腳本改為讀取設定檔的 port。
- **One-click update now updates everything** — program, scripts, documents and Java runtime; keeps your settings and adds new ones; backs up the database first; applies database changes automatically. 一鍵更新改為完整更新：程式、腳本、文件一起更新，保留設定、先備份資料庫、自動套用資料庫變更。
- **Fixed:** version number stayed old after an update, so "update available" kept showing. 修正更新後版本號不變、一直提示有新版的問題。
- **Fixed (macOS):** update and uninstall scripts failed on the built-in bash 3.2; the updater could not find `update-download.sh`. 修正 macOS 更新與解除安裝腳本無法執行的問題。
- **macOS:** no longer asks to install Xcode command line tools at startup (removed python3 dependency). 啟動時不再跳出安裝開發者工具的視窗。
- **Windows:** the setup wizard can upgrade an existing installation safely; `stop-system` only stops this system, never another program on the same port. 安裝精靈可安全覆蓋升級；停止腳本只會關閉本系統。

## Packages

| 平台 Platform | 檔案 File |
|------|------|
| Windows（第 1 步 Step 1） | `XAMPP-installer.exe` |
| Windows（第 2 步，建議 Step 2, recommended） | `JigToolingsSetup-1.3.1.exe` |
| Windows（第 2 步，手動版 Step 2, manual） | `jig-toolings-network-windows-1.3.1.zip` |
| macOS（第 1 步 Step 1） | `XAMPP-installer.dmg` |
| macOS（第 2 步 Step 2） | `jig-toolings-network-macos-1.3.1.zip` |
| 說明文件 Guides | `INSTALL-GUIDE-*.txt`、`PORT-CHANGE-GUIDE-*.txt` |

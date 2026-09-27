## ⚠️ Windows 安裝前請先閱讀 / Read before installing on Windows

📄 **完整安裝說明（中文）：[INSTALL-GUIDE-Windows-zh-TW.txt](https://github.com/gossipred/jig-toolings-network-distribution/releases/latest/download/INSTALL-GUIDE-Windows-zh-TW.txt)**

**安裝分兩步，順序不可顛倒：**

1. **先安裝 XAMPP**：執行 `XAMPP-installer.exe`
   - 跳出 UAC 英文警告 → 按「確定」即可
   - Select Components 只需要 **MySQL**，其他可取消勾選
   - 安裝路徑**保持預設 `C:\xampp`**，請勿更改
   - 解壓縮約 5–10 分鐘，請耐心等候
2. **再安裝治具系統**：執行 `JigToolingsSetup-1.3.0.exe`（建議）
   - 自動設定 MySQL 開機啟動、建立資料庫、建立桌面捷徑
   - 或改用手動版 `jig-toolings-network-windows-1.3.0.zip`（步驟見安裝說明）
3. **啟動**：點桌面「治具管理系統」→ 看到 `[OK] The system is ready.` → 瀏覽器開啟登入頁
   - 預設帳號 `admin` / 密碼 `123456`，登入後請立刻修改
   - 第一次啟動自動開始 **30 天免費試用**

**Windows install in 2 steps:** run `XAMPP-installer.exe` first (keep the default path `C:\xampp`, only MySQL is needed), then run `JigToolingsSetup-1.3.0.exe`.

---

## What's new

- **Network version now includes an automatic 30-day free trial**, matching the standalone version. No license file needed on first launch — the trial starts automatically, bound to the server's Machine ID.
- Trial status and days remaining are shown on the /license page.
- **Windows: XAMPP is now a separate download** (2026-09-27). The installer no longer bundles XAMPP — install `XAMPP-installer.exe` first, then `JigToolingsSetup-1.3.0.exe`.

## Packages

| 平台 | 檔案 |
|------|------|
| macOS | `jig-toolings-network-macos-1.3.0.zip` |
| Windows（第 1 步） | `XAMPP-installer.exe` |
| Windows（第 2 步，建議） | `JigToolingsSetup-1.3.0.exe` |
| Windows（第 2 步，手動版） | `jig-toolings-network-windows-1.3.0.zip` |
| 安裝說明 | `INSTALL-GUIDE-Windows-zh-TW.txt` |

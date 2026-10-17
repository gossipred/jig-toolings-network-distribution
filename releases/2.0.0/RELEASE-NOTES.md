# v2.0.0 — Security, languages and installation improvements

**Before installing or upgrading, download and read the [illustrated Windows installation and upgrade guide](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.0/Jig-v2.0.0-Windows-Installation-and-Upgrade-Guide.pdf).**

安裝或升級前，請務必先下載閱讀安裝與升級指南。先備份資料庫、附件與設定；升級時保留原安裝資料夾。

## Downloads

- **[Windows installer](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.0/JigToolingsSetup-2.0.0.exe)** — install XAMPP first as explained in the guide.
- [Windows online-update package](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.0/jig-toolings-network-windows-2.0.0.zip).
- [macOS package](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.0/jig-toolings-network-macos-2.0.0.zip) — follow its bundled macOS installation guide and XAMPP prerequisites.
- [SHA-256 checksums](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.0/checksums.txt).

## Changes

- Stronger account/password handling, including mandatory password changes where required.
- Dedicated application database account and signed update-manifest verification for v2.0 onward.
- English, Traditional Chinese and Simplified Chinese interface support.
- Bundled Temurin 21 runtime and improved installation, service controls and customer documentation.
- Existing users, jig records, attachments, settings and license are preserved by the supported upgrade workflow.

帳號與密碼安全、多語介面、專用資料庫帳號、更新簽章驗證及安裝操作改善。既有使用者、治具資料、附件、設定與授權依升級流程保留。

## Upgrade

Back up first. Existing supported installations can use **Check for Updates** or their bundled update script after the public update manifest is enabled. Do not create a fresh installation over an existing database to upgrade. Do not close the application server console while using the system.

## Known issues and support

- An intermittent first-login HTTP 403 has been reported; its cause is not yet confirmed. If it occurs, copy logs and a screenshot before restarting. A v2.0.1 improvement will follow after diagnosis.
- Windows Stop may show a repeated process-not-found warning after stopping the application; use Status to confirm the actual state.
- Startup logs can be overwritten on restart. Preserve `C:\JigSystem\logs\jig-system.log` and `C:\JigSystem\logs\last-update.txt` before restarting.

Email selected logs, a screenshot, version and reproduction steps to **aurastudio.studio.service@gmail.com**. Do not email passwords, license secrets or full database backups.

若發生錯誤，請先保留上述日誌，再將日誌、畫面、版本與操作步驟寄給售後服務。請勿寄送密碼、授權機密或完整資料庫備份。

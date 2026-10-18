# v2.0.1: Sign-in recovery and startup logs

## How to update

Back up your database, attachments and settings first. Once v2.0.1 is published, open **Check for Updates**, select **Update now**, and wait for the system to restart. If your installation does not offer Update now, run `scripts/UPDATE-JIG-NETWORK-APP.bat` on Windows or `scripts/UPDATE-JIG-NETWORK-APP.command` on macOS and confirm the update. Keep the updater window open until it finishes. Reopen the login page and check that it shows v2.0.1.

先備份資料庫、附件與設定。v2.0.1 正式發布後，使用 Check for Updates → Update now；沒有更新按鈕時，執行安裝資料夾內對應平台的更新腳本。等更新完成、系統重新啟動後，確認登入頁顯示 v2.0.1。升級請沿用原安裝資料夾。

## Changes

- Repeated login submissions with an expired verification token now return signed-in users to the home page. Signed-out users return to the login page with a request to sign in again. Other access restrictions remain enforced.
- The login button is disabled after submission and becomes available again when returning with the browser Back button.
- Windows and macOS startup scripts append to `logs/jig-system.log`, preserving earlier entries. Each start adds a dated separator; Windows uses a locale-independent timestamp.
- Access-denied handling records the request method, path, exception type and sign-in state, without recording passwords, verification tokens or request parameters.
- This release adds no database schema changes. The updater still checks the installation's migration history.

改善重複送出登入造成的 403 畫面，並防止登入按鈕連按。Windows 與 macOS 啟動日誌改為接續寫入，保留舊紀錄並加入時間分隔線。本版沒有新增資料庫結構變更。

## Downloads

**[Download and read the Windows installation and upgrade guide before installing or upgrading](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.1/Jig-v2.0.1-Windows-Installation-and-Upgrade-Guide.pdf).**

安裝或升級前，請先下載閱讀安裝與升級指南。

- [Windows installer](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.1/JigToolingsSetup-2.0.1.exe)
- [Windows online-update package](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.1/jig-toolings-network-windows-2.0.1.zip)
- [macOS package](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.1/jig-toolings-network-macos-2.0.1.zip)
- [SHA-256 checksums](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.1/checksums.txt)

Download links become available when this release is published. Read the bundled installation guide before installing or upgrading. New installations require the XAMPP setup described in that guide.

## Support

If an update or sign-in fails, preserve `logs/jig-system.log` and `logs/last-update.txt`, then send the relevant log excerpts, a screenshot, the version and reproduction steps to **aurastudio.studio.service@gmail.com**. Do not send passwords, license files or database backups. Windows Stop may still show a process-not-found warning; use Status to check the actual service state.

若更新或登入失敗，先保留日誌，再將相關片段、畫面、版本與操作步驟寄給售後服務。請勿寄送密碼、授權檔或資料庫備份。

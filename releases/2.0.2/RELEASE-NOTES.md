# v2.0.2: MariaDB Connector/J and official XAMPP downloads

**[Download and read the Windows installation and upgrade guide BEFORE installing or upgrading](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/Jig-v2.0.2-Windows-Installation-and-Upgrade-Guide.pdf).**

安裝或升級前，請先下載閱讀安裝與升級指南。

- MariaDB Connector/J 3.5.6 replaces mysql-connector-j. Existing jdbc:mysql URLs and application.properties continue to work without edits.
- New installations download the tested XAMPP version from Apache Friends' official SourceForge project. Jig releases no longer distribute XAMPP. Check the exact version and SHA-256 in the installation guide.
- Upgrades retain settings, database, attachments and license. No XAMPP reinstallation or new schema migration is required for this release.
- Windows ZIP, Setup.exe and macOS ZIP include THIRD-PARTY-NOTICES.txt with the MariaDB LGPL-2.1 license and source links.

改用 MariaDB Connector/J 3.5.6，舊 jdbc:mysql 網址與設定檔原封不動沿用。新安裝的 XAMPP 改從 Apache Friends 官方指定版本下載，請核對指南中的版本與 SHA-256；Jig 發布頁不再提供 XAMPP。升級保留資料、附件、授權與設定，不需重裝 XAMPP；本版沒有新增資料庫 migration。安裝包附授權說明與原始碼連結。

## Downloads

- [Windows installer](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/JigToolingsSetup-2.0.2.exe)
- [Windows online-update ZIP](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/jig-toolings-network-windows-2.0.2.zip)
- [macOS ZIP](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/jig-toolings-network-macos-2.0.2.zip)
- [Administrator manual](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/Jig-Network-Administrator-Manual-v2.0.2.docx)
- [User manual](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/Jig-Network-User-Manual-v2.0.2.docx)
- [SHA-256 checksums](https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/checksums.txt)

Back up the database, attachments and settings first. After publication, use Check for Updates → Update now, or the bundled UPDATE-JIG-NETWORK-APP script. Keep the updater window open; confirm v2.0.2 after restart. Downloads become available only after publication.

升級前先備份，發布後以 Check for Updates → Update now 或安裝目錄內更新腳本更新；保留更新視窗直到結束，重啟後確認 v2.0.2。連結於正式發布後生效。

Support: aurastudio.studio.service@gmail.com. Send selected logs and screenshots; exclude passwords, settings, license files and database dumps.

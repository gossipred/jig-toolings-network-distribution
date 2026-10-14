; -- jig-setup.nsi -------------------------------------------------------------
; Windows setup wizard for Jig & Toolings Management System (English / 繁體中文).
; Windows picks the language from its display language; any language other
; than Traditional Chinese gets English (English is listed first).
; Build on macOS:
;   makensis -DVERSION=1.0.0 \
;            -DPACKAGE_DIR=/path/to/customer-package/windows-network-app \
;            -DOUTFILE=/path/to/dist/JigToolingsSetup-1.0.0.exe \
;            windows/installer/jig-setup.nsi
; -----------------------------------------------------------------------------

!include "MUI2.nsh"
!include "LogicLib.nsh"

; Required defines (passed by release-windows.sh with -D):
; VERSION     : e.g. 1.0.0
; PACKAGE_DIR : the assembled windows-network-app folder on the Mac
; OUTFILE     : full path of the EXE to write

; -- Product -------------------------------------------------------------------
!define PRODUCT_NAME      "Jig & Toolings Management System"
!define PRODUCT_VER       "${VERSION}"
!define PRODUCT_PUBLISHER "Aura Studio"
!define SHORTCUT_NAME     "Jig Toolings 治具管理系統"
!define OLD_SHORTCUT_NAME "治具管理系統"
!define REG_KEY           "Software\Microsoft\Windows\CurrentVersion\Uninstall\JigSystem"

; -- General -------------------------------------------------------------------
; The second name doubles "&" so it is not read as a keyboard shortcut.
Name            "${PRODUCT_NAME} v${PRODUCT_VER}" "Jig && Toolings Management System v${PRODUCT_VER}"
OutFile         "${OUTFILE}"
; Not under Program Files: the system writes into its own folder (logs, license,
; uploads, backups, settings) and standard users cannot write there.
InstallDir      "C:\JigSystem"
InstallDirRegKey HKLM "${REG_KEY}" "InstallLocation"
RequestExecutionLevel admin
Unicode True
SetCompressor   lzma

; -- Variables -----------------------------------------------------------------
Var MYSQLBIN   ; XAMPP MySQL bin folder (C:\xampp\mysql\bin or C:\xampp\mariadb\bin)
Var UPGRADE    ; 1 = installing over an existing version (keeps settings, license, uploads, database)
Var BACKUPDIR

; -- MUI2 ----------------------------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON   "${PACKAGE_DIR}/app/jig-network.ico"
!define MUI_UNICON "${PACKAGE_DIR}/app/jig-network.ico"

!define MUI_WELCOMEPAGE_TITLE "$(WelcomeTitle)"
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeText)"
!define MUI_LICENSEPAGE_TEXT_TOP "$(LicenseTop)"

; The installer runs as administrator. Starting the system from it directly would
; make the system an administrator process that stop-system, change-port and the
; updater (normal user) cannot stop. explorer.exe starts it as the signed-in user.
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION StartSystemAsUser
!define MUI_FINISHPAGE_RUN_TEXT "$(FinishRun)"
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

; -- Pages ---------------------------------------------------------------------
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "$(InstallerNotes)"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; -- Languages (English first) -------------------------------------------------
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "TradChinese"

LicenseLangString InstallerNotes ${LANG_ENGLISH}     "installer-notes-en.txt"
LicenseLangString InstallerNotes ${LANG_TRADCHINESE} "installer-notes.txt"

LangString WelcomeTitle ${LANG_ENGLISH}     "Welcome to ${PRODUCT_NAME} Setup"
LangString WelcomeTitle ${LANG_TRADCHINESE} "歡迎安裝治具及模具管理系統"
LangString WelcomeText ${LANG_ENGLISH}     "This wizard installs ${PRODUCT_NAME} v${PRODUCT_VER}.$\r$\n$\r$\nBEFORE YOU START$\r$\nRun XAMPP-installer.exe first and keep its folder C:\xampp.$\r$\n$\r$\nThe wizard sets MySQL to start with Windows and creates the database and the desktop shortcut. It takes 1-2 minutes."
LangString WelcomeText ${LANG_TRADCHINESE} "本精靈將引導您完成治具及模具管理系統 v${PRODUCT_VER} 的安裝。$\r$\n$\r$\n【安裝前請先完成】$\r$\n先執行 XAMPP-installer.exe 安裝 XAMPP（安裝路徑保持預設 C:\xampp）。$\r$\n$\r$\n本精靈會自動設定 MySQL 開機自動啟動、建立資料庫與桌面捷徑，約需 1-2 分鐘。"
LangString LicenseTop ${LANG_ENGLISH}     "Please read the installation notes:"
LangString LicenseTop ${LANG_TRADCHINESE} "請閱讀以下安裝說明："
LangString FinishRun ${LANG_ENGLISH}     "Start the system now"
LangString FinishRun ${LANG_TRADCHINESE} "立即啟動治具管理系統"
LangString XamppMissing ${LANG_ENGLISH}     "XAMPP was not found (C:\xampp).$\n$\nPlease run XAMPP-installer.exe first:$\n  - keep the default folder C:\xampp$\n  - only MySQL is needed; you may untick the other components$\n$\nThen run this setup again."
LangString XamppMissing ${LANG_TRADCHINESE} "尚未偵測到 XAMPP（C:\xampp）。$\n$\n請先執行 XAMPP-installer.exe 安裝 XAMPP：$\n  • 安裝路徑保持預設 C:\xampp$\n  • 元件只需要 MySQL，其他可以取消勾選$\n$\n裝好後再重新執行本安裝程式。"
LangString UpgradeFound ${LANG_ENGLISH}     "Version v$1 is already installed in:$\n$0$\n$\nIt will be upgraded to v${PRODUCT_VER} in the same folder.$\nLicense, uploaded files, database, port and settings are kept.$\nA backup is made first in backups\before-setup-v${PRODUCT_VER}.$\n$\nClick OK to upgrade."
LangString UpgradeFound ${LANG_TRADCHINESE} "偵測到已安裝的治具管理系統 v$1$\n位置：$0$\n$\n本次會升級到 v${PRODUCT_VER}，安裝在原本的資料夾。$\n授權、上傳檔案、資料庫資料、port 與設定都會保留，$\n升級前會自動備份到 backups\before-setup-v${PRODUCT_VER}。$\n$\n按「確定」繼續升級。"
LangString DetailUpgrading ${LANG_ENGLISH}     "Existing installation found - upgrading (settings, license, uploads and database are kept)..."
LangString DetailUpgrading ${LANG_TRADCHINESE} "偵測到已安裝的版本，進行升級（保留設定、授權、上傳檔案與資料庫）..."
LangString DetailCopying ${LANG_ENGLISH}     "Copying program files..."
LangString DetailCopying ${LANG_TRADCHINESE} "正在複製系統檔案..."
LangString DetailPermissions ${LANG_ENGLISH}     "Setting folder permissions..."
LangString DetailPermissions ${LANG_TRADCHINESE} "設定資料夾權限..."
LangString DetailCheckMySql ${LANG_ENGLISH}     "Checking MySQL..."
LangString DetailCheckMySql ${LANG_TRADCHINESE} "檢查 MySQL..."
LangString DetailRegisterService ${LANG_ENGLISH}     "Registering MySQL as a Windows service (starts with Windows)..."
LangString DetailRegisterService ${LANG_TRADCHINESE} "將 MySQL 註冊為 Windows 服務（開機自動啟動）..."
LangString DetailStartMySql ${LANG_ENGLISH}     "Starting the MySQL service..."
LangString DetailStartMySql ${LANG_TRADCHINESE} "啟動 MySQL 服務..."
LangString DetailUpgradeDb ${LANG_ENGLISH}     "Upgrading the database and settings..."
LangString DetailUpgradeDb ${LANG_TRADCHINESE} "升級資料庫與設定..."
LangString UpgradeFailed ${LANG_ENGLISH}     "The database or settings upgrade failed (error code: $1).$\n$\nThe previous files and database backup are in:$\n$BACKUPDIR$\n$\nPlease do not start the system yet, and contact aurastudio.studio.service@gmail.com."
LangString UpgradeFailed ${LANG_TRADCHINESE} "資料庫或設定升級失敗（錯誤碼：$1）。$\n$\n舊版的檔案與資料庫備份在：$\n$BACKUPDIR$\n$\n請先不要啟動系統，並聯絡 aurastudio.studio.service@gmail.com。"
LangString DetailCreateDb ${LANG_ENGLISH}     "Creating the database..."
LangString DetailCreateDb ${LANG_TRADCHINESE} "建立資料庫..."
LangString DbFailed ${LANG_ENGLISH}     "Creating the database failed (error code: $0).$\n$\nAfter setup, please run:$\n$INSTDIR\scripts\install-database.bat"
LangString DbFailed ${LANG_TRADCHINESE} "資料庫建立失敗（錯誤碼：$0）。$\n$\n安裝完成後請手動執行：$\n$INSTDIR\scripts\install-database.bat"
LangString MySqlNotStartedUpgrade ${LANG_ENGLISH}     "MySQL did not start, so the database and settings were not upgraded.$\n$\nOpen XAMPP Control Panel, click Start next to MySQL (it turns green),$\nthen run this setup again."
LangString MySqlNotStartedUpgrade ${LANG_TRADCHINESE} "MySQL 沒有啟動成功，資料庫與設定還沒升級。$\n$\n請開啟 XAMPP Control Panel 按 MySQL 的 Start（變綠色），$\n再重新執行一次本安裝程式。"
LangString MySqlNotStarted ${LANG_ENGLISH}     "MySQL did not start. The database was skipped; the rest is installed.$\n$\nAfter setup:$\n1. Open XAMPP Control Panel and click Start next to MySQL (it turns green)$\n2. Run $INSTDIR\scripts\install-database.bat"
LangString MySqlNotStarted ${LANG_TRADCHINESE} "MySQL 沒有啟動成功，資料庫先跳過，其餘繼續安裝。$\n$\n安裝完成後請：$\n1. 開啟 XAMPP Control Panel，按 MySQL 的 Start（變綠色）$\n2. 執行 $INSTDIR\scripts\install-database.bat"
LangString DetailShortcut ${LANG_ENGLISH}     "Creating shortcuts..."
LangString DetailShortcut ${LANG_TRADCHINESE} "建立捷徑..."
LangString StartMenuStart ${LANG_ENGLISH}     "Start System"
LangString StartMenuStart ${LANG_TRADCHINESE} "啟動系統"
LangString StartMenuUninstall ${LANG_ENGLISH}     "Uninstall"
LangString StartMenuUninstall ${LANG_TRADCHINESE} "解除安裝"
LangString Uninstalled ${LANG_ENGLISH}     "${PRODUCT_NAME} has been uninstalled.$\n$\nIf you no longer need MySQL, remove XAMPP in Control Panel > Programs and Features."
LangString Uninstalled ${LANG_TRADCHINESE} "治具管理系統已成功解除安裝。$\n$\n若不再使用 MySQL，請至「控制台 > 新增移除程式」手動移除 XAMPP。"

Function StartSystemAsUser
  Exec '"$WINDIR\explorer.exe" "$INSTDIR\START-JIG-NETWORK-APP.bat"'
FunctionEnd

; -- Pre-check: XAMPP must be installed first (separate installer since 2026-09-27)
Function .onInit
  StrCpy $MYSQLBIN ""
  ${If} ${FileExists} "C:\xampp\mysql\bin\mysql.exe"
    StrCpy $MYSQLBIN "C:\xampp\mysql\bin"
  ${ElseIf} ${FileExists} "C:\xampp\mariadb\bin\mysql.exe"
    StrCpy $MYSQLBIN "C:\xampp\mariadb\bin"
  ${EndIf}
  ${If} $MYSQLBIN == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(XamppMissing)"
    Abort
  ${EndIf}

  ; Already installed: say clearly that this is an upgrade, where, and that data is kept
  ReadRegStr $0 HKLM "${REG_KEY}" "InstallLocation"
  ReadRegStr $1 HKLM "${REG_KEY}" "DisplayVersion"
  ${If} $0 != ""
  ${AndIf} ${FileExists} "$0\app\application.properties"
    MessageBox MB_ICONINFORMATION|MB_OKCANCEL "$(UpgradeFound)" IDOK +2
    Abort
  ${EndIf}
FunctionEnd

; -- Install -------------------------------------------------------------------
Section "Main" SecMain
  SectionIn RO

  ; Step 0: upgrade detection. app\application.properties means an older version
  ; is here: stop the system, back up, and keep the customer's settings file
  ; (File /r overwrites it with the template).
  InitPluginsDir
  StrCpy $UPGRADE 0
  ${If} ${FileExists} "$INSTDIR\app\application.properties"
    StrCpy $UPGRADE 1
    StrCpy $BACKUPDIR "$INSTDIR\backups\before-setup-v${PRODUCT_VER}"
    DetailPrint "$(DetailUpgrading)"
    nsExec::Exec `powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { ($$_.Name -eq 'java.exe' -or $$_.Name -eq 'javaw.exe') -and $$_.CommandLine -like '*jig-management-system.jar*' } | ForEach-Object { Stop-Process -Id $$_.ProcessId -Force }"`
    Pop $1
    Sleep 2000
    CreateDirectory "$BACKUPDIR\app"
    CreateDirectory "$BACKUPDIR\scripts"
    CopyFiles /SILENT "$INSTDIR\app\*.*" "$BACKUPDIR\app"
    CopyFiles /SILENT "$INSTDIR\scripts\*.*" "$BACKUPDIR\scripts"
    CopyFiles /SILENT "$INSTDIR\app\application.properties" "$PLUGINSDIR\old.properties"
  ${EndIf}

  ; Step 1: copy all program files
  DetailPrint "$(DetailCopying)"
  SetOutPath "$INSTDIR"
  File /r "${PACKAGE_DIR}/*"

  ; Let standard users write into the install folder (logs, license, uploads,
  ; backups, settings). Old versions may be in Program Files; fixed on upgrade too.
  ; *S-1-5-32-545 = Users group (SID works on every Windows language)
  DetailPrint "$(DetailPermissions)"
  nsExec::ExecToLog 'icacls "$INSTDIR" /grant *S-1-5-32-545:(OI)(CI)M /T /C /Q'
  Pop $1

  ${If} $UPGRADE == 1
    ; apply-update.ps1 merges the new template; put the customer's settings file back
    CreateDirectory "$PLUGINSDIR\src\app"
    CopyFiles /SILENT "$INSTDIR\app\application.properties" "$PLUGINSDIR\src\app\application.properties"
    CopyFiles /SILENT "$PLUGINSDIR\old.properties" "$INSTDIR\app\application.properties"
  ${EndIf}

  ; Step 2: make sure MySQL runs. Already running (e.g. started in XAMPP Control
  ; Panel): leave it. Otherwise register it as a Windows service and start it.
  DetailPrint "$(DetailCheckMySql)"
  nsExec::Exec 'powershell -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\scripts\jig-db-check.ps1" -PackageDir "$INSTDIR" -MySqlBin "$MYSQLBIN"'
  Pop $0
  ${If} $0 != 0
    nsExec::Exec 'sc query mysql'
    Pop $1
    ${If} $1 != 0
      DetailPrint "$(DetailRegisterService)"
      nsExec::ExecToLog '"$MYSQLBIN\mysqld.exe" --install mysql --defaults-file="$MYSQLBIN\my.ini"'
      Pop $1
      ${If} $1 == 0
        WriteRegDWORD HKLM "${REG_KEY}" "RegisteredMySQLService" 1
      ${EndIf}
    ${EndIf}
    DetailPrint "$(DetailStartMySql)"
    nsExec::ExecToLog 'net start mysql'
    Pop $1
    ${For} $2 1 15
      Sleep 2000
      nsExec::Exec 'powershell -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\scripts\jig-db-check.ps1" -PackageDir "$INSTDIR" -MySqlBin "$MYSQLBIN"'
      Pop $0
      ${If} $0 == 0
        ${ExitFor}
      ${EndIf}
    ${Next}
  ${EndIf}
  WriteRegStr HKLM "${REG_KEY}" "MySQLBin" "$MYSQLBIN"

  ; Step 3: database. New install: create it. Upgrade: back up, merge settings and
  ; apply only new database changes (demo data is not re-run). Skipped if MySQL is down.
  ${If} $0 == 0
  ${AndIf} $UPGRADE == 1
    DetailPrint "$(DetailUpgradeDb)"
    nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\scripts\apply-update.ps1" -Source "$PLUGINSDIR\src" -PackageDir "$INSTDIR" -BackupDir "$BACKUPDIR" -SkipFiles'
    Pop $1
    ${If} $1 != 0
      MessageBox MB_ICONEXCLAMATION|MB_OK "$(UpgradeFailed)"
    ${EndIf}
  ${ElseIf} $0 == 0
    DetailPrint "$(DetailCreateDb)"
    ExecWait '"$INSTDIR\scripts\install-database-silent.bat"' $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION|MB_OK "$(DbFailed)"
    ${EndIf}
  ${ElseIf} $UPGRADE == 1
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(MySqlNotStartedUpgrade)"
  ${Else}
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(MySqlNotStarted)"
  ${EndIf}

  ; Step 4: shortcuts. v1.x shortcuts had a Chinese-only name; remove them so an
  ; upgraded PC does not show two.
  DetailPrint "$(DetailShortcut)"
  Delete "$DESKTOP\${OLD_SHORTCUT_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${OLD_SHORTCUT_NAME}"
  CreateShortcut "$DESKTOP\${SHORTCUT_NAME}.lnk" "$INSTDIR\START-JIG-NETWORK-APP.bat" "" "$INSTDIR\app\jig-network.ico" 0

  ; Step 5: Start menu
  CreateDirectory "$SMPROGRAMS\${SHORTCUT_NAME}"
  CreateShortcut "$SMPROGRAMS\${SHORTCUT_NAME}\$(StartMenuStart).lnk" "$INSTDIR\START-JIG-NETWORK-APP.bat" "" "$INSTDIR\app\jig-network.ico" 0
  CreateShortcut "$SMPROGRAMS\${SHORTCUT_NAME}\$(StartMenuUninstall).lnk" "$INSTDIR\Uninstall.exe"

  ; Step 6: uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Step 7: Add/Remove Programs
  WriteRegStr   HKLM "${REG_KEY}" "DisplayName"     "${PRODUCT_NAME}"
  WriteRegStr   HKLM "${REG_KEY}" "DisplayVersion"  "${PRODUCT_VER}"
  WriteRegStr   HKLM "${REG_KEY}" "Publisher"       "${PRODUCT_PUBLISHER}"
  WriteRegStr   HKLM "${REG_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${REG_KEY}" "DisplayIcon"     "$INSTDIR\app\jig-network.ico"
  WriteRegStr   HKLM "${REG_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${REG_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${REG_KEY}" "NoRepair" 1
SectionEnd

; -- Uninstall -----------------------------------------------------------------
Section "Uninstall"
  ; Remove the MySQL service only if this installer registered it
  ReadRegDWORD $0 HKLM "${REG_KEY}" "RegisteredMySQLService"
  ReadRegStr   $1 HKLM "${REG_KEY}" "MySQLBin"
  ${If} $0 == 1
  ${AndIf} $1 != ""
    nsExec::Exec 'net stop mysql'
    Pop $2
    nsExec::Exec '"$1\mysqld.exe" --remove mysql'
    Pop $2
  ${EndIf}

  ; Remove program files (customer data stays: uploads\ backups\ logs\)
  RMDir /r "$INSTDIR\app"
  RMDir /r "$INSTDIR\runtime"
  RMDir /r "$INSTDIR\scripts"
  RMDir /r "$INSTDIR\database"
  RMDir /r "$INSTDIR\documents"
  RMDir /r "$INSTDIR\license"
  Delete "$INSTDIR\*.bat"
  Delete "$INSTDIR\*.txt"
  Delete "$INSTDIR\*.md"
  Delete "$INSTDIR\XAMPP-installer.exe"   ; installers up to v1.3.0 shipped this file
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  ; Shortcuts (current and v1.x names)
  Delete "$DESKTOP\${SHORTCUT_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${SHORTCUT_NAME}"
  Delete "$DESKTOP\${OLD_SHORTCUT_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${OLD_SHORTCUT_NAME}"

  DeleteRegKey HKLM "${REG_KEY}"

  MessageBox MB_ICONINFORMATION|MB_OK "$(Uninstalled)"
SectionEnd

; ── jig-setup.nsi ─────────────────────────────────────────────────────────────
; 治具及模具管理系統 Windows 安裝精靈
; 編譯方式（macOS）：
;   makensis -DVERSION=1.0.0 \
;            -DPACKAGE_DIR=/path/to/customer-package/windows-network-app \
;            -DOUTFILE=/path/to/dist/JigToolingsSetup-1.0.0.exe \
;            windows/installer/jig-setup.nsi
; ─────────────────────────────────────────────────────────────────────────────

!include "MUI2.nsh"
!include "LogicLib.nsh"

; ── 必要 Define（由 release-windows.sh -D 傳入）────────────────────────────────
; VERSION     : 版本字串，例如 1.0.0
; PACKAGE_DIR : Mac 上已組裝好的 windows-network-app 路徑（source of files）
; OUTFILE     : 輸出 EXE 完整路徑

; ── 產品常數 ──────────────────────────────────────────────────────────────────
!define PRODUCT_NAME    "治具及模具管理系統"
!define PRODUCT_VER     "${VERSION}"
!define PRODUCT_PUBLISHER "JJ Systems"
!define REG_KEY         "Software\Microsoft\Windows\CurrentVersion\Uninstall\JigSystem"

; ── 一般設定 ──────────────────────────────────────────────────────────────────
Name            "${PRODUCT_NAME} v${PRODUCT_VER}"
OutFile         "${OUTFILE}"
; Not under Program Files: the system writes into its own folder (logs, license,
; uploads, backups, settings) and standard users cannot write there.
InstallDir      "C:\JigSystem"
InstallDirRegKey HKLM "${REG_KEY}" "InstallLocation"
RequestExecutionLevel admin
Unicode True
SetCompressor   lzma

; ── 變數 ──────────────────────────────────────────────────────────────────────
Var MYSQLBIN   ; XAMPP 的 MySQL bin 資料夾（C:\xampp\mysql\bin 或 C:\xampp\mariadb\bin）
Var UPGRADE    ; 1 = 安裝在既有版本上（保留設定、授權、上傳檔案與資料庫）
Var BACKUPDIR

; ── MUI2 介面設定 ──────────────────────────────────────────────────────────────
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TITLE "歡迎安裝 ${PRODUCT_NAME}"
!define MUI_WELCOMEPAGE_TEXT "本精靈將引導您完成 ${PRODUCT_NAME} v${PRODUCT_VER} 的安裝。$\r$\n$\r$\n【安裝前請先完成】$\r$\n先執行 XAMPP-installer.exe 安裝 XAMPP（安裝路徑保持預設 C:\xampp）。$\r$\n$\r$\n本精靈會自動設定 MySQL 開機自動啟動、建立資料庫與桌面捷徑，約需 1-2 分鐘。"

!define MUI_LICENSEPAGE_TEXT_TOP "請閱讀以下安裝說明："
!define MUI_LICENSEPAGE_BUTTON "我同意(&A)"

!define MUI_FINISHPAGE_RUN "$INSTDIR\START-JIG-NETWORK-APP.bat"
!define MUI_FINISHPAGE_RUN_TEXT "立即啟動治具管理系統"
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

; ── 精靈頁面 ──────────────────────────────────────────────────────────────────
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "installer-notes.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; ── 語言 ──────────────────────────────────────────────────────────────────────
!insertmacro MUI_LANGUAGE "TradChinese"

; ── 前置檢查：XAMPP 必須先裝好（2026-09-27 起 XAMPP 改成獨立安裝，不再包進本安裝檔）
Function .onInit
  StrCpy $MYSQLBIN ""
  ${If} ${FileExists} "C:\xampp\mysql\bin\mysql.exe"
    StrCpy $MYSQLBIN "C:\xampp\mysql\bin"
  ${ElseIf} ${FileExists} "C:\xampp\mariadb\bin\mysql.exe"
    StrCpy $MYSQLBIN "C:\xampp\mariadb\bin"
  ${EndIf}
  ${If} $MYSQLBIN == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK \
      "尚未偵測到 XAMPP（C:\xampp）。$\n$\n請先執行 XAMPP-installer.exe 安裝 XAMPP：$\n  • 安裝路徑保持預設 C:\xampp$\n  • 元件只需要 MySQL，其他可以取消勾選$\n$\n裝好後再重新執行本安裝程式。"
    Abort
  ${EndIf}

  ; 已安裝過：明確告訴使用者這是升級、裝在哪裡、資料會保留（原本只寫在「顯示細節」裡看不到）
  ReadRegStr $0 HKLM "${REG_KEY}" "InstallLocation"
  ReadRegStr $1 HKLM "${REG_KEY}" "DisplayVersion"
  ${If} $0 != ""
  ${AndIf} ${FileExists} "$0\app\application.properties"
    MessageBox MB_ICONINFORMATION|MB_OKCANCEL \
      "偵測到已安裝的治具管理系統 v$1$\n位置：$0$\n$\n本次會升級到 v${PRODUCT_VER}，安裝在原本的資料夾。$\n授權、上傳檔案、資料庫資料、port 與設定都會保留，$\n升級前會自動備份到 backups\before-setup-v${PRODUCT_VER}。$\n$\n按「確定」繼續升級。" \
      IDOK +2
    Abort
  ${EndIf}
FunctionEnd

; ── 安裝 Section ──────────────────────────────────────────────────────────────
Section "主程式" SecMain
  SectionIn RO

  ; Step 0: 升級偵測。已有 app\application.properties 代表是覆蓋舊版：
  ; 先停系統、備份，並保存客戶的設定檔（File /r 會用範本蓋掉它）
  InitPluginsDir
  StrCpy $UPGRADE 0
  ${If} ${FileExists} "$INSTDIR\app\application.properties"
    StrCpy $UPGRADE 1
    StrCpy $BACKUPDIR "$INSTDIR\backups\before-setup-v${PRODUCT_VER}"
    DetailPrint "偵測到已安裝的版本，進行升級（保留設定、授權、上傳檔案與資料庫）..."
    nsExec::Exec `powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { ($$_.Name -eq 'java.exe' -or $$_.Name -eq 'javaw.exe') -and $$_.CommandLine -like '*jig-management-system.jar*' } | ForEach-Object { Stop-Process -Id $$_.ProcessId -Force }"`
    Pop $1
    Sleep 2000
    CreateDirectory "$BACKUPDIR\app"
    CreateDirectory "$BACKUPDIR\scripts"
    CopyFiles /SILENT "$INSTDIR\app\*.*" "$BACKUPDIR\app"
    CopyFiles /SILENT "$INSTDIR\scripts\*.*" "$BACKUPDIR\scripts"
    CopyFiles /SILENT "$INSTDIR\app\application.properties" "$PLUGINSDIR\old.properties"
  ${EndIf}

  ; Step 1: 解壓縮全部系統檔案
  DetailPrint "正在複製系統檔案..."
  SetOutPath "$INSTDIR"
  File /r "${PACKAGE_DIR}/*"

  ; 讓一般使用者可以寫入安裝資料夾（記錄檔、授權、上傳檔案、備份、設定）。
  ; 舊版可能裝在 Program Files，一般使用者沒有寫入權限，覆蓋升級時一併修正。
  ; *S-1-5-32-545 = Users 群組（用 SID，中文版 Windows 群組名稱不同也適用）
  DetailPrint "設定資料夾權限..."
  nsExec::ExecToLog 'icacls "$INSTDIR" /grant *S-1-5-32-545:(OI)(CI)M /T /C /Q'
  Pop $1

  ${If} $UPGRADE == 1
    ; 新範本交給 apply-update.ps1 合併；客戶原本的設定檔放回去
    CreateDirectory "$PLUGINSDIR\src\app"
    CopyFiles /SILENT "$INSTDIR\app\application.properties" "$PLUGINSDIR\src\app\application.properties"
    CopyFiles /SILENT "$PLUGINSDIR\old.properties" "$INSTDIR\app\application.properties"
  ${EndIf}

  ; Step 2: 確保 MySQL 在跑。已在跑（例如客戶從 XAMPP Control Panel 按過 Start）就不動它；
  ; 沒在跑才註冊成 Windows 服務（開機自動啟動，伺服器不用每次手動按 Start）再啟動。
  DetailPrint "檢查 MySQL..."
  nsExec::Exec '"$MYSQLBIN\mysql.exe" -u root -e "SELECT 1"'
  Pop $0
  ${If} $0 != 0
    nsExec::Exec 'sc query mysql'
    Pop $1
    ${If} $1 != 0
      DetailPrint "將 MySQL 註冊為 Windows 服務（開機自動啟動）..."
      nsExec::ExecToLog '"$MYSQLBIN\mysqld.exe" --install mysql --defaults-file="$MYSQLBIN\my.ini"'
      Pop $1
      ${If} $1 == 0
        WriteRegDWORD HKLM "${REG_KEY}" "RegisteredMySQLService" 1
      ${EndIf}
    ${EndIf}
    DetailPrint "啟動 MySQL 服務..."
    nsExec::ExecToLog 'net start mysql'
    Pop $1
    ${For} $2 1 15
      Sleep 2000
      nsExec::Exec '"$MYSQLBIN\mysql.exe" -u root -e "SELECT 1"'
      Pop $0
      ${If} $0 == 0
        ${ExitFor}
      ${EndIf}
    ${Next}
  ${EndIf}
  WriteRegStr HKLM "${REG_KEY}" "MySQLBin" "$MYSQLBIN"

  ; Step 3: 資料庫。新安裝：建立資料庫。升級：備份資料庫、合併設定、只套用新的
  ; 資料庫變更（不重跑示範資料，避免蓋掉客戶改過的帳號狀態）。MySQL 沒起來就跳過。
  ${If} $0 == 0
  ${AndIf} $UPGRADE == 1
    DetailPrint "升級資料庫與設定..."
    nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\scripts\apply-update.ps1" -Source "$PLUGINSDIR\src" -PackageDir "$INSTDIR" -BackupDir "$BACKUPDIR" -SkipFiles'
    Pop $1
    ${If} $1 != 0
      MessageBox MB_ICONEXCLAMATION|MB_OK \
        "資料庫或設定升級失敗（錯誤碼：$1）。$\n$\n舊版的檔案與資料庫備份在：$\n$BACKUPDIR$\n$\n請先不要啟動系統，並聯絡 gossipred5598@gmail.com。"
    ${EndIf}
  ${ElseIf} $0 == 0
    DetailPrint "建立資料庫..."
    ExecWait '"$INSTDIR\scripts\install-database-silent.bat"' $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION|MB_OK \
        "資料庫建立失敗（錯誤碼：$0）。$\n$\n安裝完成後請手動執行：$\n$INSTDIR\scripts\install-database.bat"
    ${EndIf}
  ${ElseIf} $UPGRADE == 1
    MessageBox MB_ICONEXCLAMATION|MB_OK \
      "MySQL 沒有啟動成功，資料庫與設定還沒升級。$\n$\n請開啟 XAMPP Control Panel 按 MySQL 的 Start（變綠色），$\n再重新執行一次本安裝程式。"
  ${Else}
    MessageBox MB_ICONEXCLAMATION|MB_OK \
      "MySQL 沒有啟動成功，資料庫先跳過，其餘繼續安裝。$\n$\n安裝完成後請：$\n1. 開啟 XAMPP Control Panel，按 MySQL 的 Start（變綠色）$\n2. 執行 $INSTDIR\scripts\install-database.bat"
  ${EndIf}

  ; Step 4: 桌面捷徑
  DetailPrint "建立桌面捷徑..."
  CreateShortcut "$DESKTOP\治具管理系統.lnk" "$INSTDIR\START-JIG-NETWORK-APP.bat"

  ; Step 5: 開始功能表
  CreateDirectory "$SMPROGRAMS\治具管理系統"
  CreateShortcut "$SMPROGRAMS\治具管理系統\啟動系統.lnk"   "$INSTDIR\START-JIG-NETWORK-APP.bat"
  CreateShortcut "$SMPROGRAMS\治具管理系統\解除安裝.lnk"   "$INSTDIR\Uninstall.exe"

  ; Step 6: 寫入解除安裝器
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Step 7: 登錄 Add/Remove Programs
  WriteRegStr   HKLM "${REG_KEY}" "DisplayName"     "${PRODUCT_NAME} v${PRODUCT_VER}"
  WriteRegStr   HKLM "${REG_KEY}" "DisplayVersion"  "${PRODUCT_VER}"
  WriteRegStr   HKLM "${REG_KEY}" "Publisher"       "${PRODUCT_PUBLISHER}"
  WriteRegStr   HKLM "${REG_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${REG_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${REG_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${REG_KEY}" "NoRepair" 1
SectionEnd

; ── 解除安裝 Section ──────────────────────────────────────────────────────────
Section "Uninstall"
  ; 只移除「我們自己註冊」的 MySQL 服務；客戶原本就設好的服務不碰
  ReadRegDWORD $0 HKLM "${REG_KEY}" "RegisteredMySQLService"
  ReadRegStr   $1 HKLM "${REG_KEY}" "MySQLBin"
  ${If} $0 == 1
  ${AndIf} $1 != ""
    nsExec::Exec 'net stop mysql'
    Pop $2
    nsExec::Exec '"$1\mysqld.exe" --remove mysql'
    Pop $2
  ${EndIf}

  ; 刪除程式檔案（保留客戶資料：uploads\ backups\ logs\）
  RMDir /r "$INSTDIR\app"
  RMDir /r "$INSTDIR\runtime"
  RMDir /r "$INSTDIR\scripts"
  RMDir /r "$INSTDIR\database"
  RMDir /r "$INSTDIR\documents"
  RMDir /r "$INSTDIR\license"
  Delete "$INSTDIR\*.bat"
  Delete "$INSTDIR\*.txt"
  Delete "$INSTDIR\XAMPP-installer.exe"   ; v1.3.0 以前的安裝檔會附帶這個檔案
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  ; 移除捷徑
  Delete "$DESKTOP\治具管理系統.lnk"
  RMDir /r "$SMPROGRAMS\治具管理系統"

  ; 移除登錄項目
  DeleteRegKey HKLM "${REG_KEY}"

  MessageBox MB_ICONINFORMATION|MB_OK \
    "治具管理系統已成功解除安裝。$\n$\n若不再使用 MySQL，請至「控制台 > 新增移除程式」手動移除 XAMPP。"
SectionEnd

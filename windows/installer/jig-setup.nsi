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
InstallDir      "$PROGRAMFILES64\JigSystem"
InstallDirRegKey HKLM "${REG_KEY}" "InstallLocation"
RequestExecutionLevel admin
Unicode True
SetCompressor   lzma

; ── 變數 ──────────────────────────────────────────────────────────────────────
Var MYSQLBIN   ; XAMPP 的 MySQL bin 資料夾（C:\xampp\mysql\bin 或 C:\xampp\mariadb\bin）

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
FunctionEnd

; ── 安裝 Section ──────────────────────────────────────────────────────────────
Section "主程式" SecMain
  SectionIn RO

  ; Step 1: 解壓縮全部系統檔案
  DetailPrint "正在複製系統檔案..."
  SetOutPath "$INSTDIR"
  File /r "${PACKAGE_DIR}/*"

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

  ; Step 3: 建立資料庫（MySQL 沒起來就跳過，提示手動補做）
  ${If} $0 == 0
    DetailPrint "建立資料庫..."
    ExecWait '"$INSTDIR\scripts\install-database-silent.bat"' $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION|MB_OK \
        "資料庫建立失敗（錯誤碼：$0）。$\n$\n安裝完成後請手動執行：$\n$INSTDIR\scripts\install-database.bat"
    ${EndIf}
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

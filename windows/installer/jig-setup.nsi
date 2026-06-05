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

; ── MUI2 介面設定 ──────────────────────────────────────────────────────────────
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TITLE "歡迎安裝 ${PRODUCT_NAME}"
!define MUI_WELCOMEPAGE_TEXT "本精靈將引導您完成 ${PRODUCT_NAME} v${PRODUCT_VER} 的安裝。$\r$\n$\r$\n安裝過程將自動設定 MySQL 資料庫並建立系統捷徑，全程約需 3-5 分鐘，請耐心等待。$\r$\n$\r$\n建議關閉其他應用程式後再繼續。"

!define MUI_LICENSEPAGE_TEXT_TOP "請閱讀以下授權與安裝說明："
!define MUI_LICENSEPAGE_BUTTON "我同意(&A)"

!define MUI_FINISHPAGE_RUN "$INSTDIR\START-JIG-NETWORK-APP.bat"
!define MUI_FINISHPAGE_RUN_TEXT "立即啟動治具管理系統"
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

; ── 精靈頁面 ──────────────────────────────────────────────────────────────────
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PACKAGE_DIR}/documents/安裝說明.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; ── 語言 ──────────────────────────────────────────────────────────────────────
!insertmacro MUI_LANGUAGE "TradChinese"

; ── 安裝 Section ──────────────────────────────────────────────────────────────
Section "主程式" SecMain
  SectionIn RO

  ; Step 1: 解壓縮全部系統檔案
  DetailPrint "正在複製系統檔案..."
  SetOutPath "$INSTDIR"
  File /r "${PACKAGE_DIR}/*"

  ; Step 2: 靜默安裝 XAMPP（MySQL）
  DetailPrint "正在安裝 MySQL (XAMPP)，約需 1-2 分鐘，請勿關閉視窗..."
  ExecWait '"$INSTDIR\XAMPP-installer.exe" /S' $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OK \
      "MySQL 安裝失敗（錯誤碼：$0）。$\n$\n安裝完成後請手動執行：$\n$INSTDIR\XAMPP-installer.exe"
  ${EndIf}

  ; Step 3: 等待 MySQL 服務就緒
  DetailPrint "等待 MySQL 服務啟動..."
  Sleep 8000
  ExecWait 'net start mysql' $0
  ${If} $0 != 0
    ExecWait 'net start mariadb' $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION|MB_YESNO \
        "MySQL 服務無法自動啟動。$\n$\n建議：$\n1. 點「否」結束安裝$\n2. 手動開啟 XAMPP Control Panel 啟動 MySQL$\n3. 再重新執行此安裝程式$\n$\n是否仍要繼續安裝？" \
        IDYES +2
      Abort "使用者取消安裝"
    ${EndIf}
  ${EndIf}
  Sleep 3000

  ; Step 4: 建立資料庫
  DetailPrint "建立資料庫..."
  ExecWait '"$INSTDIR\scripts\install-database-silent.bat"' $0
  ${If} $0 != 0
    MessageBox MB_ICONEXCLAMATION|MB_OK \
      "資料庫建立失敗（錯誤碼：$0）。$\n$\n請確認 MySQL 已啟動，再手動執行：$\n$INSTDIR\scripts\install-database.bat"
  ${EndIf}

  ; Step 5: 桌面捷徑
  DetailPrint "建立桌面捷徑..."
  CreateShortcut "$DESKTOP\治具管理系統.lnk" "$INSTDIR\START-JIG-NETWORK-APP.bat"

  ; Step 6: 開始功能表
  CreateDirectory "$SMPROGRAMS\治具管理系統"
  CreateShortcut "$SMPROGRAMS\治具管理系統\啟動系統.lnk"   "$INSTDIR\START-JIG-NETWORK-APP.bat"
  CreateShortcut "$SMPROGRAMS\治具管理系統\解除安裝.lnk"   "$INSTDIR\Uninstall.exe"

  ; Step 7: 寫入解除安裝器
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Step 8: 登錄 Add/Remove Programs
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
  ; 刪除程式檔案（保留客戶資料：uploads\ backups\ logs\）
  RMDir /r "$INSTDIR\app"
  RMDir /r "$INSTDIR\runtime"
  RMDir /r "$INSTDIR\scripts"
  RMDir /r "$INSTDIR\database"
  RMDir /r "$INSTDIR\documents"
  RMDir /r "$INSTDIR\license"
  Delete "$INSTDIR\*.bat"
  Delete "$INSTDIR\*.txt"
  Delete "$INSTDIR\XAMPP-installer.exe"
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

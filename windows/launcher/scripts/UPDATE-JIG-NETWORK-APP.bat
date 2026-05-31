@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."
set "APP_DIR=%PACKAGE_DIR%\app"
set "BACKUP_BASE=%PACKAGE_DIR%\backups"
set "DOWNLOAD_DIR=%TEMP%\jig-update"
set "UPDATE_URL=https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"

echo ============================================================
echo  Jig ^& Toolings Management System - Semi-Automatic Updater
echo ============================================================
echo.

:: -- Phase 0: Read current version --------------------------------
set "CURRENT_VERSION="
for /f "tokens=2 delims==" %%v in ('findstr /r "^app\.version=" "%APP_DIR%\application.properties" 2^>nul') do set "CURRENT_VERSION=%%v"

if "%CURRENT_VERSION%"=="" (
    echo [ERROR] Cannot read current version from:
    echo         %APP_DIR%\application.properties
    echo.
    pause
    exit /b 1
)

echo Installed version : %CURRENT_VERSION%
echo Checking server   : %UPDATE_URL%
echo.

:: -- Phase 0: Fetch latest.json and compare ----------------------
set "LATEST_VERSION="
set "RELEASE_DATE="
set "NOTES_URL="
set "DOWNLOAD_ZIP_URL="

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$info = '%TEMP%\jig-latest-info.txt';" ^
    "try {" ^
    "  $j = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 '%UPDATE_URL%').Content | ConvertFrom-Json;" ^
    "  @(" ^
    "    ('LATEST_VERSION=' + $j.latestVersion)," ^
    "    ('RELEASE_DATE='   + $j.releaseDate)," ^
    "    ('NOTES_URL='      + $j.notesUrl)," ^
    "    ('DOWNLOAD_URL='   + $j.platforms.windows.packageUrl)," ^
    "    ('SHA256='         + $j.platforms.windows.sha256)" ^
    "  ) | Out-File $info -Encoding ascii" ^
    "} catch {" ^
    "  'ERROR=Cannot reach update server. Check internet connection.' | Out-File $info -Encoding ascii" ^
    "}" 2>nul

if not exist "%TEMP%\jig-latest-info.txt" (
    echo [ERROR] Update check failed. No response from server.
    pause
    exit /b 1
)

for /f "tokens=1* delims==" %%k in (%TEMP%\jig-latest-info.txt) do (
    if "%%k"=="ERROR"          ( echo [ERROR] %%l & del "%TEMP%\jig-latest-info.txt" & pause & exit /b 1 )
    if "%%k"=="LATEST_VERSION" ( set "LATEST_VERSION=%%l" )
    if "%%k"=="RELEASE_DATE"   ( set "RELEASE_DATE=%%l" )
    if "%%k"=="NOTES_URL"      ( set "NOTES_URL=%%l" )
    if "%%k"=="DOWNLOAD_URL"   ( set "DOWNLOAD_ZIP_URL=%%l" )
    if "%%k"=="SHA256"         ( set "EXPECTED_SHA256=%%l" )
)
del "%TEMP%\jig-latest-info.txt" >nul 2>&1

if "%LATEST_VERSION%"=="" (
    echo [ERROR] Could not parse version information.
    pause
    exit /b 1
)

if "%CURRENT_VERSION%"=="%LATEST_VERSION%" (
    echo System is up to date.
    echo Installed version: %CURRENT_VERSION%
    echo.
    pause
    exit /b 0
)

:: -- Phase 1: Show update info and confirm -----------------------
echo *** UPDATE AVAILABLE ***
echo.
echo   Installed version : %CURRENT_VERSION%
echo   Latest version    : %LATEST_VERSION%
echo   Release date      : %RELEASE_DATE%
echo   Release notes     : %NOTES_URL%
echo.
echo The following data will be backed up before the update:
echo   license\  uploads\  logs\  app\application.properties
echo.
echo [WARNING] Stop the running system and update the JAR file.
echo           LAN users will be disconnected during the update.
echo.
set /p CONFIRM=Proceed with update? (Y to continue / any other key to cancel):
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo Update cancelled.
    pause
    exit /b 0
)

:: -- Phase 1: Create timestamped backup --------------------------
echo.
for /f "tokens=1-6 delims=/: " %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TIMESTAMP=%%a"
set "BACKUP_DIR=%BACKUP_BASE%\update-backup-%TIMESTAMP%"

echo [1/5] Creating backup in: backups\update-backup-%TIMESTAMP%
if not exist "%BACKUP_BASE%" mkdir "%BACKUP_BASE%"
mkdir "%BACKUP_DIR%"
mkdir "%BACKUP_DIR%\app"

if exist "%PACKAGE_DIR%\license"                 robocopy "%PACKAGE_DIR%\license"  "%BACKUP_DIR%\license"  /E /NP /NFL /NDL /NJH /NJS >nul
if exist "%PACKAGE_DIR%\uploads"                 robocopy "%PACKAGE_DIR%\uploads"  "%BACKUP_DIR%\uploads"  /E /NP /NFL /NDL /NJH /NJS >nul
if exist "%PACKAGE_DIR%\logs"                    robocopy "%PACKAGE_DIR%\logs"     "%BACKUP_DIR%\logs"     /E /NP /NFL /NDL /NJH /NJS >nul
if exist "%APP_DIR%\application.properties"      copy /Y "%APP_DIR%\application.properties" "%BACKUP_DIR%\app\" >nul

echo [1/5] Backup complete.

:: -- Phase 2: Stop running system --------------------------------
echo [2/5] Stopping the running system...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080 ^| findstr LISTENING 2^>nul') do (
    taskkill /PID %%a /F >nul 2>&1
)
timeout /t 2 /nobreak >nul
echo [2/5] System stopped.

:: -- Phase 3: Download and extract new JAR -----------------------
echo [3/5] Downloading new package...
echo        %DOWNLOAD_ZIP_URL%
echo.

if exist "%DOWNLOAD_DIR%" rmdir /s /q "%DOWNLOAD_DIR%"
mkdir "%DOWNLOAD_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "%SCRIPT_DIR%update-download.ps1" ^
    -DownloadUrl "%DOWNLOAD_ZIP_URL%" ^
    -DownloadDir "%DOWNLOAD_DIR%" ^
    -AppDir      "%APP_DIR%" ^
    -ExpectedSha "%EXPECTED_SHA256%"

if errorlevel 1 (
    echo.
    echo [ERROR] Download or extraction failed.
    echo         Your data backup is safe in: %BACKUP_DIR%
    echo         The original JAR has not been replaced.
    echo.
    echo         Restart the system manually with START-JIG-NETWORK-APP.bat
    echo         or restore from backup if needed.
    echo.
    pause
    exit /b 1
)

echo [3/5] New JAR installed.

:: -- Phase 4: Restart system -------------------------------------
echo [4/5] Restarting the system...
start "" "%PACKAGE_DIR%\START-JIG-NETWORK-APP.bat"

:: -- Phase 5: Done ------------------------------------------------
echo [5/5] Update complete.
echo.
echo   Updated from v%CURRENT_VERSION% to v%LATEST_VERSION%
echo   Backup location: backups\update-backup-%TIMESTAMP%
echo.
echo The system is restarting. Please wait for the browser to open.
echo.
pause
exit /b 0

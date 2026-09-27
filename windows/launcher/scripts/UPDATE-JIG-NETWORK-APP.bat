@echo off
:: The update replaces files in scripts\, including this one. cmd reads a batch
:: file line by line while it runs, so run from a temporary copy instead.
if /i not "%~1"=="--run" (
    copy /Y "%~f0" "%TEMP%\jig-updater-run.bat" >nul
    "%TEMP%\jig-updater-run.bat" --run "%~dp0"
    exit /b
)
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~2"
for %%d in ("%SCRIPT_DIR%..") do set "PACKAGE_DIR=%%~fd"
set "APP_DIR=%PACKAGE_DIR%\app"
set "BACKUP_BASE=%PACKAGE_DIR%\backups"
set "DOWNLOAD_DIR=%TEMP%\jig-update"
set "UPDATE_URL=https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"
if defined JIG_UPDATE_URL set "UPDATE_URL=%JIG_UPDATE_URL%"

set "JIG_PORT=8080"
if exist "%SCRIPT_DIR%jig-port.bat" call "%SCRIPT_DIR%jig-port.bat"

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
set "EXPECTED_SHA256="

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

for /f "usebackq tokens=1* delims==" %%k in ("%TEMP%\jig-latest-info.txt") do (
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

powershell -NoProfile -Command "if ([version]'%LATEST_VERSION%' -gt [version]'%CURRENT_VERSION%') { exit 1 } else { exit 0 }" >nul 2>&1
if not errorlevel 1 (
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
echo Before updating, a backup is made of:
echo   database, license\, uploads\, app\ (program + settings), scripts\
echo Your settings (port, database password) are kept.
echo.
echo [WARNING] The system stops during the update.
echo           LAN users will be disconnected for a few minutes.
echo.
set "CONFIRM="
set /p CONFIRM=Proceed with update? (Y to continue / any other key to cancel): 
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo Update cancelled.
    pause
    exit /b 0
)

:: -- Phase 1: Create timestamped backup --------------------------
echo.
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TIMESTAMP=%%t"
set "BACKUP_DIR=%BACKUP_BASE%\update-backup-%TIMESTAMP%"

echo [1/5] Creating backup in: backups\update-backup-%TIMESTAMP%
if not exist "%BACKUP_BASE%" mkdir "%BACKUP_BASE%"
mkdir "%BACKUP_DIR%"

if exist "%PACKAGE_DIR%\license" robocopy "%PACKAGE_DIR%\license" "%BACKUP_DIR%\license" /E /NP /NFL /NDL /NJH /NJS >nul
if exist "%PACKAGE_DIR%\uploads" robocopy "%PACKAGE_DIR%\uploads" "%BACKUP_DIR%\uploads" /E /NP /NFL /NDL /NJH /NJS >nul
if exist "%APP_DIR%"             robocopy "%APP_DIR%"             "%BACKUP_DIR%\app"     /E /NP /NFL /NDL /NJH /NJS >nul
if exist "%SCRIPT_DIR%"          robocopy "%SCRIPT_DIR%."         "%BACKUP_DIR%\scripts" /E /NP /NFL /NDL /NJH /NJS >nul

echo [1/5] Files backed up. (The database is backed up in step 3.)

:: -- Phase 2: Stop running system --------------------------------
set "PORTS=%JIG_PORT%"
set "RUN_PORT="
if exist "%PACKAGE_DIR%\logs\running-port.txt" set /p RUN_PORT=<"%PACKAGE_DIR%\logs\running-port.txt"
if defined RUN_PORT for /f "tokens=1" %%p in ("!RUN_PORT!") do if not "%%p"=="%JIG_PORT%" set "PORTS=%JIG_PORT% %%p"
echo [2/5] Stopping the running system (port %PORTS%)...
for %%p in (%PORTS%) do (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":%%p .*LISTENING" 2^>nul') do (
        tasklist /FI "PID eq %%a" /NH | findstr /i "java.exe javaw.exe" >nul
        if not errorlevel 1 taskkill /PID %%a /F >nul 2>&1
    )
)
timeout /t 3 /nobreak >nul
echo [2/5] System stopped.

:: -- Phase 3: Download, verify and apply the new version ----------
echo [3/5] Downloading and installing v%LATEST_VERSION%...
echo        %DOWNLOAD_ZIP_URL%
echo.

if exist "%DOWNLOAD_DIR%" rmdir /s /q "%DOWNLOAD_DIR%"
mkdir "%DOWNLOAD_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "%SCRIPT_DIR%update-download.ps1" ^
    -DownloadUrl "%DOWNLOAD_ZIP_URL%" ^
    -DownloadDir "%DOWNLOAD_DIR%" ^
    -PackageDir  "%PACKAGE_DIR%" ^
    -BackupDir   "%BACKUP_DIR%" ^
    -ExpectedSha "%EXPECTED_SHA256%"
set "UPDATE_RESULT=%errorlevel%"

if "%UPDATE_RESULT%"=="1" (
    echo.
    echo [ERROR] Download or verification failed. Nothing was changed.
    echo         Start the system again with START-JIG-NETWORK-APP.bat.
    echo.
    pause
    exit /b 1
)
if not "%UPDATE_RESULT%"=="0" (
    echo.
    echo [ERROR] The update stopped part-way. Your backup is in:
    echo         %BACKUP_DIR%
    echo         Please send a screenshot of this window to gossipred5598@gmail.com
    echo         before starting the system again.
    echo.
    pause
    exit /b 1
)

echo [3/5] New version installed.

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

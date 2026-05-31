@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."
set "APP_DIR=%PACKAGE_DIR%\app"
set "UPDATE_URL=https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"

echo ============================================================
echo  Jig ^& Toolings Management System - Update Checker
echo ============================================================
echo.

:: Read installed version from application.properties
set "CURRENT_VERSION="
for /f "tokens=2 delims==" %%v in ('findstr /r "^app\.version=" "%APP_DIR%\application.properties" 2^>nul') do set "CURRENT_VERSION=%%v"

if "%CURRENT_VERSION%"=="" (
    echo [ERROR] Cannot read current version.
    echo Expected file: %APP_DIR%\application.properties
    echo.
    pause
    exit /b 1
)

echo Installed version : %CURRENT_VERSION%
echo Checking server   : %UPDATE_URL%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { $j = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 '%UPDATE_URL%').Content | ConvertFrom-Json; $latest = $j.latestVersion; $current = '%CURRENT_VERSION%'; if ($latest -ne $current) { Write-Host '*** UPDATE AVAILABLE ***'; Write-Host ''; Write-Host ('  Installed version : ' + $current); Write-Host ('  Latest version    : ' + $latest); Write-Host ('  Release date      : ' + $j.releaseDate); Write-Host ('  Release notes     : ' + $j.notesUrl); Write-Host ''; Write-Host 'How to update:'; Write-Host '  1. Open the release notes link above and download the new package.'; Write-Host '  2. Run scripts\stop-system.bat to stop the running system.'; Write-Host '  3. Copy the new app\jig-management-system.jar into this app\ folder.'; Write-Host '  4. Restart with START-JIG-NETWORK-APP.bat.'; Write-Host ''; Write-Host 'Data folders to keep (do NOT delete):'; Write-Host '  license\  uploads\  backups\  logs\  app\application.properties' } else { Write-Host ('System is up to date  (v' + $current + ').') } } catch { Write-Host '[ERROR] Cannot reach update server. Please check your internet connection.' }"

echo.
pause

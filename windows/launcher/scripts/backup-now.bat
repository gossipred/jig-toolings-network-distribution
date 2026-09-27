@echo off
setlocal
:: Runs a full backup (database zip + uploaded files, and the external folder
:: if one is set) through the running system, same as "Back up now" in
:: System Settings. Settings such as the folder are read from there.
set "SCRIPT_DIR=%~dp0"
set "TOKEN_FILE=%SCRIPT_DIR%..\logs\.internal-token"
call "%SCRIPT_DIR%jig-port.bat"

echo ============================================================
echo  Jig ^& Toolings Management System - Back Up Now
echo ============================================================
echo.

if not exist "%TOKEN_FILE%" goto not_running
echo Backing up, please wait...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $t = (Get-Content -Raw '%TOKEN_FILE%').Trim(); $r = Invoke-WebRequest -UseBasicParsing -Method Post -TimeoutSec 900 -Headers @{'X-Jig-Token'=$t} 'http://127.0.0.1:%JIG_PORT%/internal/backup/now'; Write-Host $r.Content.Trim(); if ($r.Content -like 'FAILED*') { exit 2 } } catch { exit 1 }"
if errorlevel 2 goto failed
if errorlevel 1 goto not_running
echo.
echo Backups are in backups\auto (and the external folder, if set).
pause
exit /b 0

:failed
echo.
echo [ERROR] The backup failed. See the message above, or System Settings - Data Backup.
pause
exit /b 1

:not_running
echo [ERROR] The system is not running on port %JIG_PORT%.
echo         Start it with START-JIG-NETWORK-APP.bat, then run this again.
pause
exit /b 1

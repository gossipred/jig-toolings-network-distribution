@echo off
setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."
set "PROPS=%PACKAGE_DIR%\app\application.properties"

echo ============================================================
echo  Jig ^& Toolings Management System - Change Port
echo ============================================================
echo.

if not exist "%PROPS%" (
    echo [ERROR] Settings file not found: %PROPS%
    pause
    exit /b 1
)

call "%SCRIPT_DIR%jig-port.bat"
set "OLD_PORT=%JIG_PORT%"
echo Current port : %OLD_PORT%
echo Recommended  : a number between 8081 and 8099
echo.

set "NEW_PORT="
set /p NEW_PORT=Enter the new port number (press Enter to cancel): 
if not defined NEW_PORT (
    echo Cancelled. Nothing was changed.
    pause
    exit /b 0
)

rem Digits only, no leading zero (cmd treats 0-prefixed numbers as octal).
rem No carets (^) on lines that use !var!: delayed expansion strips them, even inside quotes.
set "BAD="
for /f "delims=0123456789" %%x in ("!NEW_PORT!") do set "BAD=1"
if "!NEW_PORT:~0,1!"=="0" set "BAD=1"
if defined BAD (
    echo [ERROR] "!NEW_PORT!" is not a valid port number. Nothing was changed.
    pause
    exit /b 1
)
rem Digits only from here on, so plain %NP% expansion is safe to use below.
set "NP=!NEW_PORT!"
if !NEW_PORT! LSS 1024 (
    echo [ERROR] Please use a port from 1024 to 65535. Nothing was changed.
    pause
    exit /b 1
)
if !NEW_PORT! GTR 65535 (
    echo [ERROR] Please use a port from 1024 to 65535. Nothing was changed.
    pause
    exit /b 1
)
for %%r in (3306 3307 8443) do (
    if "!NEW_PORT!"=="%%r" (
        echo [ERROR] Port %%r is commonly used by other software ^(for example MySQL^). Please choose another.
        pause
        exit /b 1
    )
)
if "!NEW_PORT!"=="%OLD_PORT%" (
    echo The system already uses port %OLD_PORT%. Nothing was changed.
    pause
    exit /b 0
)

for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":!NEW_PORT! .*LISTENING"') do (
    echo [ERROR] Port !NEW_PORT! is already in use by process ID %%a. Please choose another port.
    pause
    exit /b 1
)

for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "TS=%%t"
copy /Y "%PROPS%" "%PROPS%.bak-%TS%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot write to the app folder, so nothing was changed.
    echo         The system is probably installed under C:\Program Files, where
    echo         standard users cannot change files. Either:
    echo           - install v1.3.1 or later over this installation ^(fixes permissions^), or
    echo           - right-click change-port.bat and choose "Run as administrator".
    pause
    exit /b 1
)
echo [1/3] Backup saved: app\application.properties.bak-%TS%

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p = '%PROPS%'; $t = [IO.File]::ReadAllText($p);" ^
    "if ($t -match '(?m)^[ \t]*server\.port[ \t]*=') { $t = [regex]::Replace($t, '(?m)^[ \t]*server\.port[ \t]*=[^\r\n]*', 'server.port=%NP%') }" ^
    "else { $t = $t.TrimEnd() + [Environment]::NewLine + 'server.port=%NP%' + [Environment]::NewLine };" ^
    "[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding $false))"

call "%SCRIPT_DIR%jig-port.bat"
if not "%JIG_PORT%"=="!NEW_PORT!" (
    echo [ERROR] The settings file could not be updated. Restoring the backup...
    copy /Y "%PROPS%.bak-%TS%" "%PROPS%" >nul 2>&1
    if errorlevel 1 echo [ERROR] Restore failed too. Copy app\application.properties.bak-%TS% back by hand.
    pause
    exit /b 1
)
echo [2/3] Port changed: %OLD_PORT% -^> !NEW_PORT!

echo.
set "FW="
set /p FW=Open Windows Firewall for port !NEW_PORT! now? Other computers need this. (Y/N): 
if /i "!FW!"=="Y" (
    echo       A Windows permission prompt will appear. Please click "Yes".
    powershell -NoProfile -Command "Start-Process -FilePath '%SCRIPT_DIR%open-firewall.bat' -Verb RunAs -Wait" 2>nul
    if errorlevel 1 echo [WARN] Firewall not changed. Run scripts\open-firewall.bat as Administrator later.
) else (
    echo       Skipped. Run scripts\open-firewall.bat as Administrator later if needed.
)

echo.
set "RUNNING_PID="
for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":%OLD_PORT% .*LISTENING"') do (
    tasklist /FI "PID eq %%a" /NH | findstr /i "java.exe javaw.exe" >nul
    if not errorlevel 1 set "RUNNING_PID=%%a"
)
if defined RUNNING_PID (
    set "RS="
    set /p RS=The system is running on the old port %OLD_PORT%. Restart it now on port !NEW_PORT!? (Y/N): 
    if /i "!RS!"=="Y" (
        taskkill /PID !RUNNING_PID! /F >nul
        timeout /t 2 /nobreak >nul
        start "" "%PACKAGE_DIR%\START-JIG-NETWORK-APP.bat"
        echo [3/3] Restarting on port !NEW_PORT!...
    ) else (
        echo [3/3] To restart later: run scripts\stop-system.bat, then START-JIG-NETWORK-APP.bat.
    )
) else (
    echo [3/3] The new port is used the next time you start the system.
)

echo.
echo ============================================================
echo  New address for this PC     : http://localhost:!NEW_PORT!
echo  New address for other PCs   : http://SERVER-IP:!NEW_PORT!
echo  (Run scripts\show-network-address.bat to see SERVER-IP.)
echo  Please update bookmarks on other computers.
echo ============================================================
echo.
pause
exit /b 0

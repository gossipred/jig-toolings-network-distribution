@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
for %%d in ("%SCRIPT_DIR%..") do set "PACKAGE_DIR=%%~fd"
set "APP_DIR=%PACKAGE_DIR%\app"
set "LOG_DIR=%PACKAGE_DIR%\logs"
set "RUNTIME_DIR=%PACKAGE_DIR%\runtime"
set "JAR_FILE=%APP_DIR%\jig-management-system.jar"
call "%SCRIPT_DIR%jig-port.bat"
set "LOCAL_URL=http://localhost:%JIG_PORT%"
set "LOGIN_URL=http://localhost:%JIG_PORT%/login"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo ============================================================
echo  Jig ^& Toolings Management System - Windows Network App
echo ============================================================
echo.

:: -- Update Check -----------------------------------------------
set "UPDATE_URL=https://raw.githubusercontent.com/gossipred/jig-toolings-network-distribution/main/shared/latest.json"
set "CURRENT_VERSION="
for /f "tokens=2 delims==" %%v in ('findstr /r "^app\.version=" "%APP_DIR%\application.properties" 2^>nul') do set "CURRENT_VERSION=%%v"

if not "%CURRENT_VERSION%"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "try { $j = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 '%UPDATE_URL%').Content | ConvertFrom-Json; if ([version]$j.latestVersion -gt [version]'%CURRENT_VERSION%') { Write-Host ''; Write-Host '*** UPDATE AVAILABLE ***'; Write-Host ('  Current : %CURRENT_VERSION%'); Write-Host ('  Latest  : ' + $j.latestVersion); Write-Host ('  Notes   : ' + $j.notesUrl); Write-Host '  Run scripts\UPDATE-JIG-NETWORK-APP.bat to update.'; Write-Host '' } } catch {}" 2>nul
)
:: -----------------------------------------------------------------
echo.

if not exist "%JAR_FILE%" (
    echo [ERROR] Application JAR not found:
    echo %JAR_FILE%
    echo.
    echo Please copy the complete windows-network-app package again.
    pause
    exit /b 1
)

:: Find Java: use bundled runtime first, then system Java.
if exist "%RUNTIME_DIR%\bin\java.exe" (
    set "JAVA_EXE=%RUNTIME_DIR%\bin\java.exe"
    echo [INFO] Using bundled Java runtime.
) else (
    set "JAVA_EXE=java"
    echo [INFO] Bundled Java not found. Using system Java.
    java -version >nul 2>&1
    if errorlevel 1 (
        echo.
        echo [ERROR] Java not found. Please install Java 17 or place the runtime folder.
        pause
        exit /b 1
    )
)

:: Find MySQL client so we can verify the database service before startup.
set "MYSQL_EXE="
if exist "C:\xampp\mysql\bin\mysql.exe"   set "MYSQL_EXE=C:\xampp\mysql\bin\mysql.exe"
if exist "C:\xampp\mariadb\bin\mysql.exe" set "MYSQL_EXE=C:\xampp\mariadb\bin\mysql.exe"

if "%MYSQL_EXE%"=="" (
    where mysql >nul 2>&1
    if not errorlevel 1 set "MYSQL_EXE=mysql"
)

if "%MYSQL_EXE%"=="" (
    echo.
    echo [ERROR] MySQL client not found.
    echo Please install XAMPP first, then start MySQL in XAMPP Control Panel.
    pause
    exit /b 1
)

"%MYSQL_EXE%" -u root -e "SELECT 1" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] MySQL is not responding.
    echo Please open XAMPP Control Panel and click Start on MySQL.
    echo Then run this launcher again.
    pause
    exit /b 1
)

echo [INFO] MySQL is running.
echo.

rem After change-port the system may still run on the previous port. It also keeps
rem logs\jig-system.log open, so a second start could not even write its log.
set "RUN_PORT="
if exist "%LOG_DIR%\running-port.txt" set /p RUN_PORT=<"%LOG_DIR%\running-port.txt"
if defined RUN_PORT if not "%RUN_PORT%"=="%JIG_PORT%" (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":%RUN_PORT% .*LISTENING"') do (
        tasklist /FI "PID eq %%a" /NH | findstr /i "java.exe javaw.exe" >nul
        if not errorlevel 1 (
            echo [INFO] The system is still running on the previous port %RUN_PORT%. Stopping it...
            call "%SCRIPT_DIR%jig-backup-before-stop.bat" %RUN_PORT%
            taskkill /PID %%a /F >nul 2>&1
            timeout /t 3 /nobreak >nul
        )
    )
)

call :check_login
if not errorlevel 1 (
    echo [INFO] The system is already running.
    start %LOCAL_URL%
    echo.
    echo Local URL: %LOCAL_URL%
    echo LAN users can use this PC's IP address with port %JIG_PORT%.
    pause
    exit /b 0
)

for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":%JIG_PORT% .*LISTENING"') do (
    echo.
    echo [ERROR] Port %JIG_PORT% is already in use by process ID %%a, but the login page is not responding.
    echo Run scripts\stop-system.bat first, or close the other program using port %JIG_PORT%.
    echo To use a different port, run scripts\change-port.bat.
    pause
    exit /b 1
)

echo.
echo Starting Jig ^& Toolings Management System...
echo.

rem Remember the port in use, so stop-system still finds the system after the port setting changes.
>"%LOG_DIR%\running-port.txt" echo %JIG_PORT%
cd /d "%APP_DIR%"
start "Jig Toolings System" /min cmd /c ""%JAVA_EXE%" -jar jig-management-system.jar --spring.config.location=file:application.properties > "%LOG_DIR%\jig-system.log" 2>&1"

echo Waiting for the web server to become ready...
echo (The first start can take 1-2 minutes on slower computers.)
echo.

for /l %%i in (1,1,90) do (
    call :check_login
    if not errorlevel 1 goto ready
    timeout /t 1 /nobreak > nul
)

echo.
echo [ERROR] The system did not become ready within 3 minutes.
echo Please check:
echo   1. XAMPP MySQL is running
echo   2. Port %JIG_PORT% is not blocked
echo   3. Log file: %LOG_DIR%\jig-system.log
echo.
pause
exit /b 1

:ready
echo.
echo [OK] The system is ready.
echo Local URL: %LOCAL_URL%
echo.
echo First login: admin / 123456 (change the password right away).
echo A 30-day free trial starts automatically on first launch.
echo.
start %LOCAL_URL%
pause
exit /b 0

:check_login
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 '%LOGIN_URL%'; if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
exit /b %errorlevel%

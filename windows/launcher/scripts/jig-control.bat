@echo off
setlocal
:: Jig System Control: one menu to start, stop or check the system and its MySQL.
:: Start: MySQL (Windows service "mysql", installed by the setup wizard) -> start-system.bat
:: Stop:  stop-system.bat -> MySQL. Service start/stop asks for administrator rights (UAC).
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%jig-port.bat"

echo ============================================================
echo  Jig System Control
echo ============================================================
echo   1. Start
echo   2. Stop
echo   3. Status
echo.
choice /c 123 /n /m "Choose 1, 2 or 3: "
if errorlevel 3 goto status
if errorlevel 2 goto stop

:start
call :mysql_running
if not errorlevel 1 goto start_app
sc query mysql >nul 2>&1
if errorlevel 1 (
    echo [ERROR] MySQL is not running and is not installed as a Windows service.
    echo         Open XAMPP Control Panel and click Start on MySQL.
    pause
    exit /b 1
)
echo Starting MySQL ^(Windows will ask for administrator rights^)...
powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c net start mysql' -Verb RunAs -Wait"
timeout /t 3 /nobreak >nul
call :mysql_running
if errorlevel 1 (
    echo [ERROR] MySQL did not start. Open XAMPP Control Panel and check MySQL.
    pause
    exit /b 1
)
:start_app
call "%SCRIPT_DIR%start-system.bat"
exit /b 0

:stop
call "%SCRIPT_DIR%stop-system.bat"
call :mysql_running
if errorlevel 1 goto status
echo Stopping MySQL ^(Windows will ask for administrator rights^)...
powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c net stop mysql' -Verb RunAs -Wait"
goto status

:status
echo.
call :mysql_running
if errorlevel 1 (echo [  ] MySQL: not running) else (echo [OK] MySQL: running)
netstat -ano | findstr /r /c:":%JIG_PORT% .*LISTENING" >nul
if errorlevel 1 (echo [  ] Jig system: not running) else (echo [OK] Jig system: running)
echo.
echo This computer:  http://localhost:%JIG_PORT%
if defined JIG_HTTPS_PORT echo HTTPS:          https://localhost:%JIG_HTTPS_PORT%
echo Other computers: http://SERVER-IP:%JIG_PORT%  ^(see show-network-address.bat^)
echo.
pause
exit /b 0

:mysql_running
:: errorlevel 0 when the "mysql" service runs or mysqld.exe is running (XAMPP Control Panel).
sc query mysql 2>nul | findstr /c:"RUNNING" >nul && exit /b 0
tasklist /FI "IMAGENAME eq mysqld.exe" /NH | findstr /i "mysqld.exe" >nul && exit /b 0
exit /b 1

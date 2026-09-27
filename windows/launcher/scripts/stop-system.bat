@echo off
setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%jig-port.bat"

rem Also check the port recorded at the last start (it differs after change-port).
set "PORTS=%JIG_PORT%"
set "RUN_PORT="
if exist "%SCRIPT_DIR%..\logs\running-port.txt" set /p RUN_PORT=<"%SCRIPT_DIR%..\logs\running-port.txt"
if defined RUN_PORT for /f "tokens=1" %%p in ("!RUN_PORT!") do if not "%%p"=="%JIG_PORT%" set "PORTS=%JIG_PORT% %%p"

echo Stopping Jig ^& Toolings Management System (port %PORTS%)...
echo.

set "FOUND="
for %%p in (%PORTS%) do (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":%%p .*LISTENING"') do (
        set "FOUND=1"
        rem Only stop the Java process of this system, never another program on the same port.
        tasklist /FI "PID eq %%a" /NH | findstr /i "java.exe javaw.exe" >nul
        if errorlevel 1 (
            echo [WARN] Port %%p is used by process %%a, which is not this system. Not stopped.
        ) else (
            taskkill /PID %%a /F
        )
    )
)
if not defined FOUND echo The system is not running.

echo Done.
pause

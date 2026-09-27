@echo off
setlocal enabledelayedexpansion
:: Restores the database from a backup zip. Pick one from backups\auto, or
:: drag a zip (e.g. from the external drive) onto this file.
set "SCRIPT_DIR=%~dp0"
for %%d in ("%SCRIPT_DIR%..") do set "PACKAGE_DIR=%%~fd"
set "AUTO_DIR=%PACKAGE_DIR%\backups\auto"
call "%SCRIPT_DIR%jig-port.bat"

echo ============================================================
echo  Jig ^& Toolings Management System - Restore Backup
echo ============================================================
echo.

set "ZIP="
if not "%~1"=="" (
    if /i not "%~x1"==".zip" (
        echo [ERROR] "%~nx1" is not a backup zip file.
        pause
        exit /b 1
    )
    set "ZIP=%~f1"
    goto confirm
)

set "COUNT=0"
if exist "%AUTO_DIR%" (
    for /f "delims=" %%f in ('dir /b /o-d "%AUTO_DIR%\jig-backup-*.zip" 2^>nul') do (
        set /a COUNT+=1
        if !COUNT! LEQ 20 (
            set "FILE_!COUNT!=%%f"
            echo   !COUNT!. %%f
        )
    )
)
if "%COUNT%"=="0" (
    echo [ERROR] No backups found in %AUTO_DIR%
    echo         To use a backup from an external drive, drag its zip file onto restore-backup.bat.
    pause
    exit /b 1
)
echo.
set "CHOICE="
set /p CHOICE=Number of the backup to restore (press Enter to cancel): 
if not defined CHOICE (
    echo Cancelled. Nothing was changed.
    pause
    exit /b 0
)
set "PICK="
for /f "delims=0123456789" %%x in ("!CHOICE!") do set "PICK=bad"
rem Digits only by now; the for-variable keeps user input out of %%-expansion.
if not defined PICK for %%n in (!CHOICE!) do if defined FILE_%%n set "PICK=!FILE_%%n!"
if "!PICK!"=="" set "PICK=bad"
if "!PICK!"=="bad" (
    echo [ERROR] "!CHOICE!" is not in the list. Nothing was changed.
    pause
    exit /b 1
)
set "ZIP=%AUTO_DIR%\!PICK!"

:confirm
echo.
echo   Backup to restore: !ZIP!
echo.
echo [WARNING] The CURRENT database will be REPLACED by this backup.
echo           Anything added or changed after the backup is lost.
echo           The current database is saved first to backups\before-restore-*.sql.
echo           The system stops during the restore.
echo.
set "OK="
set /p OK=Type YES (capital letters) to restore: 
if not "!OK!"=="YES" (
    echo Cancelled. Nothing was changed.
    pause
    exit /b 0
)

echo.
echo [1/3] Stopping the system (port %JIG_PORT%)...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr /r /c:":%JIG_PORT% .*LISTENING"') do (
    tasklist /FI "PID eq %%a" /NH | findstr /i "java.exe javaw.exe" >nul
    if not errorlevel 1 taskkill /PID %%a /F >nul 2>&1
)
timeout /t 3 /nobreak >nul

echo [2/3] Restoring the database...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%restore-backup.ps1" -Zip "!ZIP!" -PackageDir "%PACKAGE_DIR%"
if errorlevel 1 (
    echo.
    echo [ERROR] Restore failed. See the message above.
    echo         If the database was already changed, the previous data is in backups\before-restore-*.sql.
    echo         Contact gossipred5598@gmail.com for help.
    pause
    exit /b 1
)

echo [3/3] Done.
echo.
echo [OK] Restore completed.
echo      Start the system with the desktop shortcut or START-JIG-NETWORK-APP.bat,
echo      then sign in and check the data.
pause
exit /b 0

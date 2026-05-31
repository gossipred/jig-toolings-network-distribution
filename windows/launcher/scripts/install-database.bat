@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."
set "DB_NAME=web_fixture_management"

:: Find mysql.exe: prefer XAMPP, fall back to system PATH
set "MYSQL_EXE="
if exist "C:\xampp\mysql\bin\mysql.exe"   set "MYSQL_EXE=C:\xampp\mysql\bin\mysql.exe"
if exist "C:\xampp\mariadb\bin\mysql.exe" set "MYSQL_EXE=C:\xampp\mariadb\bin\mysql.exe"

if "%MYSQL_EXE%"=="" (
    where mysql >nul 2>&1
    if not errorlevel 1 (
        set "MYSQL_EXE=mysql"
    ) else (
        echo.
        echo [ERROR] MySQL not found. Please install XAMPP first, then run this again.
        echo Download: https://www.apachefriends.org/download.html
        echo.
        pause
        exit /b 1
    )
)

echo.
echo Installing database: %DB_NAME%
echo MySQL: %MYSQL_EXE%
echo.
echo NOTE: XAMPP default root password is EMPTY. Just press Enter if asked for a password.
echo.

"%MYSQL_EXE%" -u root < "%PACKAGE_DIR%\database\schema.sql"
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to create database. Is MySQL/MariaDB running in XAMPP Control Panel?
    pause
    exit /b 1
)

"%MYSQL_EXE%" -u root < "%PACKAGE_DIR%\database\seed.sql"
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to insert seed data.
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Database installation completed!
echo  Now run: scripts\start-system.bat
echo ============================================
echo.
pause
exit /b 0

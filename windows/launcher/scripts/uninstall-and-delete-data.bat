@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."
set "DB_NAME=web_fixture_management"

echo DANGER: This will remove the app and local package data.
echo.
echo It will delete:
echo - %PACKAGE_DIR%\app\jig-management-system.jar
echo - %PACKAGE_DIR%\uploads
echo - %PACKAGE_DIR%\backups
echo - %PACKAGE_DIR%\logs
echo.
echo It will also try to drop MySQL database:
echo - %DB_NAME%
echo.
echo Type DELETE to continue.
set /p CONFIRM="Confirm: "
if /i not "%CONFIRM%"=="DELETE" (
  echo Cancelled.
  pause
  exit /b 0
)

call "%SCRIPT_DIR%stop-system.bat"

if exist "%PACKAGE_DIR%\app\jig-management-system.jar" del "%PACKAGE_DIR%\app\jig-management-system.jar"
if exist "%PACKAGE_DIR%\uploads" rmdir /s /q "%PACKAGE_DIR%\uploads"
if exist "%PACKAGE_DIR%\backups" rmdir /s /q "%PACKAGE_DIR%\backups"
if exist "%PACKAGE_DIR%\logs" rmdir /s /q "%PACKAGE_DIR%\logs"

echo Dropping database %DB_NAME%...
mysql -u root -p -e "DROP DATABASE IF EXISTS %DB_NAME%;"
if errorlevel 1 (
  echo Database drop failed. Please check MySQL manually.
) else (
  echo Database dropped.
)

echo.
echo Full uninstall completed.
pause

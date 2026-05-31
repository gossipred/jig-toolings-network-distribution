@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."

echo This will uninstall the Jig & Toolings Management System app files.
echo.
echo Preserved folders:
echo - %PACKAGE_DIR%\database
echo - %PACKAGE_DIR%\uploads
echo - %PACKAGE_DIR%\backups
echo.
echo To delete all data too, use uninstall-and-delete-data.bat instead.
echo.
choice /m "Continue with normal uninstall"
if errorlevel 2 exit /b 0

call "%SCRIPT_DIR%stop-system.bat"

if exist "%PACKAGE_DIR%\app\jig-management-system.jar" del "%PACKAGE_DIR%\app\jig-management-system.jar"
if exist "%PACKAGE_DIR%\logs" rmdir /s /q "%PACKAGE_DIR%\logs"

echo.
echo Normal uninstall completed. Database files, uploads, and backups were preserved.
pause

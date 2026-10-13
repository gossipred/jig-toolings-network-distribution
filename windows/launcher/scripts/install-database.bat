@echo off
setlocal
rem Creates the system's database (first installation) and the dedicated
rem database account jig_app; the settings are switched to jig_app.
set "SCRIPT_DIR=%~dp0"
for %%d in ("%SCRIPT_DIR%..") do set "PACKAGE_DIR=%%~fd"

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%jig-db-install.ps1" -PackageDir "%PACKAGE_DIR%"
if errorlevel 1 (
    echo.
    echo [ERROR] Database installation failed. Is MySQL running in XAMPP Control Panel?
    echo Download XAMPP: https://www.apachefriends.org/download.html
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Database installation completed!
echo  Now run: START-JIG-NETWORK-APP.bat
echo ============================================
echo.
pause
exit /b 0

@echo off
setlocal
rem Called by the setup wizard: same as install-database.bat without pauses.
rem Log: %TEMP%\jig-install.log
set "SCRIPT_DIR=%~dp0"
for %%d in ("%SCRIPT_DIR%..") do set "PACKAGE_DIR=%%~fd"
echo [%DATE% %TIME%] Starting database installation > "%TEMP%\jig-install.log"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%jig-db-install.ps1" -PackageDir "%PACKAGE_DIR%" >> "%TEMP%\jig-install.log" 2>&1
exit /b %errorlevel%

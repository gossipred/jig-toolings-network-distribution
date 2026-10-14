@echo off
setlocal
:: Turns HTTPS on when nobody can log in to the Admin page (v2.0 WP4).
:: Same as System Settings > HTTPS. Restart the system afterwards.
cd /d "%~dp0..\app" || exit /b 1
set "JAVA_EXE=..\runtime\bin\java.exe"
if not exist "%JAVA_EXE%" set "JAVA_EXE=java"
"%JAVA_EXE%" -jar jig-management-system.jar enable-https application.properties
set "RC=%ERRORLEVEL%"
echo.
echo Also run open-firewall.bat as administrator so other computers can reach the HTTPS port.
pause
exit /b %RC%

@echo off
setlocal
:: Turns HTTPS off when the browser cannot open the system any more (v2.0 WP4).
:: Same as System Settings > HTTPS. Restart the system afterwards.
cd /d "%~dp0..\app" || exit /b 1
set "JAVA_EXE=..\runtime\bin\java.exe"
if not exist "%JAVA_EXE%" set "JAVA_EXE=java"
"%JAVA_EXE%" -jar jig-management-system.jar disable-https application.properties
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%

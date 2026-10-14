@echo off
:: Sets JIG_PORT from server.port (default 8080) and JIG_HTTPS_PORT from app.https.* in app\application.properties.
:: Usage from another script (no setlocal here, so the value reaches the caller):
::     call "%~dp0jig-port.bat"
set "JIG_PORT=8080"
set "JIG_PORT_RAW="
set "JIG_PROPS=%~dp0..\app\application.properties"
if not exist "%JIG_PROPS%" exit /b 0
:: JIG_HTTPS_PORT: app.https.port when app.https.enabled=true (default 8443), empty when HTTPS is off.
set "JIG_HTTPS_PORT="
set "JIG_HTTPS_ON="
for /f "tokens=1,* delims==" %%a in ('findstr /r /b /i /c:"app\.https\.enabled *=" "%JIG_PROPS%" 2^>nul') do set "JIG_HTTPS_ON=%%b"
if defined JIG_HTTPS_ON for /f "tokens=1" %%v in ("%JIG_HTTPS_ON%") do set "JIG_HTTPS_ON=%%v"
if /i "%JIG_HTTPS_ON%"=="true" set "JIG_HTTPS_PORT=8443"
if defined JIG_HTTPS_PORT for /f "tokens=1,* delims==" %%a in ('findstr /r /b /c:"app\.https\.port *=" "%JIG_PROPS%" 2^>nul') do for /f "tokens=1" %%p in ("%%b") do echo %%p| findstr /r "^[0-9][0-9]*$" >nul && set "JIG_HTTPS_PORT=%%p"
set "JIG_HTTPS_ON="
for /f "tokens=1,* delims==" %%a in ('findstr /r /b /c:"server\.port *=" "%JIG_PROPS%" 2^>nul') do set "JIG_PORT_RAW=%%b"
if not defined JIG_PORT_RAW exit /b 0
for /f "tokens=1" %%p in ("%JIG_PORT_RAW%") do set "JIG_PORT_RAW=%%p"
echo %JIG_PORT_RAW%| findstr /r "^[0-9][0-9]*$" >nul && set "JIG_PORT=%JIG_PORT_RAW%"
set "JIG_PORT_RAW="
exit /b 0

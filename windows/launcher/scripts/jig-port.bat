@echo off
:: Sets JIG_PORT from server.port in app\application.properties (default 8080).
:: Usage from another script (no setlocal here, so the value reaches the caller):
::     call "%~dp0jig-port.bat"
set "JIG_PORT=8080"
set "JIG_PORT_RAW="
set "JIG_PROPS=%~dp0..\app\application.properties"
if not exist "%JIG_PROPS%" exit /b 0
for /f "tokens=1,* delims==" %%a in ('findstr /r /b /c:"server\.port *=" "%JIG_PROPS%" 2^>nul') do set "JIG_PORT_RAW=%%b"
if not defined JIG_PORT_RAW exit /b 0
for /f "tokens=1" %%p in ("%JIG_PORT_RAW%") do set "JIG_PORT_RAW=%%p"
echo %JIG_PORT_RAW%| findstr /r "^[0-9][0-9]*$" >nul && set "JIG_PORT=%JIG_PORT_RAW%"
set "JIG_PORT_RAW="
exit /b 0

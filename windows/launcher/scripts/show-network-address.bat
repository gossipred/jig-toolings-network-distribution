@echo off
setlocal
call "%~dp0jig-port.bat"
echo Local URL:
echo http://localhost:%JIG_PORT%
echo.
echo LAN addresses on this PC:
echo.
ipconfig | findstr /i "IPv4"
echo.
echo Other users can open:
echo http://SERVER-IP:%JIG_PORT%
echo.
pause

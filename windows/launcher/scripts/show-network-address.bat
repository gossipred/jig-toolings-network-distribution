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
if defined JIG_HTTPS_PORT (
    echo https://SERVER-IP:%JIG_HTTPS_PORT%
    echo http://SERVER-IP:%JIG_PORT% also works and switches to HTTPS.
) else (
    echo http://SERVER-IP:%JIG_PORT%
)
echo.
pause

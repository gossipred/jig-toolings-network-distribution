@echo off
echo Local URL:
echo http://localhost:8080
echo.
echo LAN addresses on this PC:
echo.
ipconfig | findstr /i "IPv4"
echo.
echo Other users can open:
echo http://SERVER-IP:8080
echo.
pause

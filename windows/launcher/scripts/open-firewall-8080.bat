@echo off
echo Opening Windows Firewall port 8080...
echo This script should be run as Administrator.
echo.

netsh advfirewall firewall add rule name="Jig Toolings System 8080" dir=in action=allow protocol=TCP localport=8080

echo.
echo Done.
pause

@echo off
setlocal
call "%~dp0jig-port.bat"
echo Opening Windows Firewall port %JIG_PORT% for Jig ^& Toolings Management System...
echo.

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] This script must be run as Administrator.
    echo         Right-click open-firewall.bat and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

:: Re-running is safe: the rule for this port is replaced, not duplicated.
netsh advfirewall firewall delete rule name="Jig Toolings System %JIG_PORT%" >nul 2>&1
netsh advfirewall firewall add rule name="Jig Toolings System %JIG_PORT%" dir=in action=allow protocol=TCP localport=%JIG_PORT%
if errorlevel 1 (
    echo [ERROR] Could not add the firewall rule.
    pause
    exit /b 1
)

echo.
echo [OK] Other computers can now connect to port %JIG_PORT%.
pause
exit /b 0

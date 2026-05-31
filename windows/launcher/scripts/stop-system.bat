@echo off
echo Stopping Jig & Toolings Management System on port 8080...
echo.

for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8080 ^| findstr LISTENING') do (
    taskkill /PID %%a /F
)

echo Done.
pause

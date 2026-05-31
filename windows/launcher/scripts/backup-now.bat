@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PACKAGE_DIR=%SCRIPT_DIR%.."
set "BACKUP_ROOT=%PACKAGE_DIR%\backups"
set "DB_NAME=web_fixture_management"
set "MYSQLDUMP_EXE=mysqldump"

for /f "tokens=1-4 delims=/ " %%a in ("%date%") do (
    set "DATE_PART=%%a-%%b-%%c"
)
for /f "tokens=1-3 delims=:." %%a in ("%time%") do (
    set "TIME_PART=%%a%%b%%c"
)
set "TIME_PART=%TIME_PART: =0%"
set "BACKUP_DIR=%BACKUP_ROOT%\backup-%DATE_PART%-%TIME_PART%"

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo Creating database backup...
%MYSQLDUMP_EXE% -u root -p %DB_NAME% > "%BACKUP_DIR%\web_fixture_management.sql"
if errorlevel 1 goto error

echo Copying uploaded files...
if exist "%PACKAGE_DIR%\uploads" (
    xcopy "%PACKAGE_DIR%\uploads" "%BACKUP_DIR%\uploads\" /E /I /Y > nul
)

echo.
echo Backup completed:
echo %BACKUP_DIR%
pause
exit /b 0

:error
echo.
echo Backup failed. Check MySQL service, username, password, and mysqldump command.
pause
exit /b 1

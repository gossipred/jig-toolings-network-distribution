@echo off
:: Asks the running system to back up before it is stopped. The system itself
:: decides: it skips when today's backup is done or the option is off.
:: Usage: call "%~dp0jig-backup-before-stop.bat" PORT
set "JIG_TOKEN_FILE=%~dp0..\logs\.internal-token"
if "%~1"=="" exit /b 0
if not exist "%JIG_TOKEN_FILE%" exit /b 0
echo Checking today's backup before stopping (this can take a minute)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $t = (Get-Content -Raw '%JIG_TOKEN_FILE%').Trim(); $r = Invoke-WebRequest -UseBasicParsing -Method Post -TimeoutSec 900 -Headers @{'X-Jig-Token'=$t} 'http://127.0.0.1:%~1/internal/backup/before-stop'; Write-Host ('  ' + $r.Content.Trim()) } catch { Write-Host '  (Backup check skipped: the system did not answer.)' }"
exit /b 0

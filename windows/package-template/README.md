# Windows Package Template

This folder describes the Windows package layout. It intentionally does not store large binaries or private customer data.

Runtime-generated or customer-owned paths:

```text
license/
uploads/
backups/
logs/
app/application.properties
```

These paths must be preserved during updates.

## Maintainer notes (moved from README-FIRST.md, 2026-10-15)

- `START-JIG-NETWORK-APP.bat` calls `scripts\start-system.bat`.
- `start-system.bat` auto-detects bundled `runtime\bin\java.exe` first, falls back to system Java.
- `start-system.bat` checks that MySQL is running before starting Spring Boot.
- `start-system.bat` waits up to 60 seconds for `http://localhost:8080/login` before opening the browser.
- If port `8080` is occupied by a non-responsive process, run `scripts\stop-system.bat` first.
- `install-database.bat` auto-detects XAMPP MySQL (`C:\xampp\mysql\bin\mysql.exe`), falls back to system PATH.
- XAMPP default root password is empty — no password needed during `install-database.bat`.
- License is server-side only: LAN browser clients connect to the licensed server and do not need their own `.lic` files.
- Do not store customer passwords in Git or public documents.
- `runtime\` is gitignored (too large). XAMPP is installed separately from Apache Friends: [xampp-windows-x64-8.2.12-0-VS16-installer.exe](https://sourceforge.net/projects/xampp/files/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe/download) (tested version 8.2.12-0). Do not bundle or upload XAMPP. See `docs/release-checklist-xampp.md`.

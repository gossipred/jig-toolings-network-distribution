# macOS Package Template

This folder describes the future macOS package layout. It intentionally does not store large binaries or private customer data.

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

- `START-JIG-NETWORK-APP.command` calls `scripts/start-system.command`.
- `start-system.command` auto-detects bundled `runtime/bin/java` first, falls back to system Java.
- `start-system.command` checks that MySQL is running (tries `/Applications/XAMPP/bin/mysql`, then `/Applications/XAMPP/xamppfiles/bin/mysql`, then system PATH) before starting Spring Boot.
- `start-system.command` waits up to 60 seconds for `http://localhost:8080/login` before opening the browser.
- If port `8080` is occupied by a non-responsive process, run `scripts/stop-system.command` first.
- Custom JRE was built with `jlink` (no JavaFX needed — this is a browser-based app, unlike `jig-standalone`). Module list verified against the actual jar via a full end-to-end browser test (login, home, `/jigs`, `/admin/settings`) before packaging — see the design doc for the exact `jlink --add-modules` list.
- macOS Application Firewall (if the customer's IT has it enabled) is per-app, not per-port — `open-firewall-8080.command` allows the bundled `java` binary through it via `socketfilterfw`, unlike Windows' port-based `netsh`.
- License is server-side only: LAN browser clients connect to the licensed server and do not need their own `.lic` files.
- Do not store customer passwords in Git or public documents.
- `runtime/` is gitignored (too large); rebuild with `jlink` (see design doc) or copy from a known-good build before packaging.
- `XAMPP-installer.dmg` is gitignored (too large, ~150MB) — bundled instead of asking the customer to download it, matching the Windows package's `XAMPP-installer.exe`. Downloaded from `https://sourceforge.net/projects/xampp/files/XAMPP%20Mac%20OS%20X/8.2.4/xampp-osx-8.2.4-0-installer.dmg` — pinned to **8.2.4** specifically because that's the exact version this dev Mac (and jig.aurastudio.studio's XAMPP install) already runs in production, so the bundled installer is a known-good version, not whatever happens to be "latest" on Apache Friends. Deliberately **not** a full copy of this Mac's `/Applications/XAMPP` (that folder is 26GB and its `var/` directory contains this machine's live MySQL data — bundling it would leak production data to any customer). Update the pinned version+URL here if this Mac's XAMPP is ever upgraded.

## Known limitation from initial build/testing (2026-09-18)

The end-to-end launcher test (`start-system.command`'s cold-start path specifically) was only partially verified on this dev Mac, because port 8080 here is permanently occupied by the live `jig.aurastudio.studio` production server (`com.jj.jig-spring` LaunchAgent). What *was* verified:

- The custom JRE + jar run correctly end-to-end (login, home, `/jigs`, `/admin/settings`) via a manual `java -jar ... --server.port=8090` run and a real browser session.
- `install-database.command`'s SQL logic, run against an isolated `web_fixture_management_mactest` database.
- `update-download.sh`'s full download → checksum → extract → replace flow, tested against a local fake release zip (both success and checksum-mismatch paths).
- `start-system.command`'s MySQL-detection, bundled-runtime-detection, and already-running/port-conflict detection logic (all fired correctly).

What was *not* directly verified on this machine: the literal "nothing is running on 8080, cold-start a fresh process, poll until ready" path, since that would require briefly stopping production. JJ reviewed this gap on 2026-09-18 and decided a second-Mac test is not required — accepted as-is, not an open TODO.

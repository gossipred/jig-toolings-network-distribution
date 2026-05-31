# Windows Network Package

The Windows package starts the Spring Boot network/server version and opens the browser after `/login` is ready.

## Release Package Name

```text
jig-toolings-network-windows-1.0.0.zip
```

## How To Build A Release

Run on Mac from the distribution repo root:

```bash
bash windows/installer/release-windows.sh
```

The script will:
1. Run `mvn package` in the core repo.
2. Assemble the package directory.
3. Sync the latest launcher scripts from `windows/launcher/`.
4. Create `windows/installer/dist/jig-toolings-network-windows-VERSION.zip`.
5. Update `shared/latest.json` and `releases/VERSION/manifest.json` with the real SHA256.

After the build, upload the ZIP to GitHub Releases as `vVERSION` and push the updated manifests.

## Launcher Scripts (`windows/launcher/`)

Canonical copies of the customer-facing BAT/PS1 scripts.
When launcher behaviour changes, update the scripts here **and** in the core repo under `customer-package/windows-network-app/scripts/`.

| Script | Purpose |
| --- | --- |
| `START-JIG-NETWORK-APP.bat` | Root shortcut the customer double-clicks |
| `scripts/start-system.bat` | Startup logic: checks Java, MySQL, port, waits for `/login`, opens browser |
| `scripts/stop-system.bat` | Kills the Java process on port 8080 |
| `scripts/install-database.bat` | First-time DB creation (schema + seed) |
| `scripts/CHECK-UPDATE.bat` | Manual update check with instructions |
| `scripts/UPDATE-JIG-NETWORK-APP.bat` | Semi-automatic updater: backup → stop → download → restart |
| `scripts/update-download.ps1` | Download helper: fetches ZIP, verifies SHA256, replaces JAR |
| `scripts/backup-now.bat` | Manual backup of DB + uploads |
| `scripts/open-firewall-8080.bat` | Opens Windows Firewall port 8080 for LAN access |
| `scripts/show-network-address.bat` | Prints this machine's LAN IP |
| `scripts/uninstall.bat` | Removes app files but keeps data |
| `scripts/uninstall-and-delete-data.bat` | Full uninstall including all customer data |

## Package Contents

```text
jig-toolings-network-windows-VERSION.zip
  安裝說明.txt                   ← Chinese installation guide
  操作說明.txt                   ← Chinese operation guide
  README-FIRST.md
  START-JIG-NETWORK-APP.bat
  XAMPP-installer.exe            ← bundled separately (gitignored, ~150MB)
  app/
    jig-management-system.jar
    application.properties
  database/
    schema.sql
    seed.sql
    migration-*.sql
  documents/
    admin-operation-guide.md
    user-quick-guide.md
    handoff-checklist.md
  license/
    README.md                    ← placeholder, .lic installed after activation
  runtime/                       ← bundled JRE (gitignored, ~200MB)
    bin/java.exe
  scripts/
    install-database.bat
    start-system.bat
    stop-system.bat
    backup-now.bat
    CHECK-UPDATE.bat
    UPDATE-JIG-NETWORK-APP.bat
    update-download.ps1
    open-firewall-8080.bat
    show-network-address.bat
    uninstall.bat
    uninstall-and-delete-data.bat
  uploads/
    jigs/
```

Do not commit generated zip files, bundled runtime folders, XAMPP installer binaries, customer uploads, logs, backups, or `.lic` files to this repository.

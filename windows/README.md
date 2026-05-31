# Windows Network Package

The Windows package starts the Spring Boot network/server version and opens the browser after `/login` is ready.

Expected customer package name:

```text
jig-toolings-network-windows-1.0.0.zip
```

The package may include:

- `START-JIG-NETWORK-APP.bat`
- `scripts/start-system.bat`
- `scripts/install-database.bat`
- `app/jig-management-system.jar`
- `app/application.properties`
- `license/`
- `uploads/jigs/`
- `database/schema.sql`
- `database/seed.sql`
- bundled Java runtime when allowed by package size policy

Do not commit generated zip files, bundled runtime folders, XAMPP installer binaries, customer uploads, logs, backups, or `.lic` files to this repository.

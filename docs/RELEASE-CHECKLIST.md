# Release checklist — network edition

Goal: **every release can be installed with the one-click online update**
(`UPDATE-JIG-NETWORK-APP.bat` / `.command`, v1.3.1 and later). Customers
should never need to reinstall or copy files by hand.

## Keep changes online-updatable

The updater runs `scripts/apply-update.ps1` / `apply-update.sh` **from the new
package**, which:

1. dumps the database to `backups/update-backup-*/`
2. replaces every file in the package except `license/`, `uploads/`, `logs/`,
   `backups/` and `app/application.properties`
3. merges `app/application.properties`: keeps the customer's values, sets the
   new `app.version`, appends keys that are new in this release
4. runs `database/migration-*.sql` files not yet listed in `schema_migrations`

So, for each change:

| Change | How it reaches customers |
|---|---|
| Java code, templates | new jar — automatic |
| Scripts, guides, runtime | new package files — automatic |
| New setting | add it to `customer-package/mysql-windows/app/application.properties` with a safe default — appended automatically |
| Changed default of an existing setting | **not** applied (customer value wins). Handle in code, or document a manual step |
| Database structure | new `data/migration-YYYY-MM-DD-*.sql` (idempotent: `IF NOT EXISTS`) **and** the same change in `data/schema.sql` |
| Updater / apply-update logic | ships in the new package and is used by this very update (apply-update runs from the new package) |
| XAMPP / MySQL upgrade, Windows service, installer registry | **not** online — say so in the release notes with manual steps |

## Before publishing

- [ ] `mvn test` passes
- [ ] Build the test jar outside `target/` (the live jig.aurastudio.studio server runs `target/…jar`); package with `JAR_SOURCE=… SKIP_MAVEN=1`
- [ ] Online update tested from the previous release: Mac with a local fake server (`JIG_UPDATE_URL`), Windows VM likewise (server bound to the vmnet address only — en1 is a public IP)
- [ ] Production DB: apply new migrations to `web_fixture_management` **before** restarting jig.aurastudio.studio on the new jar
- [ ] Release notes start with "how to update" (online steps)

## Publishing order

1. push code (without `shared/latest.json`)
2. `gh release create` with all assets
3. download and compare sha256 with `latest.json`
4. push `shared/latest.json` last (otherwise customers see the update before the files exist)

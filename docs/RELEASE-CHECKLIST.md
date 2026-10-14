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
- Guide headers (INSTALL-GUIDE-*, USER-GUIDE-*) are stamped with the release version automatically by the release scripts; renamed/removed files go in `scripts/obsolete-files.txt`
- [ ] `shared/latest.json.sig` was written by the release script (`tools/sign-latest-json.sh`). After **any** later edit of `latest.json` (by hand or by the other platform's release script), sign again: `bash tools/sign-latest-json.sh shared/latest.json <core repo>`. v2.0+ installations refuse an unsigned or stale `latest.json`.

## Publishing order

1. push code (without `shared/latest.json`)
2. `gh release create` with all assets
3. download and compare sha256 with `latest.json`
4. push `shared/latest.json` **and** `shared/latest.json.sig` last, in the same commit (otherwise customers see the update before the files exist)
5. GitHub caches raw files for about 5 minutes: wait 5 minutes, check that `curl -s <raw latest.json URL>.sig` is the new signature, then announce the release. Until then v2.x systems simply report "up to date".

## After publishing

- [ ] Update the public release history page https://aurastudio.studio/software/updates/ —
      add the version at the top of `NETWORK` in `Claude project/docs/jig-software-page/build_changelog.py`,
      run it and update WordPress page 2651 (steps in that folder's README). Standalone releases go in `STANDALONE`.
- [ ] Restart the live server on the new jar (`launchctl kickstart -k gui/501/com.jj.jig-spring`) so it does not report an update to itself
- [ ] Test machines: after a rollback test, delete the fake `database/migration-*-vmtest-*.sql` files, or the next real update will fail on them

## Update-signing keys

- Main private key: `~/.jig-update-signing/update-signing-private.pem` (never in git). Public keys ship in `app/` and inside the jar; they can never be changed for installed systems.
- Backup private key: offline only — encrypted DMG in iCloud Drive `jig-signing-keys/` and on the backup USB stick (password in Apple's Passwords app). Made by CORE `scripts/backup-signing-keys.sh`.
- Main key lost or leaked: mount the DMG, sign with `JIG_UPDATE_SIGNING_KEY=<mounted>/update-signing/update-signing-backup-private.pem bash tools/sign-latest-json.sh …`, and ship a release whose program carries a new key pair; then create a new backup.

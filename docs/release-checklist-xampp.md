# XAMPP release checklist

Jig releases provide Jig files only. Customers download the pinned, tested
XAMPP version from Apache Friends official SourceForge separately.

## Verified installers (2026-11-05)

| Platform | Official installer | Bytes | SHA-256 |
| --- | --- | --- | --- |
| Windows | [8.2.12-0](https://sourceforge.net/projects/xampp/files/XAMPP%20Windows/8.2.12/xampp-windows-x64-8.2.12-0-VS16-installer.exe/download) | 157583456 | `12e818ce5aec79fe646606df3a80b35da865ec0213646ad7c92044dcfcec7535` |
| macOS | [8.2.4-0](https://sourceforge.net/projects/xampp/files/XAMPP%20Mac%20OS%20X/8.2.4/xampp-osx-8.2.4-0-installer.dmg/download) | 156443914 | `eb9888f2e3b131ae9a5fbec063a6b642a7285e065a8e5f5e97c699b71e2d7ac5` |

Both official downloads matched the local tested installers byte for byte.
Their sizes and SHA-256 also matched GitHub Release v2.0.1 asset metadata.
Do not switch to a latest-version URL. If unavailable, ask customers to email
aurastudio.studio.service@gmail.com for an alternative.

## Before packaging

- [ ] Retain private test/emergency copies outside the repo at
  `~/Documents/Others/AuraStudio備份/xampp-tested/`; verify their SHA-256.
- [ ] Remove third-party installers from package inputs, including nested folders.
  Do not upload `XAMPP-installer*` under any name or embed XAMPP in Jig archives.
- [ ] Run `bash tests/test-xampp-release.sh` and the repository test suite.
- [ ] Check both platform archives contain Jig files and no XAMPP installers.
- [ ] Check the four installation guides and Windows update guide retain the
  pinned official URLs, hashes, and missing-version support instructions.
- [ ] Upload only explicitly selected Jig artifacts after JJ authorizes release.
  Never use an upload wildcard that could include third-party installers.

## After uploading (read-only verification)

Run the following with the actual release tag, then inspect the entire list:

```bash
gh release view v2.0.2 --repo gossipred/jig-toolings-network-distribution \
  --json assets --jq '.assets[] | [.name, .size, .digest] | @tsv'
```

- [ ] Confirm there are no XAMPP assets, including renamed original installers.
- [ ] Download the published Jig archives and inspect their contents.
- [ ] Verify published guides link to the tested official installers.

## Existing assets for JJ to remove when releasing v2.0.2

Deletion requires JJ's `!` execution. Dev must not delete or alter releases.

| Existing tag | Asset | Asset API ID | Bytes |
| --- | --- | --- | --- |
| v2.0.1 | `XAMPP-installer.exe` | 652413495 | 157583456 |
| v2.0.1 | `XAMPP-installer.dmg` | 652413483 | 156443914 |
| v2.0.0 | `XAMPP-installer.exe` | 650067495 | 157583456 |
| v2.0.0 | `XAMPP-installer.dmg` | 650067496 | 156443914 |
| v1.4.3 | `XAMPP-installer.exe` | 596837219 | 157583456 |
| v1.4.3 | `XAMPP-installer.dmg` | 596837227 | 156443914 |
| v1.4.2 | `XAMPP-installer.exe` | 594457180 | 157583456 |
| v1.4.2 | `XAMPP-installer.dmg` | 594457194 | 156443914 |
| v1.4.1 | `XAMPP-installer.exe` | 593977942 | 157583456 |
| v1.4.1 | `XAMPP-installer.dmg` | 593977943 | 156443914 |
| v1.4.0 | `XAMPP-installer.exe` | 592939004 | 157583456 |
| v1.4.0 | `XAMPP-installer.dmg` | 592939002 | 156443914 |
| v1.3.1 | `XAMPP-installer.exe` | 592577395 | 157583456 |
| v1.3.1 | `XAMPP-installer.dmg` | 592577389 | 156443914 |
| v1.3.0 | `XAMPP-installer.exe` | 592412839 | 157583456 |
| v1.3.0 | `XAMPP-installer.dmg` | 592413944 | 156443914 |

The paginated GitHub releases API returned these 16 assets on 2026-11-05.
All Windows assets had the Windows hash above; all macOS assets had the macOS
hash above. Before JJ executes deletion, gm must refresh this inventory and
confirm private backups. Historical release notes are retained as history; they are not current
installation instructions. Verify the asset lists again after removal.

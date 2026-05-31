# Version 1.0.0

Initial network distribution planning release.

Highlights:

- Spring Boot network/server version boundary is separated from distribution tooling.
- Windows and macOS packages share one version metadata model.
- Customer data protection policy is defined.
- First updater direction is semi-automatic, not fully automatic.

Customer data paths are preserved during updates:

- `license/`
- `uploads/`
- `backups/`
- `logs/`
- `app/application.properties`

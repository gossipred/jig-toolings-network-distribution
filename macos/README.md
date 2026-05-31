# macOS Network Package

The macOS package will start the same Spring Boot network/server version and open the browser after `/login` is ready.

Expected customer package name:

```text
jig-toolings-network-macos-1.0.0.zip
```

The package may include:

- `.app` launcher or shell launcher
- bundled Java runtime for macOS when allowed by package size policy
- `app/jig-management-system.jar`
- `app/application.properties`
- `license/`
- `uploads/jigs/`
- database setup guidance for MySQL/MariaDB

macOS packaging must stay separate from Windows packaging. The Spring Boot JAR can be shared, but launchers, runtime folders, installer behavior, and OS helper scripts are platform-specific.

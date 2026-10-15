# Launcher script tests

These tests run the real launcher scripts against a throwaway MariaDB
(127.0.0.1:13306, temporary data folder). They never touch port 3306.

    bash tests/test-mariadb.sh start
    bash tests/macos/test-db-account.sh
    pwsh tests/windows/test-db-account.ps1     # needs PowerShell 7 (brew install powershell)
    bash tests/test-mariadb.sh stop

Override the core repo location with JIG_CORE_REPO=/path/to/core.

Text and packaging checks (no database needed):

    bash tests/test-docs.sh
    bash tests/test-installer.sh   # needs makensis (brew install makensis)
    bash tests/macos/test-app-icon.sh
    bash tests/test-runtimes.sh    # after scripts/build-runtimes.sh in the core repo

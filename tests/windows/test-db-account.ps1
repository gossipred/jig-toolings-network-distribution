# Windows launcher-script tests (v2.0 plan 1). Run on the Mac with PowerShell 7
# against the throwaway MariaDB:  bash tests/test-mariadb.sh start
# Also runs on Windows PowerShell 5.1 (JJ's laptop, Task 13): set JIG_TEST_MYSQL_BIN
# to the XAMPP mysql\bin folder and tunnel 127.0.0.1:13306 to the Mac's test MariaDB.
$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object Text.UTF8Encoding $false   # 5.1 pipes ASCII to mysql otherwise
$PsExe = if ($PSVersionTable.PSEdition -eq "Desktop") { "powershell.exe" } else { "pwsh" }
$Dist = Split-Path (Split-Path $PSScriptRoot)
$Core = if ($env:JIG_CORE_REPO) { $env:JIG_CORE_REPO } else { Join-Path $HOME "Documents/Codex/jig-and-toolings-management-system" }
$CoreDb = Join-Path $Core "customer-package/mac-network-app/database"
$WinScripts = Join-Path $Dist "windows/launcher/scripts"
$Bin = if ($env:JIG_TEST_MYSQL_BIN) { $env:JIG_TEST_MYSQL_BIN } else { "/Applications/XAMPP/xamppfiles/bin" }
$Work = Join-Path ([IO.Path]::GetTempPath()) ("jig-wintest-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Work | Out-Null
$script:Run = 0; $script:Failed = 0

function RootSql([string]$sql) {
    $out = & "$Bin/mysql" --no-defaults -h 127.0.0.1 -P 13306 -u root -N -B -e $sql 2>&1
    return ($out -join "`n").Trim()
}
function RootSqlFile([string]$file) { Get-Content $file -Raw | & "$Bin/mysql" --no-defaults -h 127.0.0.1 -P 13306 -u root }
function Reset-Db {
    RootSql "DROP DATABASE IF EXISTS web_fixture_management; DROP USER IF EXISTS 'jig_app'@'localhost'; DROP USER IF EXISTS 'jig_app'@'127.0.0.1'; DROP USER IF EXISTS 'jig_app'@'::1'; DROP USER IF EXISTS 'custom_user'@'127.0.0.1';" | Out-Null
}
# The database as a v1.4.3 customer has it: schema + seed, every shipped migration recorded.
function Install-V143Db {
    RootSqlFile (Join-Path $CoreDb "schema.sql"); RootSqlFile (Join-Path $CoreDb "seed.sql")
    RootSql "CREATE TABLE web_fixture_management.schema_migrations (filename VARCHAR(255) NOT NULL PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)" | Out-Null
    foreach ($f in Get-ChildItem $CoreDb -Filter "migration-*.sql") { RootSql "INSERT INTO web_fixture_management.schema_migrations (filename) VALUES ('$($f.Name)')" | Out-Null }
}
function New-Install([string]$dir, [string]$user, [string]$pass, [string]$version = "1.4.3") {
    foreach ($sub in "app", "scripts", "database", "logs", "license", "uploads") { New-Item -ItemType Directory -Force -Path (Join-Path $dir $sub) | Out-Null }
    Copy-Item (Join-Path $WinScripts "*") (Join-Path $dir "scripts")
    Copy-Item (Join-Path $CoreDb "*.sql") (Join-Path $dir "database")
    Set-Content (Join-Path $dir "app/jig-management-system.jar") "fake jar"
    @("spring.datasource.url=jdbc:mysql://127.0.0.1:13306/web_fixture_management?useSSL=false",
      "spring.datasource.username=$user", "spring.datasource.password=$pass",
      "app.version=$version", "server.port=18080") | Set-Content (Join-Path $dir "app/application.properties")
}
function PropOf([string]$file, [string]$key) {
    $line = Get-Content $file | Where-Object { $_ -like "$key=*" } | Select-Object -Last 1
    if ($line) { return $line.Substring($key.Length + 1) } else { return "" }
}
function Check($actual, $expected, [string]$label) {
    if ("$actual" -ne "$expected") { throw "$label`n      expected: [$expected]`n      actual:   [$actual]" }
}
function Run-Test([string]$name) {
    $script:Run++
    try { & $name; Write-Host "PASS $name" } catch { $script:Failed++; Write-Host "FAIL $name"; Write-Host "    $_" }
}

. (Join-Path $WinScripts "jig-db.ps1")

function Test-ConfigParsesProps {
    $d = Join-Path $Work "cfg"; New-Install $d "root" ""
    $cfg = Get-JigDbConfig $d $Bin
    Check $cfg.User "root" "user"; Check $cfg.Pass "" "password"; Check $cfg.Name "web_fixture_management" "name"
    Check $cfg.Host "127.0.0.1" "host"; Check $cfg.Port "13306" "port"; Check $cfg.Bin $Bin "bin"
}
function Test-PingRootNoPassword {
    Reset-Db; $d = Join-Path $Work "ping"; New-Install $d "root" ""
    Check (Test-JigDb (Get-JigDbConfig $d $Bin)) $true "ping"
}
function Test-SpecialCharPassword {
    Reset-Db
    RootSql "CREATE DATABASE web_fixture_management; CREATE USER 'custom_user'@'127.0.0.1' IDENTIFIED BY 'p@ss w`$rd`"x'; GRANT ALL PRIVILEGES ON web_fixture_management.* TO 'custom_user'@'127.0.0.1';" | Out-Null
    $d = Join-Path $Work "special"; New-Install $d "custom_user" 'p@ss w$rd"x'
    Check (Test-JigDb (Get-JigDbConfig $d $Bin)) $true "special-character password connects"
}
function Test-NoOptionFileLeft {
    Reset-Db; $d = Join-Path $Work "leak"; New-Install $d "root" "LeakCheckPw42"
    $before = @(Get-ChildItem ([IO.Path]::GetTempPath()) -File | ForEach-Object FullName)
    Test-JigDb (Get-JigDbConfig $d $Bin) | Out-Null   # fails to log in, but must still clean up
    $left = Get-ChildItem ([IO.Path]::GetTempPath()) -File | Where-Object { $before -notcontains $_.FullName } |
        Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match "LeakCheckPw42" }
    Check (@($left).Count) 0 "no temp file with the password left"
}
function Test-InstallAppAccount {
    Reset-Db; Install-V143Db; $d = Join-Path $Work "acct"; New-Install $d "root" ""
    $cfg = Get-JigDbConfig $d $Bin
    $r = Install-JigAppAccount $cfg
    Check $r.Ok $true $r.Message; Check $r.Created $true "created"
    $props = Join-Path $d "app/application.properties"
    Check (PropOf $props "spring.datasource.username") "jig_app" "username"
    Check (PropOf $props "spring.datasource.password").Length 24 "password length"
    Check $cfg.User "root" "cfg unchanged"
    Check (Test-JigDb (Get-JigDbConfig $d $Bin)) $true "jig_app connects"
    Check (RootSql "SELECT COUNT(*) FROM mysql.user WHERE User='jig_app'") "3" "jig_app@localhost, @127.0.0.1 and @::1"
    if ($env:OS -ne "Windows_NT") { Check (Get-Item $props).UnixMode "-rw-------" "settings readable by owner only" }
    else { Check ((Get-Acl $props).AreAccessRulesProtected) $true "settings ACL not inherited" }
}
function Test-NewPasswordNotOnCommandLine {
    if ($env:OS -eq "Windows_NT") { return }   # the stub below is a bash script
    $d = Join-Path $Work "argv"; New-Install $d "root" ""
    $stub = Join-Path $Work "argvbin"; New-Item -ItemType Directory -Force -Path $stub | Out-Null
    Set-Content (Join-Path $stub "mysql") "#!/bin/bash`nprintf '%s\n' `"`$@`" >> `"`$(dirname `"`$0`")/args`"`necho 0"
    chmod +x (Join-Path $stub "mysql")
    $r = Install-JigAppAccount (Get-JigDbConfig $d $stub)
    Check $r.Ok $true $r.Message
    $pw = PropOf (Join-Path $d "app/application.properties") "spring.datasource.password"
    Check $pw.Length 24 "password saved"
    Check ((Get-Content (Join-Path $stub "args") -Raw) -match $pw) $false "new password not in mysql arguments"
}
function Test-InstallKeepsCustomUser {
    Reset-Db; Install-V143Db; $d = Join-Path $Work "keep"; New-Install $d "custom_user" "x"
    $r = Install-JigAppAccount (Get-JigDbConfig $d $Bin)
    Check $r.Ok $true "ok"; Check $r.Created $false "not created"
    Check (RootSql "SELECT COUNT(*) FROM mysql.user WHERE User='jig_app'") "0" "no jig_app"
}
function Test-CheckScriptExitCodes {
    Reset-Db; $d = Join-Path $Work "chk"; New-Install $d "root" ""
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $WinScripts "jig-db-check.ps1") -PackageDir $d -MySqlBin $Bin; Check $LASTEXITCODE 0 "reachable"
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $WinScripts "jig-db-check.ps1") -PackageDir $d -MySqlBin (Join-Path $Work "nope"); Check $LASTEXITCODE 2 "no mysql"
}

function Test-FreshInstallCreatesAppAccount {
    Reset-Db; $d = Join-Path $Work "fresh"; New-Install $d "root" ""
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $d "scripts/jig-db-install.ps1") -PackageDir $d -MySqlBin $Bin | Out-Host
    Check $LASTEXITCODE 0 "exit code"
    Check (PropOf (Join-Path $d "app/application.properties") "spring.datasource.username") "jig_app" "username"
    Check (RootSql "SELECT COUNT(*) FROM web_fixture_management.users") "4" "seed users"
    $migrations = @(Get-ChildItem (Join-Path $d "database") -Filter "migration-*.sql").Count
    Check (RootSql "SELECT COUNT(*) FROM web_fixture_management.schema_migrations") $migrations "migrations recorded"
}

function New-Update([string]$name) {
    $script:Pkg = Join-Path $Work "$name/installed"; $script:Src = Join-Path $Work "$name/new"; $script:Bk = Join-Path $Work "$name/backup"
    New-Install $script:Pkg "root" "" "1.4.3"; New-Install $script:Src "root" "" "2.0.0"
    New-Item -ItemType Directory -Force -Path $script:Bk | Out-Null
    Copy-Item (Join-Path $script:Pkg "app") (Join-Path $script:Bk "app") -Recurse
    Copy-Item (Join-Path $script:Pkg "scripts") (Join-Path $script:Bk "scripts") -Recurse
}
function Test-UpdateSwitchesToAppAccount {
    Reset-Db; Install-V143Db; New-Update "upd"
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Src "scripts/apply-update.ps1") -Source $Src -PackageDir $Pkg -BackupDir $Bk -MySqlBin $Bin | Out-Host
    Check $LASTEXITCODE 0 "exit code"
    $props = Join-Path $Pkg "app/application.properties"
    Check (PropOf $props "spring.datasource.username") "jig_app" "switched"
    Check (PropOf $props "app.version") "2.0.0" "version"
    Check (Test-Path (Join-Path $Bk "database-web_fixture_management.sql")) $true "dump made"
}
function Test-UpdateRollback {
    Reset-Db; Install-V143Db; New-Update "rb"
    Set-Content (Join-Path $Src "database/migration-2099-01-01-broken.sql") "THIS IS NOT SQL;"
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Src "scripts/apply-update.ps1") -Source $Src -PackageDir $Pkg -BackupDir $Bk -MySqlBin $Bin | Out-Host
    Check $LASTEXITCODE 3 "rolled back"
    Check (PropOf (Join-Path $Pkg "app/application.properties") "spring.datasource.username") "root" "settings back to root"
    Check (RootSql "SELECT COUNT(*) FROM mysql.user WHERE User='jig_app'") "0" "jig_app removed"
    Check (RootSql "SELECT COUNT(*) FROM web_fixture_management.users") "4" "data intact"
}
function Test-RestoreUsesSettingsAccount {
    $text = Get-Content (Join-Path $WinScripts "restore-backup.ps1") -Raw
    Check ($text -match 'Get-JigDbConfig') $true "uses jig-db.ps1"
    Check ($text -match 'MYSQL_PWD') $false "no MYSQL_PWD"
}

Run-Test Test-ConfigParsesProps
Run-Test Test-PingRootNoPassword
Run-Test Test-SpecialCharPassword
Run-Test Test-NoOptionFileLeft
Run-Test Test-InstallAppAccount
Run-Test Test-InstallKeepsCustomUser
Run-Test Test-NewPasswordNotOnCommandLine
Run-Test Test-CheckScriptExitCodes

Run-Test Test-FreshInstallCreatesAppAccount

Run-Test Test-UpdateSwitchesToAppAccount
Run-Test Test-UpdateRollback
Run-Test Test-RestoreUsesSettingsAccount

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""; Write-Host "$script:Run tests, $script:Failed failed"
if ($script:Failed -gt 0) { exit 1 }

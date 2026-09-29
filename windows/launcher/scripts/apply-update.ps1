# Installs an extracted release package over an existing installation.
# Runs from the NEW package (called by update-download.ps1, or by the setup
# wizard when installing over an older version).
#   1. Back up the database (mysqldump)
#   2. Replace program files; keep license\, uploads\, logs\, backups\
#   3. Merge app\application.properties: keep the customer's values (port,
#      database password...), take the new app.version, add new settings
#   4. Apply database migrations that have not run yet (schema_migrations)
# If a step after the database backup fails, the previous version is put back
# (app\ and scripts\ from the updater's backup, database from the dump).
# Exit codes: 0 = done, 1 = nothing changed, 2 = failed part-way and could not
# be undone, 3 = failed and the previous version was restored.
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$PackageDir,
    [Parameter(Mandatory)][string]$BackupDir,
    [switch]$SkipFiles,
    [string]$MySqlBin = ""   # override for testing; normally found automatically
)
$ErrorActionPreference = "Stop"
$Utf8 = New-Object Text.UTF8Encoding $false
$PropsPath = [IO.Path]::Combine($PackageDir, "app", "application.properties")
$NewPropsPath = [IO.Path]::Combine($Source, "app", "application.properties")

function Read-Props([string]$path) {
    $map = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*([^#!=\s][^=]*?)\s*=(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() }
    }
    return $map
}

function Find-MySqlBin {
    foreach ($d in @("C:\xampp\mysql\bin", "C:\xampp\mariadb\bin")) {
        if (Test-Path (Join-Path $d "mysql.exe")) { return $d }
    }
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return (Split-Path $cmd.Source) }
    return $null
}

if (-not (Test-Path $PropsPath) -or -not (Test-Path $NewPropsPath)) {
    Write-Host "[ERROR] application.properties not found (installed or new package)."
    exit 1
}

$old = Read-Props $PropsPath
$new = Read-Props $NewPropsPath
$DbUser = if ($old.Contains("spring.datasource.username")) { $old["spring.datasource.username"] } else { "root" }
$DbPass = if ($old.Contains("spring.datasource.password")) { $old["spring.datasource.password"] } else { "" }
$DbName = "web_fixture_management"
if ($old.Contains("spring.datasource.url") -and $old["spring.datasource.url"] -match 'jdbc:mysql://[^/]+/([^?;]+)') { $DbName = $Matches[1] }

if ($MySqlBin -eq "") { $MySqlBin = Find-MySqlBin }
if (-not $MySqlBin) { Write-Host "[ERROR] MySQL (XAMPP) not found."; exit 1 }
$Exe = if (Test-Path (Join-Path $MySqlBin "mysql.exe")) { ".exe" } else { "" }
$MySql = Join-Path $MySqlBin "mysql$Exe"
$MySqlDump = Join-Path $MySqlBin "mysqldump$Exe"
$AuthArgs = @("-u", $DbUser)
if ($DbPass -ne "") { $AuthArgs += "--password=$DbPass" }

function Invoke-MySql([string[]]$extra, [string]$inputFile = $null) {
    $argList = @($AuthArgs + @("--default-character-set=utf8mb4") + $extra) | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $out = [IO.Path]::GetTempFileName(); $err = [IO.Path]::GetTempFileName()
    $p = @{ FilePath = $MySql; ArgumentList = $argList; NoNewWindow = $true; Wait = $true; PassThru = $true
            RedirectStandardOutput = $out; RedirectStandardError = $err }
    if ($inputFile) { $p.RedirectStandardInput = $inputFile }
    $proc = Start-Process @p
    $result = @{ Code = $proc.ExitCode; Out = (Get-Content $out -Raw); Err = (Get-Content $err -Raw) }
    Remove-Item $out, $err -Force -ErrorAction SilentlyContinue
    return $result
}

# -- 1. Database backup (nothing has changed yet, so failing here is safe) --
Write-Host "    Backing up database $DbName..."
$r = Invoke-MySql @("-N", "-B", "-e", "SELECT 1")
if ($r.Code -ne 0) { Write-Host "[ERROR] MySQL is not responding. Start MySQL and run the update again."; Write-Host $r.Err; exit 1 }
$DumpFile = Join-Path $BackupDir "database-$DbName.sql"
$dumpArgs = @($AuthArgs + @("--default-character-set=utf8mb4", "--single-transaction", "--result-file=$DumpFile", $DbName)) | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
$d = Start-Process -FilePath $MySqlDump -ArgumentList $dumpArgs -NoNewWindow -Wait -PassThru
if ($d.ExitCode -ne 0 -or -not (Test-Path $DumpFile)) { Write-Host "[ERROR] Database backup failed. Nothing was changed."; exit 1 }
Write-Host "    Database backup: $DumpFile"

try {
    # -- 2. Program files ------------------------------------------------
    if (-not $SkipFiles) {
        Write-Host "    Replacing program files..."
        $keep = @("license", "uploads", "logs", "backups")
        foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
            if ($keep -contains $item.Name) { continue }
            $dest = Join-Path $PackageDir $item.Name
            if ($item.PSIsContainer) {
                if ($item.Name -eq "runtime" -and (Test-Path $dest)) { Remove-Item $dest -Recurse -Force }
                if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
                foreach ($f in Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File) {
                    $rel = $f.FullName.Substring($item.FullName.Length).TrimStart('\', '/')
                    if ($item.Name -eq "app" -and $rel -eq "application.properties") { continue }
                    $target = Join-Path $dest $rel
                    $dir = Split-Path $target
                    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                    Copy-Item -LiteralPath $f.FullName -Destination $target -Force
                }
            } else {
                Copy-Item -LiteralPath $item.FullName -Destination $dest -Force
            }
        }
    }

    # Files that older versions had but this one replaces (e.g. renamed guides)
    $obsolete = [IO.Path]::Combine($Source, "scripts", "obsolete-files.txt")
    # The setup wizard has already copied the new files (-SkipFiles): use the installed list
    if (-not (Test-Path $obsolete)) { $obsolete = [IO.Path]::Combine($PackageDir, "scripts", "obsolete-files.txt") }
    if (Test-Path $obsolete) {
        foreach ($line in [IO.File]::ReadAllLines($obsolete, [Text.Encoding]::UTF8)) {
            $rel = $line.Trim()
            if ($rel -eq "" -or $rel.StartsWith("#") -or $rel.Contains("..")) { continue }
            $top = $rel.Split("/")[0]
            if (@("license", "uploads", "logs", "backups") -contains $top) { continue }
            $target = Join-Path $PackageDir ($rel -replace "/", [IO.Path]::DirectorySeparatorChar)
            if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
        }
    }

    # -- 3. Settings merge -----------------------------------------------
    Write-Host "    Updating settings (your port and database settings are kept)..."
    $lines = [Collections.Generic.List[string]]::new([IO.File]::ReadAllLines($PropsPath))
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*app\.version\s*=') { $lines[$i] = "app.version=" + $new["app.version"] }
    }
    $added = @()
    foreach ($k in $new.Keys) { if (-not $old.Contains($k)) { $added += "$k=" + $new[$k] } }
    if ($added.Count -gt 0) {
        $lines.Add("")
        $lines.Add("# Added by update to v" + $new["app.version"])
        foreach ($a in $added) { $lines.Add($a) }
    }
    [IO.File]::WriteAllText($PropsPath, ($lines -join "`r`n") + "`r`n", $Utf8)

    # -- 4. Database migrations ------------------------------------------
    $DbDir = Join-Path $PackageDir "database"
    $r = Invoke-MySql @("-N", "-B", "-e", "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DbName' AND table_name='schema_migrations'")
    if ($r.Code -ne 0) { throw "Cannot read the database: $($r.Err)" }
    $hasTable = ("$($r.Out)".Trim() -eq "1")
    $r = Invoke-MySql @("-e", "CREATE TABLE IF NOT EXISTS ``$DbName``.schema_migrations (filename VARCHAR(255) NOT NULL PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)")
    if ($r.Code -ne 0) { throw "Cannot create schema_migrations: $($r.Err)" }
    $files = @(Get-ChildItem -Path $DbDir -Filter "migration-*.sql" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if (-not $hasTable) {
        # First run of this mechanism. Migrations dated up to 2026-05-23 predate
        # every customer package: its schema.sql already contains them.
        foreach ($f in $files) {
            if ($f.Name -match '^migration-(\d{4}-\d{2}-\d{2})' -and $Matches[1] -le "2026-05-23") {
                Invoke-MySql @("-e", "INSERT IGNORE INTO ``$DbName``.schema_migrations (filename) VALUES ('$($f.Name)')") | Out-Null
            }
        }
    }
    $r = Invoke-MySql @("-N", "-B", "-e", "SELECT filename FROM ``$DbName``.schema_migrations")
    $applied = @($r.Out -split "`r?`n" | Where-Object { $_ -ne "" })
    foreach ($f in $files) {
        if ($applied -contains $f.Name) { continue }
        Write-Host "    Applying database change: $($f.Name)"
        $m = Invoke-MySql @($DbName) $f.FullName
        if ($m.Code -ne 0) { throw "Database change $($f.Name) failed: $($m.Err)" }
        Invoke-MySql @("-e", "INSERT INTO ``$DbName``.schema_migrations (filename) VALUES ('$($f.Name)')") | Out-Null
    }
} catch {
    Write-Host "[ERROR] $_"
    Write-Host "    Restoring the previous version..."
    $restored = $true
    try {
        foreach ($name in @("app", "scripts")) {
            $from = Join-Path $BackupDir $name
            if (Test-Path $from) {
                Copy-Item -Path (Join-Path $from "*") -Destination (Join-Path $PackageDir $name) -Recurse -Force
            } else {
                $restored = $false
            }
        }
        $back = Invoke-MySql @($DbName) $DumpFile
        if ($back.Code -ne 0) { throw "Database restore failed: $($back.Err)" }
    } catch {
        Write-Host "[ERROR] Could not restore the previous version: $_"
        $restored = $false
    }
    Write-Host "        Backup of files and database: $BackupDir"
    if ($restored) {
        Write-Host "    Previous version restored."
        exit 3
    }
    exit 2
}

# -- 5. Shortcut icon (cosmetic, best effort: never fails the update) --
# Shortcuts made by older installers show the generic .bat icon. Point the ones
# that start this installation at the app icon shipped in app\.
try {
    $icon = [IO.Path]::Combine($PackageDir, "app", "jig-network.ico")
    $target = [IO.Path]::Combine($PackageDir, "START-JIG-NETWORK-APP.bat")
    if (Test-Path $icon) {
        $shell = New-Object -ComObject WScript.Shell
        $folders = "Desktop", "CommonDesktopDirectory", "Programs", "CommonPrograms" |
            ForEach-Object { [Environment]::GetFolderPath($_) } | Where-Object { $_ -and (Test-Path $_) }
        foreach ($lnk in (Get-ChildItem -Path $folders -Filter *.lnk -Recurse -Depth 1 -ErrorAction SilentlyContinue)) {
            $sc = $shell.CreateShortcut($lnk.FullName)
            if ($sc.TargetPath -ieq $target -and $sc.IconLocation -notlike "*jig-network.ico*") {
                $sc.IconLocation = "$icon,0"
                $sc.Save()
            }
        }
    }
} catch { }

Write-Host "    Now at version $($new['app.version'])."
exit 0

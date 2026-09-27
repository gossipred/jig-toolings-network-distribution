# Restores the SQL dump inside a backup zip into the system's database.
# The current database is saved first to backups\before-restore-<time>.sql.
param(
    [Parameter(Mandatory)][string]$Zip,
    [Parameter(Mandatory)][string]$PackageDir,
    [string]$MySqlBin = ""   # override for testing; normally found automatically
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-Props([string]$path) {
    $map = @{}
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*([^#!=\s][^=]*?)\s*=(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() }
    }
    return $map
}

$props = Read-Props ([IO.Path]::Combine($PackageDir, "app", "application.properties"))
$DbUser = if ($props.ContainsKey("spring.datasource.username")) { $props["spring.datasource.username"] } else { "root" }
$DbPass = if ($props.ContainsKey("spring.datasource.password")) { $props["spring.datasource.password"] } else { "" }
$DbName = "web_fixture_management"
if ($props.ContainsKey("spring.datasource.url") -and $props["spring.datasource.url"] -match 'jdbc:mysql://[^/]+/([^?;]+)') { $DbName = $Matches[1] }

if ($MySqlBin -eq "") {
    foreach ($d in @("C:\xampp\mysql\bin", "C:\xampp\mariadb\bin")) { if (Test-Path (Join-Path $d "mysql.exe")) { $MySqlBin = $d; break } }
}
if ($MySqlBin -eq "") { Write-Host "[ERROR] MySQL (XAMPP) not found."; exit 1 }
$Exe = if (Test-Path (Join-Path $MySqlBin "mysql.exe")) { ".exe" } else { "" }
$MySql = Join-Path $MySqlBin "mysql$Exe"
$MySqlDump = Join-Path $MySqlBin "mysqldump$Exe"
if ($DbPass -ne "") { $env:MYSQL_PWD = $DbPass }

function Run([string]$exe, [string[]]$argList, [string]$stdin = $null) {
    $err = [IO.Path]::GetTempFileName(); $out = [IO.Path]::GetTempFileName()
    $p = @{ FilePath = $exe; ArgumentList = $argList; NoNewWindow = $true; Wait = $true; PassThru = $true
            RedirectStandardError = $err; RedirectStandardOutput = $out }
    if ($stdin) { $p.RedirectStandardInput = $stdin }
    $proc = Start-Process @p
    $msg = Get-Content $err -Raw
    Remove-Item $err, $out -Force -ErrorAction SilentlyContinue
    return @{ Code = $proc.ExitCode; Err = $msg }
}

$check = Run $MySql @("-u", $DbUser, "-e", '"SELECT 1"')
if ($check.Code -ne 0) { Write-Host "[ERROR] MySQL is not responding. Start MySQL and try again."; exit 1 }

# 1. Read the dump from the zip (before touching anything)
$work = Join-Path ([IO.Path]::GetTempPath()) ("jig-restore-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $archive = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $entry = $archive.Entries | Where-Object { $_.Name -like "database-*.sql" } | Select-Object -First 1
        if (-not $entry) { Write-Host "[ERROR] This zip does not contain a database backup (database-*.sql)."; exit 1 }
        $sql = Join-Path $work "restore.sql"
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $sql)
    } finally { $archive.Dispose() }

    # 2. Save the current database first
    $backups = Join-Path $PackageDir "backups"
    if (-not (Test-Path $backups)) { New-Item -ItemType Directory -Path $backups | Out-Null }
    $safety = Join-Path $backups ("before-restore-" + (Get-Date -Format "yyyy-MM-dd_HHmmss") + ".sql")
    $d = Run $MySqlDump @("-u", $DbUser, "--default-character-set=utf8mb4", "--single-transaction", "--result-file=`"$safety`"", $DbName)
    if ($d.Code -ne 0 -or -not (Test-Path $safety)) { Write-Host "[ERROR] Could not save the current database first, so nothing was restored."; Write-Host $d.Err; exit 1 }
    Write-Host "    Current database saved: $safety"

    # 3. Restore
    $r = Run $MySql @("-u", $DbUser, "--default-character-set=utf8mb4", $DbName) $sql
    if ($r.Code -ne 0) { Write-Host "[ERROR] Restore failed: $($r.Err)"; Write-Host "        Previous data: $safety"; exit 1 }
    Write-Host "    Database restored from $([IO.Path]::GetFileName($Zip))"
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0

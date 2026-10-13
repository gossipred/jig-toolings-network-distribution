# Restores the SQL dump inside a backup zip into the system's database.
# The current database is saved first to backups\before-restore-<time>.sql.
param(
    [Parameter(Mandatory)][string]$Zip,
    [Parameter(Mandatory)][string]$PackageDir,
    [string]$MySqlBin = ""   # override for testing; normally found automatically
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

. (Join-Path $PSScriptRoot "jig-db.ps1")
$cfg = Get-JigDbConfig $PackageDir $MySqlBin
if (-not $cfg.Bin) { Write-Host "[ERROR] MySQL (XAMPP) not found."; exit 1 }
$DbName = $cfg.Name
if (-not (Test-JigDb $cfg)) { Write-Host "[ERROR] MySQL is not responding. Start MySQL and try again."; exit 1 }

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
    $d = Invoke-JigMySqlDump $cfg @("--result-file=$safety", $DbName)
    if ($d.Code -ne 0 -or -not (Test-Path $safety)) { Write-Host "[ERROR] Could not save the current database first, so nothing was restored."; Write-Host $d.Err; exit 1 }
    Write-Host "    Current database saved: $safety"

    # 3. Restore
    $r = Invoke-JigMySql $cfg @($DbName) $sql
    if ($r.Code -ne 0) { Write-Host "[ERROR] Restore failed: $($r.Err)"; Write-Host "        Previous data: $safety"; exit 1 }
    Write-Host "    Database restored from $([IO.Path]::GetFileName($Zip))"
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0

# First installation: creates the database from database\schema.sql and
# seed.sql, records the migrations they already contain, then creates the
# dedicated account jig_app and switches the settings to it.
param(
    [Parameter(Mandatory)][string]$PackageDir,
    [string]$MySqlBin = ""
)
. (Join-Path $PSScriptRoot "jig-db.ps1")
$cfg = Get-JigDbConfig $PackageDir $MySqlBin
if (-not $cfg.Bin) { Write-Host "[ERROR] MySQL not found. Please install XAMPP first (C:\xampp)."; exit 1 }
$db = Join-Path $PackageDir "database"

Write-Host "Installing database: $($cfg.Name)"
foreach ($f in @("schema.sql", "seed.sql")) {
    $r = Invoke-JigMySql $cfg @() (Join-Path $db $f)
    if ($r.Code -ne 0) { Write-Host "[ERROR] $f failed. Is MySQL running? $($r.Err)"; exit 1 }
}

# A fresh schema.sql already contains every migration, so record them all as
# applied; the updater then only runs migrations added in later versions.
$r = Invoke-JigMySql $cfg @("-e", "CREATE TABLE IF NOT EXISTS ``$($cfg.Name)``.schema_migrations (filename VARCHAR(255) NOT NULL PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)")
if ($r.Code -ne 0) { Write-Host "[ERROR] Could not create schema_migrations: $($r.Err)"; exit 1 }
foreach ($f in Get-ChildItem -Path $db -Filter "migration-*.sql" -File | Sort-Object Name) {
    Invoke-JigMySql $cfg @("-e", "INSERT IGNORE INTO ``$($cfg.Name)``.schema_migrations (filename) VALUES ('$($f.Name)')") | Out-Null
}

$acct = Install-JigAppAccount $cfg
Write-Host "    $($acct.Message)"
if (-not $acct.Ok) { Write-Host "[ERROR] The database was created, but the dedicated database account could not be set up."; exit 1 }
Write-Host "Database installation completed."
exit 0

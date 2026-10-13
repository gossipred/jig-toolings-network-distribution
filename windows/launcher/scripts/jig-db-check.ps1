# Exit 0 = the database answers with the account in app\application.properties,
# 1 = it does not answer, 2 = no MySQL client found. Used by .bat scripts and
# the setup wizard, which cannot read the settings themselves.
param(
    [Parameter(Mandatory)][string]$PackageDir,
    [string]$MySqlBin = ""
)
. (Join-Path $PSScriptRoot "jig-db.ps1")
$cfg = Get-JigDbConfig $PackageDir $MySqlBin
if (-not $cfg.Bin) { exit 2 }
if (Test-JigDb $cfg) { exit 0 }
exit 1

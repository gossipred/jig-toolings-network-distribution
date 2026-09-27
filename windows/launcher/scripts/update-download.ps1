# Downloads and verifies the new release, then hands over to apply-update.ps1
# from the NEW package, so each release brings its own install logic.
# Exit codes: 0 = done, 1 = failed before anything changed, 2 = failed part-way.
param(
    [Parameter(Mandatory)][string]$DownloadUrl,
    [Parameter(Mandatory)][string]$DownloadDir,
    [Parameter(Mandatory)][string]$PackageDir,
    [Parameter(Mandatory)][string]$BackupDir,
    [string]$ExpectedSha = ""
)

$ZipPath = Join-Path $DownloadDir "jig-update.zip"
$ExtractDir = Join-Path $DownloadDir "extracted"

Write-Host "    Downloading..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 600
} catch {
    Write-Host "[ERROR] Download failed: $_"
    exit 1
}
if (-not (Test-Path $ZipPath)) {
    Write-Host "[ERROR] Downloaded file not found."
    exit 1
}

$PLACEHOLDER = "0000000000000000000000000000000000000000000000000000000000000000"
if ($ExpectedSha -ne "" -and $ExpectedSha -ne $PLACEHOLDER) {
    Write-Host "    Verifying checksum..."
    $actual = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $ExpectedSha.ToLower()) {
        Write-Host "[ERROR] Checksum mismatch. The download may be corrupted."
        Write-Host "        Expected : $ExpectedSha"
        Write-Host "        Actual   : $actual"
        exit 1
    }
    Write-Host "    Checksum OK."
}

Write-Host "    Extracting..."
try {
    if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force
} catch {
    Write-Host "[ERROR] Extraction failed: $_"
    exit 1
}

$Apply = [IO.Path]::Combine($ExtractDir, "scripts", "apply-update.ps1")
if (-not (Test-Path $Apply)) {
    Write-Host "[ERROR] The downloaded package has no scripts\apply-update.ps1."
    exit 1
}

& $Apply -Source $ExtractDir -PackageDir $PackageDir -BackupDir $BackupDir
$code = $LASTEXITCODE

Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
exit $code

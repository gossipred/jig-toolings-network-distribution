param(
    [Parameter(Mandatory)][string]$DownloadUrl,
    [Parameter(Mandatory)][string]$DownloadDir,
    [Parameter(Mandatory)][string]$AppDir,
    [string]$ExpectedSha = ""
)

$ZipPath = Join-Path $DownloadDir "jig-update.zip"
$ExtractDir = Join-Path $DownloadDir "extracted"
$JarName = "jig-management-system.jar"

# ── Download ──────────────────────────────────────────────────
Write-Host "    Downloading..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 120
} catch {
    Write-Host "[ERROR] Download failed: $_"
    exit 1
}

if (-not (Test-Path $ZipPath)) {
    Write-Host "[ERROR] Downloaded file not found."
    exit 1
}

# ── SHA256 Verification ───────────────────────────────────────
$PLACEHOLDER = "0000000000000000000000000000000000000000000000000000000000000000"
if ($ExpectedSha -ne "" -and $ExpectedSha -ne $PLACEHOLDER) {
    Write-Host "    Verifying checksum..."
    $actual = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $ExpectedSha.ToLower()) {
        Write-Host "[ERROR] Checksum mismatch."
        Write-Host "        Expected : $ExpectedSha"
        Write-Host "        Actual   : $actual"
        Write-Host "        The downloaded file may be corrupted or tampered."
        exit 1
    }
    Write-Host "    Checksum OK."
} else {
    Write-Host "    (Checksum verification skipped — no hash provided)"
}

# ── Extract ───────────────────────────────────────────────────
Write-Host "    Extracting..."
try {
    if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force
} catch {
    Write-Host "[ERROR] Extraction failed: $_"
    exit 1
}

# ── Find JAR ─────────────────────────────────────────────────
$JarFile = Get-ChildItem -Path $ExtractDir -Filter $JarName -Recurse | Select-Object -First 1
if (-not $JarFile) {
    Write-Host "[ERROR] $JarName not found inside the downloaded package."
    Write-Host "        Contents of extracted ZIP:"
    Get-ChildItem $ExtractDir -Recurse | ForEach-Object { Write-Host "          $_" }
    exit 1
}

# ── Replace JAR ───────────────────────────────────────────────
$TargetJar = Join-Path $AppDir $JarName
Write-Host "    Replacing: $TargetJar"
try {
    Copy-Item -Path $JarFile.FullName -Destination $TargetJar -Force
} catch {
    Write-Host "[ERROR] Failed to replace JAR: $_"
    Write-Host "        Source : $($JarFile.FullName)"
    Write-Host "        Target : $TargetJar"
    exit 1
}

# ── Cleanup ───────────────────────────────────────────────────
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "    Done."
exit 0

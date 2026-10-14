# v2.0 plan 4: the Windows updater refuses unsigned or wrongly signed update information.
# Mac (PowerShell 7): checks verify-update-signature.ps1.
# Windows PowerShell 5.1 (JJ's laptop): also runs UPDATE-JIG-NETWORK-APP.bat end to end
# with file:// URLs. No database needed.
$ErrorActionPreference = "Stop"
$PsExe = if ($PSVersionTable.PSEdition -eq "Desktop") { "powershell.exe" } else { "pwsh" }
$Dist = Split-Path (Split-Path $PSScriptRoot)
$WinScripts = Join-Path $Dist "windows/launcher/scripts"
$Verify = Join-Path $WinScripts "verify-update-signature.ps1"
$Work = Join-Path ([IO.Path]::GetTempPath()) ("jig-sigtest-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Work | Out-Null
$script:Run = 0; $script:Failed = 0

# Test keys made with .NET, so the laptop needs no openssl. 2048 bits: size does not matter here.
$Keys = @{}
foreach ($k in "primary", "backup", "stranger") { $Keys[$k] = New-Object System.Security.Cryptography.RSACryptoServiceProvider 2048 }

function Check($actual, $expected, [string]$label) {
    if ("$actual" -ne "$expected") { throw "$label`n      expected: [$expected]`n      actual:   [$actual]" }
}
function Run-Test([string]$name) {
    $script:Run++
    try { & $name; Write-Host "PASS $name" } catch { $script:Failed++; Write-Host "FAIL $name"; Write-Host "    $_" }
}
function New-App([string]$dir, [bool]$withKeys = $true) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ($withKeys) {
        [IO.File]::WriteAllText((Join-Path $dir "update-signing-public.xml"), $Keys["primary"].ToXmlString($false))
        [IO.File]::WriteAllText((Join-Path $dir "update-signing-backup-public.xml"), $Keys["backup"].ToXmlString($false))
    }
}
# New-Served <dir> <version> <primary|backup|stranger|none>: latest.json (+ .sig) in <dir>
function New-Served([string]$dir, [string]$version, [string]$signer) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $json = "{`n  `"latestVersion`": `"$version`",`n  `"platforms`": {`"windows`": {`"packageUrl`": `"file:///nonexistent.zip`", `"sha256`": `"`"}},`n  `"notesUrl`": `"https://example.invalid/notes`"`n}`n"
    $bytes = (New-Object Text.UTF8Encoding $false).GetBytes($json)
    [IO.File]::WriteAllBytes((Join-Path $dir "latest.json"), $bytes)
    $sigFile = Join-Path $dir "latest.json.sig"
    if (Test-Path $sigFile) { Remove-Item $sigFile }
    if ($signer -ne "none") {
        [IO.File]::WriteAllText($sigFile, [Convert]::ToBase64String($Keys[$signer].SignData($bytes, "SHA256")))
    }
}
function Verify-Code([string]$served, [string]$app) {
    & $PsExe -NoProfile -ExecutionPolicy Bypass -File $Verify -Json (Join-Path $served "latest.json") `
        -Sig (Join-Path $served "latest.json.sig") -AppDir $app | Out-Null
    return $LASTEXITCODE
}

function Test-MainKeyIsAccepted {
    $d = Join-Path $Work "main"; New-App "$d/app"; New-Served "$d/srv" "2.0.0" "primary"
    Check (Verify-Code "$d/srv" "$d/app") 0 "exit code"
}
function Test-BackupKeyIsAccepted {
    $d = Join-Path $Work "backup"; New-App "$d/app"; New-Served "$d/srv" "2.0.0" "backup"
    Check (Verify-Code "$d/srv" "$d/app") 0 "exit code"
}
function Test-SignatureWithLineBreakIsAccepted {
    $d = Join-Path $Work "newline"; New-App "$d/app"; New-Served "$d/srv" "2.0.0" "primary"
    [IO.File]::AppendAllText((Join-Path "$d/srv" "latest.json.sig"), "`r`n")
    Check (Verify-Code "$d/srv" "$d/app") 0 "exit code"
}
function Test-UnknownKeyIsRejected {
    $d = Join-Path $Work "stranger"; New-App "$d/app"; New-Served "$d/srv" "2.0.0" "stranger"
    Check (Verify-Code "$d/srv" "$d/app") 1 "exit code"
}
function Test-ChangedAfterSigningIsRejected {
    $d = Join-Path $Work "changed"; New-App "$d/app"; New-Served "$d/srv" "2.0.0" "primary"
    $sig = [IO.File]::ReadAllText((Join-Path "$d/srv" "latest.json.sig"))
    New-Served "$d/srv" "9.9.9" "none"
    [IO.File]::WriteAllText((Join-Path "$d/srv" "latest.json.sig"), $sig)
    Check (Verify-Code "$d/srv" "$d/app") 1 "exit code"
}
function Test-MissingSignatureIsRejected {
    $d = Join-Path $Work "unsigned"; New-App "$d/app"; New-Served "$d/srv" "2.0.0" "none"
    Check (Verify-Code "$d/srv" "$d/app") 1 "exit code"
}
function Test-AppWithoutKeysIsRejected {
    $d = Join-Path $Work "nokeys"; New-App "$d/app" $false; New-Served "$d/srv" "2.0.0" "primary"
    Check (Verify-Code "$d/srv" "$d/app") 1 "exit code"
}

# --- Windows PowerShell 5.1 only: the real .bat, end to end ---
# Both cases serve the installed version 1.4.3, so the .bat can never reach backup / stop-system.
# New-BatInstall <dir>: version 1.4.3 installation with the test keys and the current scripts (CRLF, like a release).
function New-BatInstall([string]$dir) {
    foreach ($sub in "app", "scripts", "logs") { New-Item -ItemType Directory -Force -Path (Join-Path $dir $sub) | Out-Null }
    Copy-Item (Join-Path $WinScripts "*") (Join-Path $dir "scripts")
    foreach ($f in Get-ChildItem (Join-Path $dir "scripts") -Filter "*.bat") {
        $text = [IO.File]::ReadAllText($f.FullName) -replace "`r?`n", "`r`n"
        [IO.File]::WriteAllText($f.FullName, $text, [Text.Encoding]::ASCII)
    }
    New-App (Join-Path $dir "app")
    @("app.version=1.4.3", "server.port=18080") | Set-Content (Join-Path $dir "app/application.properties")
}
function Run-Bat([string]$install, [string]$served) {
    $env:JIG_UPDATE_URL = ([Uri](Join-Path $served "latest.json")).AbsoluteUri
    try { return (& cmd.exe /c "$install\scripts\UPDATE-JIG-NETWORK-APP.bat" --auto 2>&1 | Out-String) }
    finally { Remove-Item Env:JIG_UPDATE_URL }
}
function Test-BatAcceptsSignedSameVersion {
    $d = Join-Path $Work "bat-ok"; New-BatInstall "$d\inst"; New-Served "$d\srv" "1.4.3" "primary"
    $out = Run-Bat "$d\inst" "$d\srv"
    if ($out -notmatch "System is up to date") { throw "no 'up to date' message:`n$out" }
    Check (Test-Path "$d\inst\logs\last-update.txt") $false "last-update.txt written"
}
function Test-BatRejectsUnknownKey {
    $d = Join-Path $Work "bat-bad"; New-BatInstall "$d\inst"; New-Served "$d\srv" "1.4.3" "stranger"
    $out = Run-Bat "$d\inst" "$d\srv"
    if ($out -notmatch "invalid signature") { throw "no signature message:`n$out" }
    $line = Get-Content "$d\inst\logs\last-update.txt" -TotalCount 1
    Check (($line -split ";")[0..2] -join ";") "FAILED_NOCHANGE;1.4.3;" "result line"
    if ($line -notmatch "aurastudio\.studio\.service@gmail\.com") { throw "no support address: $line" }
    Check (Test-Path "$d\inst\backups") $false "backup started"
}

Run-Test Test-MainKeyIsAccepted
Run-Test Test-BackupKeyIsAccepted
Run-Test Test-SignatureWithLineBreakIsAccepted
Run-Test Test-UnknownKeyIsRejected
Run-Test Test-ChangedAfterSigningIsRejected
Run-Test Test-MissingSignatureIsRejected
Run-Test Test-AppWithoutKeysIsRejected
if ($PSVersionTable.PSEdition -eq "Desktop") {
    Run-Test Test-BatAcceptsSignedSameVersion
    Run-Test Test-BatRejectsUnknownKey
} else {
    Write-Host "SKIP .bat end-to-end tests (Windows PowerShell 5.1 only)"
}

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""; Write-Host "$script:Run tests, $script:Failed failed"
if ($script:Failed -gt 0) { exit 1 }

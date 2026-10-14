# Checks latest.json.sig: the Base64 SHA256withRSA signature of latest.json's exact
# bytes, made with the update-signing key or its offline backup. Both public keys ship
# in app\ as XML, which Windows PowerShell 5.1 can load.
# Exit 0 = valid, 1 = missing or invalid.
param([string]$Json, [string]$Sig, [string]$AppDir)
try {
    $data = [IO.File]::ReadAllBytes($Json)
    $signature = [Convert]::FromBase64String([IO.File]::ReadAllText($Sig).Trim())
    foreach ($name in "update-signing-public.xml", "update-signing-backup-public.xml") {
        $keyFile = Join-Path $AppDir $name
        if (-not (Test-Path -LiteralPath $keyFile)) { continue }
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
        $rsa.FromXmlString([IO.File]::ReadAllText($keyFile))
        if ($rsa.VerifyData($data, "SHA256", $signature)) { exit 0 }
    }
} catch { }
exit 1

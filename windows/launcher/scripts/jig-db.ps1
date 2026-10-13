# Shared database helpers, dot-sourced by the .ps1 scripts:
#     . (Join-Path $PSScriptRoot "jig-db.ps1")
# Every script connects with the account in app\application.properties
# (jig_app since v2.0), never an assumed root without a password. The password
# reaches MySQL through a temporary option file that only the current user can
# read and that is deleted right after the call - never on the command line,
# where Task Manager would show it.
# Must work in Windows PowerShell 5.1 (customers) and PowerShell 7 (tests on macOS).

$script:JigAppDbUser = "jig_app"

function Read-JigProps([string]$path) {
    $map = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^\s*([^#!=\s][^=]*?)\s*=(.*)$') { $map[$Matches[1]] = $Matches[2].Trim() }
    }
    return $map
}

# Replace the key's line (first one; later duplicates are dropped) or append it.
function Set-JigProp([string]$path, [string]$key, [string]$value) {
    $lines = [Collections.Generic.List[string]]::new([IO.File]::ReadAllLines($path))
    $done = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*([^#!=\s][^=]*?)\s*=' -and $Matches[1] -eq $key) {
            if ($done) { $lines.RemoveAt($i); $i-- } else { $lines[$i] = "$key=$value"; $done = $true }
        }
    }
    if (-not $done) { $lines.Add("$key=$value") }
    [IO.File]::WriteAllText($path, ($lines -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding $false))
}

function Find-JigMySqlBin([string]$override = "") {
    if ($override -ne "") { if (Test-Path $override) { return $override } else { return $null } }
    foreach ($d in @("C:\xampp\mysql\bin", "C:\xampp\mariadb\bin")) {
        if (Test-Path (Join-Path $d "mysql.exe")) { return $d }
    }
    $cmd = Get-Command mysql -ErrorAction SilentlyContinue
    if ($cmd) { return (Split-Path $cmd.Source) }
    return $null
}

function Get-JigDbConfig([string]$PackageDir, [string]$MySqlBin = "") {
    $propsPath = [IO.Path]::Combine($PackageDir, "app", "application.properties")
    $p = Read-JigProps $propsPath
    $cfg = @{ PropsPath = $propsPath; User = "root"; Pass = ""; Name = "web_fixture_management"
              Host = "localhost"; Port = ""; Bin = (Find-JigMySqlBin $MySqlBin) }
    if ($p.Contains("spring.datasource.username") -and $p["spring.datasource.username"] -ne "") { $cfg.User = $p["spring.datasource.username"] }
    if ($p.Contains("spring.datasource.password")) { $cfg.Pass = $p["spring.datasource.password"] }
    if ($p.Contains("spring.datasource.url") -and $p["spring.datasource.url"] -match '^jdbc:[a-z]+://([^/:]+)(?::(\d+))?/([^?;]+)') {
        $cfg.Host = $Matches[1]; if ($Matches[2]) { $cfg.Port = $Matches[2] }; $cfg.Name = $Matches[3]
    }
    return $cfg
}

# Settings file now holds the DB password: current user, Administrators and
# SYSTEM only (chmod 600 when the tests run on macOS).
function Protect-JigFile([string]$path) {
    if ($env:OS -eq "Windows_NT") {
        $acl = New-Object Security.AccessControl.FileSecurity
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($who in @([Security.Principal.WindowsIdentity]::GetCurrent().Name, "BUILTIN\Administrators", "NT AUTHORITY\SYSTEM")) {
            $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($who, "FullControl", "Allow")))
        }
        Set-Acl -Path $path -AclObject $acl
    } else {
        chmod 600 $path
    }
}

function Get-JigTool($cfg, [string]$tool) {
    $exe = Join-Path $cfg.Bin "$tool.exe"
    if (Test-Path $exe) { return $exe }
    return (Join-Path $cfg.Bin $tool)   # macOS test runs
}

# A temp file only we can read (it holds a password); the caller deletes it.
function New-JigPrivateFile([string[]]$lines) {
    $file = [IO.Path]::GetTempFileName()
    Protect-JigFile $file
    [IO.File]::WriteAllLines($file, $lines)   # UTF-8 without BOM
    return $file
}

function New-JigOptionFile([string]$user, [string]$pass, $cfg) {
    $escaped = $pass.Replace('\', '\\').Replace('"', '\"')
    $lines = @("[client]", "user=$user", "password=`"$escaped`"", "host=$($cfg.Host)")
    if ($cfg.Port -ne "") { $lines += "port=$($cfg.Port)" }
    return (New-JigPrivateFile $lines)
}

# Runs mysql or mysqldump. Returns @{ Code; Out; Err }.
function Invoke-JigDbTool($cfg, [string]$tool, [string[]]$arguments, [string]$inputFile = $null, [string]$user = $null, [string]$pass = $null) {
    if (-not $user) { $user = $cfg.User; $pass = $cfg.Pass }
    $opt = New-JigOptionFile $user $pass $cfg
    $out = [IO.Path]::GetTempFileName(); $err = [IO.Path]::GetTempFileName()
    try {
        # --defaults-file must be the first argument; it also stops the client
        # from reading my.ini, whose password would override ours. TCP like Java.
        $all = @("--defaults-file=$opt", "--protocol=TCP", "--default-character-set=utf8mb4") + $arguments |
            ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
        $p = @{ FilePath = (Get-JigTool $cfg $tool); ArgumentList = $all; NoNewWindow = $true; Wait = $true; PassThru = $true
                RedirectStandardOutput = $out; RedirectStandardError = $err }
        if ($inputFile) { $p.RedirectStandardInput = $inputFile }
        $proc = Start-Process @p
        return @{ Code = $proc.ExitCode; Out = [string](Get-Content $out -Raw); Err = [string](Get-Content $err -Raw) }
    } catch {
        return @{ Code = 1; Out = ""; Err = "$_" }
    } finally {
        Remove-Item $opt, $out, $err -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-JigMySql($cfg, [string[]]$arguments, [string]$inputFile = $null) { Invoke-JigDbTool $cfg "mysql" $arguments $inputFile }
function Invoke-JigMySqlDump($cfg, [string[]]$arguments) { Invoke-JigDbTool $cfg "mysqldump" (@("--no-tablespaces", "--single-transaction") + $arguments) }
function Test-JigDb($cfg) { return ((Invoke-JigMySql $cfg @("-N", "-B", "-e", "SELECT 1")).Code -eq 0) }

function New-JigPassword {
    $chars = [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $bytes = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return (-join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] }))
}

function Remove-JigAppAccount($cfg) {
    $u = $script:JigAppDbUser
    Invoke-JigMySql $cfg @("-e", "DROP USER IF EXISTS '$u'@'localhost'; DROP USER IF EXISTS '$u'@'127.0.0.1'; DROP USER IF EXISTS '$u'@'::1';") | Out-Null
}

# Switches app\application.properties from root to jig_app. Leaves other
# accounts alone. Returns @{ Ok; Created; Message }; the settings are only
# changed when Ok. $cfg keeps describing the account used before (root).
function Install-JigAppAccount($cfg) {
    $u = $script:JigAppDbUser
    if ($cfg.User -ne "root") { return @{ Ok = $true; Created = $false; Message = "Database account: $($cfg.User) (kept)" } }
    $pw = New-JigPassword
    $r = Invoke-JigMySql $cfg @("-N", "-B", "-e", "SELECT COUNT(*) FROM mysql.user WHERE User='$u'")
    if ($r.Code -ne 0) { return @{ Ok = $false; Created = $false; Message = "Cannot read the MySQL accounts: $($r.Err)" } }
    $created = ($r.Out.Trim() -eq "0")
    $sql = foreach ($h in @("localhost", "127.0.0.1", "::1")) {
        "CREATE OR REPLACE USER '$u'@'$h' IDENTIFIED BY '$pw'; GRANT ALL PRIVILEGES ON ``$($cfg.Name)``.* TO '$u'@'$h';"
    }
    # The SQL goes through a private temp file, not -e: Task Manager would show it.
    $sqlFile = New-JigPrivateFile $sql
    try {
        $r = Invoke-JigMySql $cfg @() $sqlFile
        $ok = $r.Code -eq 0
        # Prove the new account can read the real data before switching to it.
        if ($ok) { $r = Invoke-JigDbTool $cfg "mysql" @("-N", "-B", "-e", "SELECT COUNT(*) FROM users", $cfg.Name) $null $u $pw; $ok = $r.Code -eq 0 }
        if ($ok) {
            Protect-JigFile $cfg.PropsPath
            Set-JigProp $cfg.PropsPath "spring.datasource.username" $u
            Set-JigProp $cfg.PropsPath "spring.datasource.password" $pw
        }
    } catch {
        $ok = $false; $r = @{ Err = "$_" }
    } finally {
        Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue
    }
    if (-not $ok) {
        if ($created) { Remove-JigAppAccount $cfg }
        return @{ Ok = $false; Created = $false; Message = "Could not set up the database account ${u}: $($r.Err)" }
    }
    return @{ Ok = $true; Created = $created; Message = "Database account: $u (password saved in app\application.properties)" }
}

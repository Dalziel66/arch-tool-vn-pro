#requires -Version 5.1
# [VI] Test offline: kế hoạch winget, từ chối đầu vào xấu, nguồn, và tinh chỉnh với registry giả trong bộ nhớ.
# No package installation, registry writes, elevation, or network access.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
. "$root\src\Core.ps1"
. "$root\src\Tweaks.ps1"
$script:Passed=0
function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw "FAIL: $Message" }; $script:Passed++; Write-Output "PASS: $Message" }
function Assert-Throws([scriptblock]$Action,[string]$Message) { $caught=$false; try { & $Action | Out-Null } catch { $caught=$true }; Assert-True $caught $Message }

$catalog=@(Get-MocCatalog)
Assert-True ($catalog.Count -eq 36) 'Catalog loads all 36 applications on Windows PowerShell 5.1'
foreach ($action in @('install','upgrade','uninstall','show')) {
    foreach ($app in $catalog) {
        $plan=@(New-MocWingetPlan -Action $action -Ids @($app.id) -AcceptAgreements)
        if ($plan.Count -ne 1 -or $plan[0].Arguments -notcontains '--exact' -or $plan[0].Arguments -notcontains 'winget') { throw 'Invalid plan' }
        foreach ($token in $plan[0].Arguments) { if ($token -cnotmatch '^[A-Za-z0-9._+-]+$') { throw "Unsafe command token: $token" } }
    }
}
Assert-True $true 'All catalog/action combinations produce token-safe exact-source commands'
Assert-Throws { New-MocWingetPlan -Action install -Ids @('Mozilla.Firefox') } 'Install requires explicit agreement consent'
Assert-Throws { New-MocWingetPlan -Action upgrade -Ids @('Mozilla.Firefox') } 'Upgrade requires explicit agreement consent'
foreach ($id in @('Mozilla.Firefox;calc','Mozilla.Firefox --force','$(calc)','Unknown.Package','mozilla.firefox','--help','')) {
    Assert-Throws { New-MocWingetPlan -Action show -Ids @($id) } "Reject untrusted ID: $id"
}
Assert-Throws { New-MocWingetPlan -Action install -Ids @() -AcceptAgreements } 'Empty selection rejected'
Assert-Throws { New-MocWingetPlan -Action list -Ids @('Mozilla.Firefox') } 'Inventory cannot receive package IDs'
$plans=@(New-MocWingetPlan -Action show -Ids @('Mozilla.Firefox','Mozilla.Firefox'))
Assert-True ($plans.Count -eq 1) 'Repeated IDs deduplicate'
$install=New-MocWingetPlan -Action install -Ids @('Mozilla.Firefox') -AcceptAgreements
Assert-True ($install.Arguments -contains '--no-upgrade') 'Install does not implicitly upgrade'
$uninstall=New-MocWingetPlan -Action uninstall -Ids @('Mozilla.Firefox') -AcceptAgreements
Assert-True ($uninstall.Arguments -contains '--interactive' -and $uninstall.Arguments -notcontains '--purge') 'Uninstall preserves installer UI and omits purge'
$tampered=New-MocWingetPlan -Action show -Ids @('Mozilla.Firefox')
$tampered.Arguments += '--ignore-security-hash'
Assert-Throws {Start-MocProcess -Executable 'unused' -Plan $tampered} 'Execution boundary rejects a modified plan before spawning a process'
Assert-Throws {Get-MocTweak -Id '..\evil'} 'Tweak path traversal rejected'
Assert-Throws {Start-MocTool -Id 'calc.exe & whoami'} 'Unknown system tool rejected'
Assert-Throws {Open-MocApp -Id 'Unknown.Package'} 'Unknown app launch rejected'
Assert-True ($null -eq (Get-MocLaunchPath -Id 'Unknown.Package')) 'No PATH fallback for unknown app launches'
Assert-True ((Get-MocExitDescription 3010) -match 'khởi động lại') 'Reboot-required exit is explained'
Assert-True ((Get-MocExitDescription -1) -match '0xFFFFFFFF') 'Negative HRESULT is preserved as unsigned hex'
$official='{"Name":"winget","Arg":"https://cdn.winget.microsoft.com/cache","Type":"Microsoft.PreIndexed.Package","Identifier":"Microsoft.Winget.Source_8wekyb3d8bbwe"}'
Test-MocSource -Json $official
Assert-True $true 'Official Microsoft winget source accepted'
Assert-Throws {Test-MocSource -Json ($official.Replace('cdn.winget.microsoft.com','evil.example'))} 'Renamed third-party source rejected'
Assert-Throws {Test-MocSource -Json ($official.Replace('https:','http:'))} 'Insecure source URL rejected'
Assert-Throws {Test-MocSource -Json ($official.Replace('Microsoft.PreIndexed.Package','Microsoft.Rest'))} 'Unexpected source type rejected'
Assert-Throws {Test-MocSource -Json '{}'} 'Incomplete source metadata rejected'

# Keep backup/audit tests confined to the workspace. Registry adapter is in memory.
$script:StateRoot=Join-Path $root ('artifacts\tests-' + [Guid]::NewGuid().ToString('N'))
$script:Memory=@{extensions=[pscustomobject]@{Exists=$true; Value=1}; dark=[pscustomobject]@{Exists=$false; Value=$null}; transparency=[pscustomobject]@{Exists=$true; Value=1}}
$script:SimulateFailure=$false
function Get-MocRegistryState {param([object]$Tweak) return $script:Memory[$Tweak.Id]}
function Set-MocRegistryState {param([object]$Tweak,[bool]$Exists,[object]$Value)
    $backupPath=Join-Path $script:StateRoot ('backups\' + $Tweak.Id + '.json')
    if (-not (Test-Path -LiteralPath $backupPath)) {throw 'Write attempted before backup'}
    if ($script:SimulateFailure) {throw 'Simulated registry permission failure'}
    $script:Memory[$Tweak.Id]=[pscustomobject]@{Exists=$Exists; Value=$Value}
}
Invoke-MocTweak extensions
Assert-True ($script:Memory.extensions.Value -eq 0) 'Apply writes only after original snapshot exists'
$backupPath=Join-Path $script:StateRoot 'backups\extensions.json'
$before=[IO.File]::ReadAllText($backupPath)
Assert-Throws {Invoke-MocTweak extensions} 'Repeated apply cannot overwrite original snapshot'
Assert-True ([IO.File]::ReadAllText($backupPath) -ceq $before) 'Original snapshot is unchanged'
Invoke-MocTweak extensions -Restore
Assert-True ($script:Memory.extensions.Value -eq 1) 'Restore returns the original value'
Assert-True (-not (Test-Path -LiteralPath $backupPath)) 'Restored snapshot is archived'
Assert-Throws {Invoke-MocTweak extensions -Restore} 'No fabricated rollback without snapshot'
Invoke-MocTweak dark
Invoke-MocTweak dark -Restore
Assert-True (-not $script:Memory.dark.Exists) 'Restore removes a value which originally did not exist'
Invoke-MocTweak extensions
$script:Memory.extensions=[pscustomobject]@{Exists=$true; Value=4}
Assert-Throws {Invoke-MocTweak extensions -Restore} 'Restore refuses to overwrite an external change'
$script:Memory.extensions=[pscustomobject]@{Exists=$true; Value=0}
$backup=Get-Content -LiteralPath $backupPath -Raw -Encoding UTF8 | ConvertFrom-Json
$backup.sid='wrong-user'
$backup | ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
Assert-Throws {Invoke-MocTweak extensions -Restore} 'Backup from a different user rejected'
$backup.sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$backup.id='dark'
Assert-Throws {Test-MocBackup $backup extensions} 'Backup for a different tweak rejected'
$backup.id='extensions'; $backup.value='not a number'
Assert-Throws {Test-MocBackup $backup extensions} 'Non-integer backup rejected'
$backup.value=2147483648
Assert-Throws {Test-MocBackup $backup extensions} 'Out-of-range DWORD rejected'
$script:SimulateFailure=$true
Assert-Throws {Invoke-MocTweak transparency} 'Registry write failure is surfaced'
Assert-True (Test-Path -LiteralPath (Join-Path $script:StateRoot 'backups\transparency.json')) 'Snapshot survives a failed write'
Assert-True ($script:Memory.transparency.Value -eq 1) 'Failed write leaves simulated original unchanged'
$audit=@(Get-Content -LiteralPath (Join-Path $script:StateRoot ('audit-' + (Get-Date -Format yyyy-MM) + '.jsonl')) -Encoding UTF8 | ForEach-Object {$_ | ConvertFrom-Json})
Assert-True ($audit.Count -gt 0 -and $audit[0].event -eq 'tweak-start') 'Audit log is valid structured JSONL'
# Installer irm: tải qua file:// (không mạng), kiểm tra hash, giải nén, không mở UI.
. "$root\scripts\Install.template.ps1"
$fake=Join-Path $script:StateRoot 'pkg\MocToolkit-9.9.9'; [void](New-Item -ItemType Directory -Path $fake -Force)
Set-Content -LiteralPath (Join-Path $fake 'Start-Moc.ps1') -Value '# fake' -Encoding UTF8
$fakeZip=Join-Path $script:StateRoot 'fake.zip'; Compress-Archive -LiteralPath $fake -DestinationPath $fakeZip
$fakeHash=(Get-FileHash -LiteralPath $fakeZip -Algorithm SHA256).Hash
$appDir=Join-Path $script:StateRoot 'app'
$installed=Install-Moc -ZipUrl ([Uri]$fakeZip).AbsoluteUri -Sha256 $fakeHash -Version '9.9.9' -Destination $appDir -NoLaunch 6>$null
Assert-True (Test-Path -LiteralPath (Join-Path $installed 'Start-Moc.ps1')) 'Installer extracts a hash-verified package'
[void](Install-Moc -ZipUrl ([Uri]$fakeZip).AbsoluteUri -Sha256 $fakeHash -Version '9.9.9' -Destination $appDir -NoLaunch 6>$null)
Assert-True (@(Get-ChildItem -LiteralPath $appDir).Count -eq 1) 'Reinstall replaces the version folder without leftovers'
Assert-Throws {Install-Moc -ZipUrl ([Uri]$fakeZip).AbsoluteUri -Sha256 ('0'*64) -Version '9.9.9' -Destination (Join-Path $script:StateRoot 'bad') -NoLaunch 6>$null} 'Installer rejects a hash mismatch'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:StateRoot 'bad\9.9.9'))) 'Hash mismatch installs nothing'
Write-Output "`n$script:Passed checks passed. Registry was mocked; no real installation or system modification."

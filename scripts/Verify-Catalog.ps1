# [VI] Truy vấn online "winget show" cho từng ID trong catalog để xác nhận gói còn tồn tại; không cài gì.
# Read-only online check. Queries package metadata; does not install any package.
# WinGet may refresh its own source cache. Requires access to App Installer/network.
param([string[]]$Ids=@())
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. "$root\src\Core.ps1"
$script:StateRoot=Join-Path $root 'artifacts\catalog-validation'
$winget=Resolve-MocWinget
$catalog=@(Get-MocCatalog)
if ($Ids.Count -eq 0) { $Ids=@($catalog.id) }
$results=@()
foreach ($id in $Ids) {
    $plan=New-MocWingetPlan -Action show -Ids @($id)
    $job=Start-MocProcess -Executable $winget -Plan $plan
    try {
        if (-not $job.Process.WaitForExit(30000)) { $job.Process.Kill(); throw "Metadata request timed out for $id" }
        $out=$job.Output.GetAwaiter().GetResult(); $err=$job.Error.GetAwaiter().GetResult()
        $results += [pscustomobject]@{id=$id; code=$job.Process.ExitCode; output=$out; error=$err; verifiedAt=[DateTime]::UtcNow.ToString('o')}
        Write-Output "$id : exit $($job.Process.ExitCode)"
    } finally { $job.Process.Dispose() }
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:StateRoot 'report.json') -Encoding UTF8
$failed=@($results | Where-Object code -NE 0)
if ($failed.Count -gt 0) { throw "$($failed.Count) catalog metadata checks failed. See artifacts/catalog-validation/report.json" }
Write-Output "Verified $($results.Count) package IDs against the official winget source."

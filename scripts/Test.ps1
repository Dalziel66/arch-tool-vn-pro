#requires -Version 5.1
# [VI] Chạy kiểm tra cú pháp mọi .ps1, test core bằng Windows PowerShell 5.1 và (tùy chọn -IncludeUI) smoke test WPF.
param([switch]$IncludeUI)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$engine=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
foreach ($file in Get-ChildItem -LiteralPath $root -Filter *.ps1 -Recurse) {
    $tokens=$null; $issues=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$issues)
    if ($issues.Count -gt 0) { throw ($issues | Out-String) }
}
& $engine -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "$root\tests\Run-Tests.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
if ($IncludeUI) {
    & $engine -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -STA -File "$root\Start-Moc.ps1" -SmokeTest -ScreenshotPath "$root\artifacts\moc-preview.png"
    if ($LASTEXITCODE -ne 0) { throw 'UI smoke failed.' }
}

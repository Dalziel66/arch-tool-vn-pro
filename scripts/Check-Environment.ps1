# [VI] Chẩn đoán chỉ đọc: in phiên bản PowerShell/Windows, xác minh chữ ký winget và nguồn chính thức.
# Read-only diagnostic: no installs, no source modifications, no elevation.
$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\src\Core.ps1"
Write-Output ('PowerShell: ' + $PSVersionTable.PSVersion)
Write-Output ('Windows: ' + [Environment]::OSVersion.Version)
$winget=Resolve-MocWinget
Write-Output ('Validated executable: ' + $winget)
& $winget --version
if ($LASTEXITCODE -ne 0) { throw 'Winget version check failed.' }
Assert-MocOfficialSource -Executable $winget
Write-Output 'Official source validation passed.'

#requires -Version 5.1
# [VI] Đóng gói portable: chép các thư mục được liệt kê, biên dịch Moc.exe bằng csc của .NET Framework, tạo SHA256SUMS và ZIP.
[CmdletBinding()]
# [VI] -Repo owner/name: sinh thêm dist/install.ps1 cho lệnh irm, trỏ tới GitHub Release v0.1.0.
param([ValidatePattern('^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$')][string]$Repo='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$published=Join-Path $root 'dist\MocToolkit-0.1.0'
# Always stage into a fresh directory. Never zip a previously run portable folder,
# which may contain logs, test artifacts or files removed from newer source.
$stageRoot=Join-Path $root ('dist\.build-' + [Guid]::NewGuid().ToString('N'))
$destination=Join-Path $stageRoot 'MocToolkit-0.1.0'
$compiler=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The Windows .NET Framework C# compiler was not found.' }
[void](New-Item -ItemType Directory -Path $destination -Force)
# Explicit inclusion prevents private files and test artifacts leaking into a release.
foreach ($name in @('Start-Moc.ps1','Start-Moc.cmd','README.md','CLAUDE.md','AGENTS.md','LICENSE','CHANGELOG.md','src','data','docs','launcher','scripts','tests')) {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination $destination -Recurse -Force
}
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll "/win32manifest:$root\launcher\app.manifest" "/out:$destination\Moc.exe" "$root\launcher\MocLauncher.cs"
if ($LASTEXITCODE -ne 0) { throw 'Launcher build failed.' }
$manifest=Join-Path $destination 'SHA256SUMS.txt'
$hashes=Get-ChildItem -LiteralPath $destination -File -Recurse | Where-Object Name -NE 'SHA256SUMS.txt' | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.FullName.Substring($destination.Length+1)
}
[IO.File]::WriteAllLines($manifest,[string[]]$hashes,(New-Object Text.UTF8Encoding($false)))
$zip=Join-Path $root 'dist\MocToolkit-0.1.0.zip'
Compress-Archive -LiteralPath $destination -DestinationPath $zip -Force
[void](New-Item -ItemType Directory -Path $published -Force)
Get-ChildItem -LiteralPath $destination -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $published -Recurse -Force }
Write-Output "Portable build: $published\Moc.exe"
Write-Output "Archive: $zip"
Write-Output "Clean staging directory retained for review: $destination"
$zipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
if ($Repo) {
    # Hash cố định trong install.ps1: zip bị thay trên release sẽ bị từ chối.
    $template=[IO.File]::ReadAllText((Join-Path $root 'scripts\Install.template.ps1')).TrimStart([char]0xFEFF)
    $call="[void](Install-Moc -ZipUrl 'https://github.com/$Repo/releases/download/v0.1.0/MocToolkit-0.1.0.zip' -Sha256 '$zipHash' -Version '0.1.0')"
    if ($template -notmatch '#MOC-INVOKE') { throw 'Install template marker missing.' }
    $installer=Join-Path $root 'dist\install.ps1'
    # Không BOM: irm có thể giải mã BOM thành ký tự lạ ở đầu script.
    [IO.File]::WriteAllText($installer,$template.Replace('#MOC-INVOKE',$call),(New-Object Text.UTF8Encoding($false)))
    Write-Output "Installer: $installer"
    Write-Output "CMD: powershell -NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol=3072; irm https://github.com/$Repo/releases/latest/download/install.ps1 | iex`""
}
Write-Output ('ZIP SHA256: ' + $zipHash)

#requires -Version 5.1
# [VI] Điểm khởi động: kiểm tra Windows + STA, nạp WPF, dot-source Core/Tweaks/UI rồi mở cửa sổ (hoặc chạy smoke test).
[CmdletBinding()]
param([switch]$SmokeTest, [string]$ScreenshotPath = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $ScreenshotPath) { $ScreenshotPath = Join-Path $PSScriptRoot 'artifacts\moc-preview.png' }
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Moc requires Windows.' }
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Start with powershell.exe -STA -File Start-Moc.ps1' }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. "$PSScriptRoot\src\Core.ps1"
. "$PSScriptRoot\src\Tweaks.ps1"
. "$PSScriptRoot\src\UI.ps1"
Start-MocWindow -SmokeTest:$SmokeTest -ScreenshotPath $ScreenshotPath

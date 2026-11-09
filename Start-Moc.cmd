@echo off
rem Mo Moc bang Windows PowerShell 5.1 (STA); giu cua so neu loi de doc thong bao.
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -STA -File "%~dp0Start-Moc.ps1"
if errorlevel 1 pause

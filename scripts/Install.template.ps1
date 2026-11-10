# [VI] Bootstrap cho lệnh "irm <url>/install.ps1 | iex". Build.ps1 sinh dist/install.ps1 từ mẫu này,
# điền sẵn URL zip của release và SHA256. Hash sai => xóa tệp tải về và dừng, không chạy gì.
# Không cần quyền quản trị; chỉ ghi vào %LOCALAPPDATA%\MocToolkit\app.

function Install-Moc {
    param(
        [Parameter(Mandatory)][string]$ZipUrl,
        [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$Sha256,
        [Parameter(Mandatory)][string]$Version,
        [string]$Destination = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MocToolkit\app'),
        [switch]$NoLaunch
    )
    $ErrorActionPreference = 'Stop'
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Moc chi chay tren Windows.' }
    if ($PSVersionTable.PSVersion -lt [version]'5.1') { throw 'Can Windows PowerShell 5.1 tro len.' }
    # PS 5.1 mặc định có thể chưa bật TLS 1.2, GitHub từ chối TLS cũ.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $work = Join-Path ([IO.Path]::GetTempPath()) ('moc-install-' + [Guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $work)
    try {
        $zip = Join-Path $work 'moc.zip'
        Write-Host "[moc] Tai $ZipUrl"
        for ($try = 1; ; $try++) {
            try { Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing; break }
            catch { if ($try -ge 3) { throw "Khong tai duoc goi sau 3 lan: $($_.Exception.Message)" }; Start-Sleep -Seconds (2 * $try) }
        }
        $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        if ($actual -ne $Sha256.ToUpperInvariant()) { throw "SHA256 khong khop (nhan $actual). Da dung; khong giai nen hay chay gi." }
        Write-Host '[moc] SHA256 hop le.'

        $extract = Join-Path $work 'x'
        Expand-Archive -LiteralPath $zip -DestinationPath $extract
        $source = Join-Path $extract "MocToolkit-$Version"
        if (-not (Test-Path -LiteralPath (Join-Path $source 'Start-Moc.ps1'))) { throw 'Goi tai ve thieu Start-Moc.ps1.' }

        # Thay đúng thư mục phiên bản này; không đụng audit/backups trong MocToolkit.
        $target = Join-Path $Destination $Version
        [void](New-Item -ItemType Directory -Path $Destination -Force)
        $old = $null
        if (Test-Path -LiteralPath $target) { $old = "$target.old-" + [Guid]::NewGuid().ToString('N')
            # Mộc đang mở giữ thư mục này làm thư mục làm việc nên không đổi tên được.
            try { Move-Item -LiteralPath $target -Destination $old } catch { throw "Khong thay duoc ban cu (Moc dang mo?). Dong Moc roi chay lai lenh. $($_.Exception.Message)" }
        }
        try { Move-Item -LiteralPath $source -Destination $target }
        catch { if ($old) { Move-Item -LiteralPath $old -Destination $target }; throw }
        if ($old) { Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue }
        # Nội dung đã khớp hash, gỡ Mark-of-the-Web để RemoteSigned cho chạy.
        Get-ChildItem -LiteralPath $target -Recurse -File | Unblock-File
        Write-Host "[moc] Da cai vao $target"

        $script = Join-Path $target 'Start-Moc.ps1'
        if (-not $NoLaunch) {
            # Tiến trình riêng, STA, cho WPF; không phụ thuộc phiên shell đang gọi irm.
            $engine = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            Start-Process -FilePath $engine -WorkingDirectory $target -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','RemoteSigned','-STA','-File',"`"$script`"")
            Write-Host '[moc] Dang mo Moc...'
        }
        return $target
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Build.ps1 thay dòng dưới bằng lệnh gọi có URL/hash cố định. Mẫu gốc không làm gì.
#MOC-INVOKE

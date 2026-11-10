# [VI] Core: đọc catalog, lập kế hoạch lệnh winget, xác minh winget/nguồn, chạy tiến trình, mở ứng dụng và công cụ Windows.
# Pure command planning is deliberately separate from process execution.
# No catalog field is ever interpreted as PowerShell, a command line, or a URL.
Set-StrictMode -Version Latest
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StateRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MocToolkit'

# [VI] Đọc data/apps.json và kiểm tra từng mục (ID hợp lệ, không trùng, trường bắt buộc, màu hex). Sai là ném lỗi.
function Get-MocCatalog {
    param([string]$Path = (Join-Path $script:ProjectRoot 'data\apps.json'))
    $data = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($data.Count -lt 1 -or $data.Count -gt 500) { throw 'Invalid catalog size.' }
    $seen = @{}
    foreach ($app in $data) {
        if ($app.id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{1,119}$' -or $seen.ContainsKey($app.id)) { throw "Invalid or duplicate package ID: $($app.id)" }
        foreach ($field in @('name','category','description','mark','color')) {
            if (-not ($app.$field -is [string]) -or $app.$field.Length -gt 300 -or [string]::IsNullOrWhiteSpace($app.$field)) { throw "Invalid catalog field: $field" }
        }
        if ($app.color -notmatch '^#[0-9A-Fa-f]{6}$') { throw 'Invalid catalog color.' }
        $seen[$app.id] = $true
    }
    return $data
}

# [VI] Tạo danh sách tham số winget cố định cho từng gói trong catalog; không bao giờ nhận chuỗi lệnh tự do.
function New-MocWingetPlan {
    param(
        [Parameter(Mandatory)][ValidateSet('install','upgrade','uninstall','show','list')][string]$Action,
        [string[]]$Ids = @(), [switch]$AcceptAgreements
    )
    $catalog = @(Get-MocCatalog)
    if ($Action -ne 'list' -and $Ids.Count -eq 0) { throw 'Choose at least one package.' }
    if ($Action -eq 'list' -and $Ids.Count -gt 0) { throw 'Inventory does not accept IDs.' }
    if ($Action -eq 'list') {
        return [pscustomobject]@{ Id='inventory'; Action=$Action; Arguments=@('list','--source','winget','--disable-interactivity'); Display='winget list --source winget --disable-interactivity' }
    }
    foreach ($id in @($Ids | Select-Object -Unique)) {
        if ($id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{1,119}$' -or $id -cnotin @($catalog.id)) { throw "Package outside catalog: $id" }
        $arguments = @($Action,'--id',$id,'--exact','--source','winget','--disable-interactivity')
        if ($Action -in @('install','upgrade')) {
            $arguments += @('--no-upgrade') | Where-Object { $Action -eq 'install' }
            if (-not $AcceptAgreements) { throw 'Package/source agreements need explicit consent.' }
            $arguments += @('--accept-package-agreements','--accept-source-agreements')
        }
        # Uninstall retains installer UI. No --force, --purge, --silent or reboot flags.
        if ($Action -eq 'uninstall') { $arguments += '--interactive' }
        if ($AcceptAgreements -and $Action -in @('show','uninstall')) { $arguments += '--accept-source-agreements' }
        [pscustomobject]@{ Id=$id; Action=$Action; Arguments=$arguments; Display=('winget ' + ($arguments -join ' ')) }
    }
}

# [VI] Tìm winget.exe trong gói App Installer và chỉ chấp nhận khi có chữ ký Microsoft hợp lệ.
function Resolve-MocWinget {
    # Do not search PATH: a malicious winget.exe in the current directory must not win.
    $package = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction Stop | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $package) { throw 'Chưa có App Installer. Cài/cập nhật App Installer từ Microsoft Store rồi mở lại Mộc.' }
    $path = Join-Path $package.InstallLocation 'winget.exe'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Không tìm thấy winget.exe trong App Installer.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') { throw 'Không xác thực được chữ ký Microsoft của winget. Đã chặn thực thi.' }
    return $path
}

# [VI] Ghi một dòng JSON (JSONL) vào nhật ký kiểm toán theo tháng trong %LOCALAPPDATA%\MocToolkit.
function Write-MocAudit {
    param([Parameter(Mandatory)][string]$Event, [object]$Detail)
    if (-not (Test-Path -LiteralPath $script:StateRoot)) { [void](New-Item -ItemType Directory -Path $script:StateRoot -Force) }
    $row = [ordered]@{ time=[DateTime]::UtcNow.ToString('o'); event=$Event; detail=$Detail }
    $path = Join-Path $script:StateRoot ('audit-' + (Get-Date -Format 'yyyy-MM') + '.jsonl')
    Add-Content -LiteralPath $path -Value ($row | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8 -ErrorAction Stop
}

# [VI] So khớp JSON của nguồn "winget" với kho Microsoft chính thức (tên, URL, loại, identifier).
function Test-MocSource {
    param([Parameter(Mandatory)][string]$Json)
    $source=$Json | ConvertFrom-Json
    if ($source.Name -cne 'winget' -or $source.Arg -cne 'https://cdn.winget.microsoft.com/cache' -or $source.Type -cne 'Microsoft.PreIndexed.Package' -or $source.Identifier -cne 'Microsoft.Winget.Source_8wekyb3d8bbwe') {
        throw 'Nguồn có tên winget không khớp kho Microsoft chính thức. Đã chặn; không tự sửa nguồn của bạn.'
    }
}

# [VI] Chạy "winget source export" (chỉ đọc, tối đa 10 giây) rồi xác minh nguồn bằng Test-MocSource.
function Assert-MocOfficialSource {
    param([Parameter(Mandatory)][string]$Executable)
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Executable; $info.Arguments='source export --name winget --disable-interactivity'
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.StandardOutputEncoding=[Text.Encoding]::UTF8; $info.StandardErrorEncoding=[Text.Encoding]::UTF8
    $info.WorkingDirectory=$env:SystemRoot
    $proc=New-Object Diagnostics.Process; $proc.StartInfo=$info
    try {
        [void]$proc.Start()
        $stdout=$proc.StandardOutput.ReadToEndAsync(); $stderr=$proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit(10000)) {
            # This is only a read-only source export, never a running installer.
            $proc.Kill(); throw 'Kiểm tra nguồn winget quá 10 giây. Chưa chạy tác vụ.'
        }
        if ($proc.ExitCode -ne 0) { throw ('Không đọc được nguồn winget: ' + $stderr.GetAwaiter().GetResult()) }
        Test-MocSource -Json $stdout.GetAwaiter().GetResult()
    } finally { $proc.Dispose() }
}

# [VI] Xác minh lại kế hoạch, winget và nguồn ngay trước khi chạy; khởi động winget và đọc stdout/stderr bất đồng bộ.
function Start-MocProcess {
    param([Parameter(Mandatory)][string]$Executable, [Parameter(Mandatory)][object]$Plan)
    # Revalidate the entire plan at the execution boundary, including every flag.
    $ids = @(); if ($Plan.Action -ne 'list') { $ids = @($Plan.Id) }
    $approved = @(New-MocWingetPlan -Action $Plan.Action -Ids $ids -AcceptAgreements:($Plan.Arguments -contains '--accept-source-agreements'))
    if ($approved.Count -ne 1 -or ($approved[0].Arguments -join "`n") -cne ($Plan.Arguments -join "`n")) { throw 'Plan validation failed.' }
    if ($Executable -cne (Resolve-MocWinget)) { throw 'Untrusted executable.' }
    Assert-MocOfficialSource -Executable $Executable
    Write-MocAudit -Event 'process-start' -Detail @{command=$Plan.Display}
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    # .NET Framework lacks ArgumentList. All tokens above are validated ASCII
    # without whitespace or quotes; joining them cannot create another argument.
    $info.Arguments = $Plan.Arguments -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $info.WorkingDirectory = $env:SystemRoot
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    if (-not $process.Start()) { throw 'Unable to start winget.' }
    # Both streams drain concurrently to prevent pipe deadlock; UI polls asynchronously.
    [pscustomobject]@{ Process=$process; Output=$process.StandardOutput.ReadToEndAsync(); Error=$process.StandardError.ReadToEndAsync(); Plan=$Plan; Started=Get-Date }
}

# [VI] Dịch mã thoát (exit code) của winget/installer sang câu tiếng Việt dễ hiểu.
function Get-MocExitDescription {
    param([int]$Code)
    $hex = '0x' + [BitConverter]::ToUInt32([BitConverter]::GetBytes($Code),0).ToString('X8')
    switch ($hex) {
        '0x00000000' { return 'Hoàn tất (exit 0).' }
        '0x00000BC2' { return 'Hoàn tất; cần khởi động lại. Mộc không tự khởi động lại.' }
        '0x8A150014' { return 'Winget không tìm thấy gói: chưa cài (khi cập nhật/gỡ) hoặc mã gói không còn trên nguồn.' }
        '0x8A15002B' { return 'Không có bản cập nhật phù hợp.' }
        '0x8A150061' { return 'Đã cài sẵn; bỏ qua (không cài đè). Dùng "Cập nhật" nếu muốn lên bản mới.' }
        default { return "Không hoàn tất. Exit $Code ($hex). Xem đầu ra bên dưới." }
    }
}

# [VI] True nếu exit code nghĩa là "không có gì để làm": hàng đợi chạy tiếp, không tính là lỗi.
# Cố ý không gồm 3010 (cần reboot) và mã lạ: vẫn dừng để người dùng xem lại.
function Test-MocExitBenign {
    param([int]$Code)
    return $Code -in @(0, -1978335189, -1978335135)  # 0, 0x8A15002B (no update), 0x8A150061 (already installed)
}

# [VI] Trả về đường dẫn EXE ở vị trí cài đặt chuẩn của ứng dụng, hoặc $null nếu không tìm thấy.
function Get-MocLaunchPath {
    param([Parameter(Mandatory)][string]$Id)
    # Only fixed locations. No registry shell commands, arbitrary paths or CLI arguments.
    $locations = @{
        'Mozilla.Firefox'=@('PF|Mozilla Firefox\firefox.exe','PF86|Mozilla Firefox\firefox.exe')
        'Google.Chrome'=@('PF|Google\Chrome\Application\chrome.exe','LOCAL|Google\Chrome\Application\chrome.exe')
        'Brave.Brave'=@('PF|BraveSoftware\Brave-Browser\Application\brave.exe')
        'Microsoft.VisualStudioCode'=@('LOCAL|Programs\Microsoft VS Code\Code.exe','PF|Microsoft VS Code\Code.exe')
        'VideoLAN.VLC'=@('PF|VideoLAN\VLC\vlc.exe','PF86|VideoLAN\VLC\vlc.exe')
        '7zip.7zip'=@('PF|7-Zip\7zFM.exe')
        'Notepad++.Notepad++'=@('PF|Notepad++\notepad++.exe')
        'Valve.Steam'=@('PF86|Steam\steam.exe','PF|Steam\steam.exe')
        'OBSProject.OBSStudio'=@('PF|obs-studio\bin\64bit\obs64.exe')
        'Spotify.Spotify'=@('ROAM|Spotify\Spotify.exe')
        'Telegram.TelegramDesktop'=@('ROAM|Telegram Desktop\Telegram.exe')
        'Obsidian.Obsidian'=@('LOCAL|Obsidian\Obsidian.exe')
        'Microsoft.PowerToys'=@('PF|PowerToys\PowerToys.exe','LOCAL|PowerToys\PowerToys.exe')
        'SumatraPDF.SumatraPDF'=@('LOCAL|SumatraPDF\SumatraPDF.exe','PF|SumatraPDF\SumatraPDF.exe')
    }
    if (-not $locations.ContainsKey($Id)) { return $null }
    $roots = @{PF=[Environment]::GetFolderPath('ProgramFiles'); PF86=[Environment]::GetFolderPath('ProgramFilesX86'); LOCAL=[Environment]::GetFolderPath('LocalApplicationData'); ROAM=[Environment]::GetFolderPath('ApplicationData')}
    foreach ($location in $locations[$Id]) {
        $parts = $location.Split('|'); $root = $roots[$parts[0]]
        if (-not $root) { continue }
        $candidate = Join-Path $root $parts[1]
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

# [VI] Mở ứng dụng đã cài nếu EXE ở vị trí chuẩn và có chữ ký số hợp lệ.
function Open-MocApp {
    param([Parameter(Mandatory)][string]$Id)
    if ($Id -cnotin @( (Get-MocCatalog).id )) { throw 'Unknown application.' }
    $path = Get-MocLaunchPath -Id $Id
    if (-not $path) { throw 'Chưa tìm thấy ứng dụng ở vị trí chuẩn. Hãy mở bằng Start Menu; cài đặt tùy chỉnh/Store có thể dùng đường dẫn khác.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    if ($signature.Status -ne 'Valid') { throw 'Mộc chỉ mở trực tiếp tệp có chữ ký hợp lệ. Bạn có thể kiểm tra và mở thủ công từ Start Menu.' }
    Write-MocAudit -Event 'app-launch' -Detail @{id=$Id; path=$path; publisher=$signature.SignerCertificate.Subject}
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$path; $info.WorkingDirectory=Split-Path $path -Parent; $info.UseShellExecute=$false
    [void][Diagnostics.Process]::Start($info)
}

# [VI] Danh sách cố định các công cụ Windows (Settings, Task Manager, SFC, DISM...).
function Get-MocTools {
    @(
        [pscustomobject]@{Id='updates'; Name='Windows Update'; Description='Kiểm tra và quản lý cập nhật trong Windows Settings.'; File=''; Args='ms-settings:windowsupdate'; Admin=$false; Repair=$false}
        [pscustomobject]@{Id='storage'; Name='Storage'; Description='Xem dung lượng và chọn dữ liệu cần dọn trong Settings.'; File=''; Args='ms-settings:storagesense'; Admin=$false; Repair=$false}
        [pscustomobject]@{Id='startup'; Name='Startup apps'; Description='Tự chọn ứng dụng khởi động cùng Windows.'; File=''; Args='ms-settings:startupapps'; Admin=$false; Repair=$false}
        [pscustomobject]@{Id='apps'; Name='Installed apps'; Description='Mở danh sách ứng dụng của Windows.'; File=''; Args='ms-settings:appsfeatures'; Admin=$false; Repair=$false}
        [pscustomobject]@{Id='taskmgr'; Name='Task Manager'; Description='Theo dõi CPU, RAM và các tiến trình.'; File='Taskmgr.exe'; Args=''; Admin=$false; Repair=$false}
        [pscustomobject]@{Id='restore'; Name='System Protection'; Description='Mở cửa sổ để tự tạo hoặc quản lý restore point.'; File='SystemPropertiesProtection.exe'; Args=''; Admin=$false; Repair=$false}
        [pscustomobject]@{Id='sfcverify'; Name='Kiểm tra tệp hệ thống'; Description='SFC /verifyonly: kiểm tra, không sửa tệp. Cần UAC.'; File='sfc.exe'; Args='/verifyonly'; Admin=$true; Repair=$false}
        [pscustomobject]@{Id='dismcheck'; Name='Kiểm tra Windows image'; Description='DISM /ScanHealth: quét component store. Cần UAC.'; File='Dism.exe'; Args='/Online /Cleanup-Image /ScanHealth'; Admin=$true; Repair=$false}
        [pscustomobject]@{Id='sfc'; Name='Sửa tệp hệ thống'; Description='SFC /scannow: quét và sửa. Nên tạo restore point trước.'; File='sfc.exe'; Args='/scannow'; Admin=$true; Repair=$true}
        [pscustomobject]@{Id='dism'; Name='Sửa Windows image'; Description='DISM /RestoreHealth: có thể tải từ Windows Update. Không tự reboot.'; File='Dism.exe'; Args='/Online /Cleanup-Image /RestoreHealth /NoRestart'; Admin=$true; Repair=$true}
    )
}

# [VI] Mở một công cụ trong danh sách cố định; công cụ Admin yêu cầu UAC riêng cho tiến trình đó.
function Start-MocTool {
    param([Parameter(Mandatory)][string]$Id)
    $tool = @(Get-MocTools | Where-Object Id -CEQ $Id)
    if ($tool.Count -ne 1) { throw 'Unknown tool.' }
    $tool = $tool[0]
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.UseShellExecute = $true
    if ($tool.File) {
        $info.FileName = Join-Path ([Environment]::SystemDirectory) $tool.File
        $info.Arguments = $tool.Args
        if ($tool.Admin) { $info.Verb = 'runas' }
    } else { $info.FileName = $tool.Args }
    Write-MocAudit -Event 'tool-start' -Detail @{id=$Id; file=$info.FileName; arguments=$info.Arguments}
    return [Diagnostics.Process]::Start($info)
}

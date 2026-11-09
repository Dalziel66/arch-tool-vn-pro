# [VI] Tinh chỉnh registry HKCU (DWORD) có bản sao giá trị gốc, hoàn tác và đọc lại để xác minh.
# Deliberately limited to current-user DWORD settings. Backups never supply paths.
# [VI] Danh sách cố định các tinh chỉnh được hỗ trợ (khóa, tên value, giá trị áp dụng).
function Get-MocTweaks {
    @(
        [pscustomobject]@{Id='extensions'; Name='Hiện phần mở rộng tệp'; Description='Dễ nhận ra .exe, .pdf hoặc tệp có đuôi kép. Có thể cần mở lại Explorer.'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; ValueName='HideFileExt'; Value=0}
        [pscustomobject]@{Id='dark'; Name='Chế độ tối cho ứng dụng'; Description='Đặt giao diện tối cho ứng dụng Windows hỗ trợ. Có thể cần đăng nhập lại.'; Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; ValueName='AppsUseLightTheme'; Value=0}
        [pscustomobject]@{Id='transparency'; Name='Giảm hiệu ứng trong suốt'; Description='Tắt transparency của Windows cho giao diện rõ hơn. Có thể cần đăng nhập lại.'; Path='Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; ValueName='EnableTransparency'; Value=0}
    )
}

# [VI] Lấy đúng một tinh chỉnh theo Id; Id lạ bị từ chối.
function Get-MocTweak {
    param([string]$Id)
    $matches = @(Get-MocTweaks | Where-Object Id -CEQ $Id)
    if ($matches.Count -ne 1) { throw 'Unknown tweak.' }
    return $matches[0]
}

# [VI] Đọc trạng thái hiện tại (có tồn tại không, giá trị) của value; từ chối nếu không phải DWORD.
function Get-MocRegistryState {
    param([object]$Tweak)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Tweak.Path, $false)
    try {
        $exists = $null -ne $key -and $key.GetValueNames() -contains $Tweak.ValueName
        if ($exists -and $key.GetValueKind($Tweak.ValueName) -ne [Microsoft.Win32.RegistryValueKind]::DWord) { throw 'Registry value is not DWORD. Refusing to modify.' }
        $value = $null; if ($exists) { $value = [int]$key.GetValue($Tweak.ValueName) }
        return [pscustomobject]@{Exists=$exists; Value=$value}
    } finally { if ($key) { $key.Dispose() } }
}

# [VI] Kiểm tra bản sao JSON (không tin cậy): đúng schema, tinh chỉnh, người dùng, máy và giá trị DWORD.
function Test-MocBackup {
    param([object]$Backup, [string]$Id)
    if ($Backup.schema -ne 1 -or $Backup.id -cne $Id -or $Backup.sid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -or $Backup.machine -cne $env:COMPUTERNAME) { throw 'Backup does not belong to this user/machine/tweak.' }
    if ($Backup.exists -isnot [bool]) { throw 'Invalid backup existence flag.' }
    if ($Backup.exists -and ($Backup.value -isnot [int] -and $Backup.value -isnot [long])) { throw 'Invalid DWORD backup.' }
    if ($Backup.exists -and ($Backup.value -lt [int]::MinValue -or $Backup.value -gt [int]::MaxValue)) { throw 'DWORD backup out of range.' }
}

# [VI] Ghi DWORD hoặc xóa value (khi giá trị gốc không tồn tại). Không bao giờ xóa cả khóa.
function Set-MocRegistryState {
    param([object]$Tweak,[bool]$Exists,[object]$Value)
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($Tweak.Path)
    try {
        if ($Exists) { $key.SetValue($Tweak.ValueName, [int]$Value, [Microsoft.Win32.RegistryValueKind]::DWord) }
        else { $key.DeleteValue($Tweak.ValueName, $false) }
    } finally { $key.Dispose() }
}

# [VI] Áp dụng (tạo bản sao gốc trước) hoặc hoàn tác (-Restore) một tinh chỉnh, sau đó đọc lại để xác minh.
function Invoke-MocTweak {
    param([Parameter(Mandatory)][string]$Id, [switch]$Restore)
    $tweak = Get-MocTweak -Id $Id
    $backupDir = Join-Path $script:StateRoot 'backups'
    [void](New-Item -ItemType Directory -Path $backupDir -Force)
    $file = Join-Path $backupDir ($Id + '.json')
    # Get current state before writing a backup; abort on unsupported registry types.
    $current = Get-MocRegistryState -Tweak $tweak
    if ($Restore) {
        if (-not (Test-Path -LiteralPath $file)) { throw 'Chưa có bản sao để hoàn tác.' }
        $backup = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
        Test-MocBackup -Backup $backup -Id $Id
        # Avoid overwriting a setting changed by another program since our apply.
        if (-not $current.Exists -or $current.Value -ne $tweak.Value) { throw 'Giá trị đã thay đổi bên ngoài Mộc. Đã dừng để tránh ghi đè; xem docs/SECURITY.md.' }
        $desiredExists = $backup.exists; $desiredValue = $backup.value
    } else {
        if (Test-Path -LiteralPath $file) { throw 'Đã có bản sao cho tinh chỉnh này. Hoàn tác trước khi áp dụng lại.' }
        $backup = [ordered]@{schema=1; id=$Id; sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value; machine=$env:COMPUTERNAME; at=[DateTime]::UtcNow.ToString('o'); exists=$current.Exists; value=$current.Value}
        # CreateNew makes overwriting an existing original snapshot impossible.
        $bytes = [Text.Encoding]::UTF8.GetBytes(($backup | ConvertTo-Json))
        $stream = [IO.File]::Open($file, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
        $desiredExists = $true; $desiredValue = $tweak.Value
    }
    Write-MocAudit -Event 'tweak-start' -Detail @{id=$Id; restore=[bool]$Restore; before=$current}
    Set-MocRegistryState -Tweak $tweak -Exists $desiredExists -Value $desiredValue
    $after = Get-MocRegistryState -Tweak $tweak
    if ($after.Exists -ne $desiredExists -or ($desiredExists -and $after.Value -ne $desiredValue)) { throw 'Read-back verification failed. Backup retained.' }
    Write-MocAudit -Event 'tweak-complete' -Detail @{id=$Id; restore=[bool]$Restore; after=$after}
    if ($Restore) {
        # Archive rather than delete a successful restore snapshot.
        $archive = Join-Path $backupDir ($Id + '.restored-' + [Guid]::NewGuid().ToString('N') + '.json')
        Move-Item -LiteralPath $file -Destination $archive -ErrorAction Stop
    }
}

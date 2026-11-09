# [VI] Giao diện WPF: dựng thẻ ứng dụng/tinh chỉnh/công cụ, hộp xác nhận, hàng đợi winget và timer theo dõi tiến trình.
# [VI] Thêm một dòng có giờ vào ô nhật ký; tự cắt bớt khi quá dài.
function Add-MocLog {
    param([string]$Text)
    # Keep UI bounded; full command summaries/exit codes are in the audit log.
    if ($script:Ui.LogBox.Text.Length -gt 120000) { $script:Ui.LogBox.Text = $script:Ui.LogBox.Text.Substring($script:Ui.LogBox.Text.Length - 60000) }
    $script:Ui.LogBox.AppendText("`r`n[$(Get-Date -Format 'HH:mm:ss')] $Text")
    $script:Ui.LogBox.ScrollToEnd()
}

# [VI] Ghi lỗi vào nhật ký và hiện hộp thoại cảnh báo.
function Show-MocError {
    param([object]$ErrorRecord)
    Add-MocLog "LỖI: $ErrorRecord"
    [void][Windows.MessageBox]::Show($script:Window, [string]$ErrorRecord, 'Mộc — thao tác chưa hoàn tất', 'OK', 'Warning')
}

# [VI] Tạo TextBlock với cỡ chữ/màu cho trước.
function New-MocText {
    param([string]$Text, [int]$Size=14, [string]$Color='#D4BE98')
    $block = New-Object Windows.Controls.TextBlock
    $block.Text=$Text; $block.FontSize=$Size; $block.Foreground=$Color; $block.TextWrapping='Wrap'
    return $block
}

# [VI] Tạo Button và gắn sự kiện Click.
function New-MocButton {
    param([string]$Text, [scriptblock]$Click)
    $button = New-Object Windows.Controls.Button
    $button.Content=$Text
    $button.Add_Click($Click)
    return $button
}

# [VI] Cập nhật nhãn số ứng dụng đã chọn và đồng bộ các checkbox.
function Update-MocSelection {
    $script:Ui.SelectionLabel.Text = "$($script:Selected.Count) ứng dụng đã chọn"
    foreach ($check in @($script:CardChecks)) { $check.IsChecked = $script:Selected.ContainsKey([string]$check.Tag) }
}

# [VI] Vẽ lại lưới thẻ ứng dụng theo nhóm và ô tìm kiếm hiện tại.
function Render-MocApps {
    $script:Ui.AppCards.Children.Clear(); $script:CardChecks = @()
    $query=$script:Ui.SearchBox.Text.Trim()
    $script:Ui.SearchHint.Visibility = if ($query) { 'Collapsed' } else { 'Visible' }
    $visible=@($script:Catalog | Where-Object {
        ($script:Category -eq 'Tất cả' -or $_.category -eq $script:Category) -and
        (($_.name + ' ' + $_.id + ' ' + $_.category).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0)
    })
    foreach ($app in $visible) {
        $id=$app.id
        $border=New-Object Windows.Controls.Border
        $border.Width=365; $border.Height=147; $border.Margin='0,0,10,10'; $border.Padding='15,13'; $border.CornerRadius=5
        $border.Background='#262A28'; $border.BorderBrush='#3B4038'; $border.BorderThickness=1
        $panel=New-Object Windows.Controls.StackPanel
        $header=New-Object Windows.Controls.DockPanel
        $check=New-Object Windows.Controls.CheckBox
        $check.Tag=$id; $check.IsChecked=$script:Selected.ContainsKey($id); $check.Margin='0,0,10,0'
        $check.SetValue([Windows.Automation.AutomationProperties]::NameProperty, "Chọn $($app.name)")
        $check.Add_Click({param($sender,$eventArgs) if ($sender.IsChecked) { $script:Selected[[string]$sender.Tag]=$true } else { $script:Selected.Remove([string]$sender.Tag) }; Update-MocSelection })
        $script:CardChecks += $check
        [void]$header.Children.Add($check)
        $mark=New-MocText -Text $app.mark -Size 14 -Color $app.color
        $mark.FontFamily='Consolas'; $mark.Width=36; $mark.FontWeight='Bold'
        [void]$header.Children.Add($mark)
        $name=New-MocText -Text $app.name -Size 15; $name.FontWeight='SemiBold'
        [void]$header.Children.Add($name); [void]$panel.Children.Add($header)
        $desc=New-MocText -Text $app.description -Size 12 -Color '#AAA593'; $desc.Margin='0,10,0,7'; $desc.Height=34
        [void]$panel.Children.Add($desc)
        $bottom=New-Object Windows.Controls.DockPanel
        $info=New-MocButton -Text 'Thông tin' -Click ({try { Request-MocPackages -Action show -Ids @($id) } catch { Show-MocError $_ }}.GetNewClosure())
        $info.FontSize=11; $info.Padding='8,4'; $info.SetValue([Windows.Controls.DockPanel]::DockProperty,[Windows.Controls.Dock]::Right); $info.Margin='6,0,0,0'
        [void]$bottom.Children.Add($info)
        $launch=New-MocButton -Text 'Mở ↗' -Click ({try { Open-MocApp -Id $id; Add-MocLog "Đã yêu cầu mở $id" } catch { Show-MocError $_ }}.GetNewClosure())
        $launch.FontSize=11; $launch.Padding='8,4'; $launch.SetValue([Windows.Controls.DockPanel]::DockProperty,[Windows.Controls.Dock]::Right); $launch.Margin='6,0,0,0'
        $launch.IsEnabled = $null -ne (Get-MocLaunchPath -Id $id)
        $launch.ToolTip='Chỉ mở tệp ở vị trí chuẩn, có chữ ký hợp lệ; dùng Start Menu nếu nút này bị mờ.'
        [void]$bottom.Children.Add($launch)
        $tag=New-MocText -Text $app.category -Size 11 -Color '#89947B'; $tag.VerticalAlignment='Center'
        [void]$bottom.Children.Add($tag); [void]$panel.Children.Add($bottom)
        $border.Child=$panel; [void]$script:Ui.AppCards.Children.Add($border)
    }
    if ($visible.Count -eq 0) { [void]$script:Ui.AppCards.Children.Add((New-MocText -Text 'Không có kết quả. Thử tên khác hoặc chọn Tất cả.' -Color '#D8A657')) }
    Update-MocSelection
}

# [VI] Hộp thoại xem trước + đồng ý; gỡ cài đặt cần gõ đúng "GO". -TestOnly chỉ kiểm tra logic, không hiện hộp thoại.
function Confirm-MocPlan {
    param([string]$Title,[string]$Body,[switch]$Agreements,[switch]$Destructive,[switch]$TestOnly)
    $dialog=New-Object Windows.Window
    $dialog.Title=$Title; $dialog.Width=780; $dialog.Height=570; $dialog.MinHeight=430
    $dialog.Owner=$script:Window; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Background='#242827'; $dialog.Foreground='#D4BE98'; $dialog.FontFamily='Segoe UI'
    $dialog.Resources=$script:Window.Resources
    $grid=New-Object Windows.Controls.Grid; $grid.Margin=24
    foreach ($height in @('Auto','*','Auto','Auto','Auto')) { $row=New-Object Windows.Controls.RowDefinition; $row.Height=$height; [void]$grid.RowDefinitions.Add($row) }
    $titleBlock=New-MocText -Text $Title -Size 23 -Color '#A9B665'; $titleBlock.Margin='0,0,0,18'; [void]$grid.Children.Add($titleBlock)
    $bodyBox=New-Object Windows.Controls.TextBox
    $bodyBox.Text=$Body; $bodyBox.IsReadOnly=$true; $bodyBox.TextWrapping='Wrap'; $bodyBox.VerticalScrollBarVisibility='Auto'; $bodyBox.FontFamily='Consolas'; $bodyBox.FontSize=12
    $bodyBox.SetValue([Windows.Controls.Grid]::RowProperty,1); [void]$grid.Children.Add($bodyBox)
    $consent=New-Object Windows.Controls.CheckBox
    $consent.Content='Tôi đã đọc kế hoạch và đồng ý thực hiện các thao tác trên.'
    if ($Agreements) { $consent.Content='Tôi đã đọc kế hoạch và đồng ý điều khoản của gói và nguồn winget.' }
    $consent.Margin='0,18,0,12'; $consent.SetValue([Windows.Controls.Grid]::RowProperty,2); [void]$grid.Children.Add($consent)
    $typed=New-Object Windows.Controls.TextBox; $typed.Margin='0,0,0,12'; $typed.SetValue([Windows.Controls.Grid]::RowProperty,3)
    $typed.ToolTip='Gõ đúng chữ GO để xác nhận gỡ cài đặt.'
    if (-not $Destructive) { $typed.Visibility='Collapsed' }
    [void]$grid.Children.Add($typed)
    $buttons=New-Object Windows.Controls.StackPanel; $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'; $buttons.SetValue([Windows.Controls.Grid]::RowProperty,4)
    $cancel=New-MocButton -Text 'Quay lại' -Click ({$dialog.DialogResult=$false}.GetNewClosure()); $cancel.IsCancel=$true
    $ok=New-MocButton -Text 'Xác nhận & chạy' -Click ({$dialog.DialogResult=$true}.GetNewClosure()); $ok.IsEnabled=$false
    $update={ $ok.IsEnabled = $consent.IsChecked -eq $true -and (-not $Destructive -or $typed.Text -ceq 'GO') }.GetNewClosure()
    $consent.Add_Click($update); $typed.Add_TextChanged($update)
    [void]$buttons.Children.Add($cancel); [void]$buttons.Children.Add($ok); [void]$grid.Children.Add($buttons)
    $dialog.Content=$grid
    if ($TestOnly) {
        if ($ok.IsEnabled) { throw 'Confirmation must initially be disabled.' }
        $consent.IsChecked=$true; $consent.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        if ($Destructive) {
            if ($ok.IsEnabled) { throw 'Uninstall needs typed confirmation.' }
            $typed.Text='go'; if ($ok.IsEnabled) { throw 'Typed confirmation must be exact.' }
            $typed.Text='GO'
        }
        if (-not $ok.IsEnabled) { throw 'Consent did not enable confirmation.' }
        $consent.IsChecked=$false; $consent.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        if ($ok.IsEnabled) { throw 'Revoking consent must disable confirmation.' }
        return $false
    }
    return $dialog.ShowDialog() -eq $true
}

# [VI] Đổi nhóm đang lọc (helper thường, để closure không sửa $script: trực tiếp).
function Set-MocCategory {
    param([string]$Name)
    $script:Category=$Name
    Render-MocApps
}

# [VI] Đánh dấu bận và theo dõi một công cụ Windows cần UAC cho đến khi kết thúc.
function Watch-MocMaintenance {
    param([Diagnostics.Process]$Process,[string]$Id,[string]$Name)
    $script:Maintenance=[pscustomobject]@{Process=$Process; Id=$Id}
    $script:Busy=$true; $script:Ui.Tabs.IsEnabled=$false
    $script:Ui.StatusText.Text="●  CÔNG CỤ WINDOWS / $Name · chờ tiến trình hoàn tất"
}

# [VI] Lập kế hoạch winget, xin xác nhận, rồi đưa các lệnh vào hàng đợi chạy tuần tự.
function Request-MocPackages {
    param([ValidateSet('install','upgrade','uninstall','show','list')][string]$Action,[string[]]$Ids=@())
    if ($script:Busy) { throw 'Hãy chờ tác vụ hiện tại hoàn tất.' }
    if ($Action -ne 'list' -and $Ids.Count -eq 0) { throw 'Hãy chọn ít nhất một ứng dụng.' }
    $needsAgreement=$Action -in @('install','upgrade','uninstall','show')
    $plans=@(New-MocWingetPlan -Action $Action -Ids $Ids -AcceptAgreements:$needsAgreement)
    $title = @{install='Xem trước · Cài đặt'; upgrade='Xem trước · Cập nhật'; uninstall='Xem trước · Gỡ cài đặt'; show='Thông tin gói từ winget'; list='Danh sách phần mềm đã cài'}[$Action]
    $body="Nguồn: winget. Chỉ mã gói trong danh mục; phiên bản do winget chọn tại thời điểm chạy.`r`n`r`n" + (($plans.Display) -join "`r`n`r`n")
    if ($Action -in @('install','upgrade')) { $body += "`r`n`r`nTác động: tải và chạy installer của bên phát hành; có thể hiện UAC hoặc thay đổi cài đặt hệ thống. Mộc không bảo đảm installer bên thứ ba không yêu cầu khởi động lại. Cập nhật không có hoàn tác tự động. Đọc thông tin gói và giấy phép bằng nút Thông tin trước khi cài." }
    if ($Action -eq 'uninstall') { $body += "`r`n`r`nGỡ có thể mất cấu hình/dữ liệu tùy uninstaller. Không có hoàn tác tự động. Sao lưu trước; gõ GO vào ô bên dưới để xác nhận." }
    if ($Action -in @('show','list')) { $body += "`r`n`r`nKhông cài hoặc gỡ phần mềm. Winget có thể truy cập mạng/cập nhật bộ nhớ đệm nguồn. Nếu nguồn chưa được chấp nhận, list có thể yêu cầu bạn khởi tạo winget thủ công." }
    if (-not (Confirm-MocPlan -Title $title -Body $body -Agreements:$needsAgreement -Destructive:($Action -eq 'uninstall'))) { return }
    $script:WingetPath=Resolve-MocWinget
    $script:Ui.WingetBadge.Text='●  winget · chữ ký hợp lệ'; $script:Ui.WingetBadge.Foreground='#A9B665'
    $script:Queue=New-Object 'System.Collections.Generic.Queue[object]'
    foreach ($plan in $plans) { $script:Queue.Enqueue($plan) }
    $script:Failures=0; $script:Completed=0; $script:Stopped=$false
    $script:Busy=$true; $script:Ui.StopButton.IsEnabled=$true; $script:Ui.Tabs.IsEnabled=$false
    Start-MocNext
}

# [VI] Lấy mục tiếp theo trong hàng đợi để chạy; hết hàng đợi thì mở khóa giao diện và báo tổng kết.
function Start-MocNext {
    if ($script:Queue.Count -eq 0) {
        $script:Busy=$false; $script:Ui.StopButton.IsEnabled=$false; $script:Ui.Tabs.IsEnabled=$true
        $script:Ui.StatusText.Text="●  KẾT THÚC / $($script:Completed) tác vụ trả về · $($script:Failures) cần xem lại"
        if ($script:Stopped) { $script:Ui.StatusText.Text += ' · đã bỏ các mục chờ' }
        Add-MocLog $script:Ui.StatusText.Text; Render-MocApps
        return
    }
    $plan=$script:Queue.Dequeue()
    $script:Ui.StatusText.Text="●  ĐANG CHẠY / $($plan.Action) $($plan.Id) · $($script:Queue.Count) mục chờ"
    Add-MocLog ('$ ' + $plan.Display)
    try { $script:Running=Start-MocProcess -Executable $script:WingetPath -Plan $plan }
    catch {
        $script:Failures++; $script:Queue.Clear(); $script:Running=$null
        Add-MocLog "Không khởi chạy được: $_. Đã dừng hàng đợi."
        Start-MocNext
    }
}

# [VI] Dựng các thẻ tinh chỉnh với nút Áp dụng/Hoàn tác.
function Render-MocTweaks {
    foreach ($tweak in Get-MocTweaks) {
        $id=$tweak.Id
        $border=New-Object Windows.Controls.Border; $border.Background='#262A28'; $border.BorderBrush='#3B4038'; $border.BorderThickness=1; $border.CornerRadius=5; $border.Padding=18; $border.Margin='0,0,10,12'
        $dock=New-Object Windows.Controls.DockPanel
        $buttons=New-Object Windows.Controls.StackPanel; $buttons.Orientation='Horizontal'; $buttons.VerticalAlignment='Center'; $buttons.SetValue([Windows.Controls.DockPanel]::DockProperty,[Windows.Controls.Dock]::Right)
        foreach ($isRestore in @($false,$true)) {
            $label=if ($isRestore) {'Hoàn tác'} else {'Áp dụng'}
            $button=New-MocButton -Text $label -Click ({
                try {
                    $item=Get-MocTweak -Id $id
                    $verb=if ($isRestore) {'Hoàn tác'} else {'Áp dụng'}
                    $state=Get-MocRegistryState -Tweak $item
                    $text="$verb`: $($item.Name)`r`nHKCU\$($item.Path)`r`n$($item.ValueName)`r`nHiện tại: $(if ($state.Exists) {$state.Value} else {'chưa tồn tại'})`r`nGiá trị khi áp dụng: $($item.Value)`r`n`r`n$($item.Description)`r`nHoàn tác phục hồi giá trị gốc từ bản sao riêng cho người dùng/máy này. Không tự khởi động lại Explorer."
                    if (Confirm-MocPlan -Title "$verb tinh chỉnh" -Body $text) { Invoke-MocTweak -Id $id -Restore:$isRestore; Add-MocLog "$verb hoàn tất: $($item.Name)" }
                } catch { Show-MocError $_ }
            }.GetNewClosure())
            [void]$buttons.Children.Add($button)
        }
        [void]$dock.Children.Add($buttons)
        $stack=New-Object Windows.Controls.StackPanel
        [void]$stack.Children.Add((New-MocText -Text $tweak.Name -Size 17))
        $description=New-MocText -Text $tweak.Description -Size 12 -Color '#A6A28F'; $description.Margin='0,8,18,0'; [void]$stack.Children.Add($description)
        [void]$dock.Children.Add($stack); $border.Child=$dock; [void]$script:Ui.TweakCards.Children.Add($border)
    }
}

# [VI] Dựng các thẻ công cụ Windows; công cụ cần quyền quản trị phải xem lệnh và xác nhận trước.
function Render-MocTools {
    foreach ($tool in Get-MocTools) {
        $id=$tool.Id
        $border=New-Object Windows.Controls.Border; $border.Width=365; $border.Height=150; $border.Background='#262A28'; $border.BorderBrush='#3B4038'; $border.BorderThickness=1; $border.CornerRadius=5; $border.Padding=16; $border.Margin='0,0,10,10'
        $stack=New-Object Windows.Controls.StackPanel
        [void]$stack.Children.Add((New-MocText -Text $tool.Name -Size 17))
        $desc=New-MocText -Text $tool.Description -Size 12 -Color '#A6A28F'; $desc.Height=40; $desc.Margin='0,8,0,10'; [void]$stack.Children.Add($desc)
        $label=if ($tool.Admin) {'Xem lệnh & chạy ↗'} else {'Mở công cụ ↗'}
        $button=New-MocButton -Text $label -Click ({
            try {
                $item=Get-MocTools | Where-Object Id -EQ $id
                if ($item.Admin) {
                    $text="$($item.Description)`r`n`r`n$([Environment]::SystemDirectory)\$($item.File) $($item.Args)`r`n`r`nChỉ tiến trình này yêu cầu UAC. Kết quả chi tiết nằm trong cửa sổ Windows và nhật ký CBS/DISM của hệ thống. Nên tạo restore point và sao lưu trước khi sửa. Không có hoàn tác tự động cho sửa chữa hệ thống."
                    if (-not (Confirm-MocPlan -Title $item.Name -Body $text)) { return }
                }
                $proc=Start-MocTool -Id $id
                Add-MocLog "Đã yêu cầu mở: $($item.Name)"
                if ($item.Admin -and $proc) {
                    Watch-MocMaintenance -Process $proc -Id $id -Name $item.Name
                }
            } catch { Show-MocError $_ }
        }.GetNewClosure())
        $button.HorizontalAlignment='Left'; $button.FontSize=12; $button.Padding='10,6'
        [void]$stack.Children.Add($button); $border.Child=$stack; [void]$script:Ui.ToolCards.Children.Add($border)
    }
}

# [VI] Điểm vào giao diện: nạp XAML, gắn sự kiện, khởi động timer; -SmokeTest chạy kiểm thử UI và chụp ảnh rồi đóng.
function Start-MocWindow {
    param([switch]$SmokeTest,[string]$ScreenshotPath)
    $script:Catalog=@(Get-MocCatalog); $script:Selected=@{}; $script:Category='Tất cả'; $script:Busy=$false; $script:Running=$null; $script:Maintenance=$null
    # Single instance per session prevents two windows racing on tweak snapshots.
    # Smoke test không ghi registry/bản sao, nên dùng khóa riêng để chạy được khi người dùng đang mở Mộc.
    $mutexName=if ($SmokeTest) {'Local\MocToolkit-Smoke-v1'} else {'Local\MocToolkit-Desktop-v1'}
    $script:Mutex=New-Object Threading.Mutex($false,$mutexName)
    if (-not $script:Mutex.WaitOne(0)) { $script:Mutex.Dispose(); throw 'Mộc đang mở. Hãy dùng cửa sổ hiện tại.' }
    try {
        $xml=[xml](Get-Content -LiteralPath (Join-Path $PSScriptRoot 'MainWindow.xaml') -Raw -Encoding UTF8)
        $reader=New-Object Xml.XmlNodeReader $xml
        $script:Window=[Windows.Markup.XamlReader]::Load($reader)
        $script:Ui=@{}
        foreach ($name in @('WingetBadge','ThemeButton','Tabs','SearchBox','SearchHint','DevPreset','BasicPreset','ClearSelection','Categories','AppCards','AppsScroll','SelectionLabel','InstallButton','UpgradeButton','UninstallButton','InventoryButton','TweakCards','ToolCards','DocsButton','LogsButton','StatusText','CopyLogButton','StopButton','LogBox','Footer')) { $script:Ui[$name]=$script:Window.FindName($name) }
        $script:Ui.Footer.Text="v0.1.0   /   $([Environment]::OSVersion.Version.Major).$([Environment]::OSVersion.Version.Build)   /   LOCAL SESSION"
        foreach ($category in @('Tất cả') + @($script:Catalog.category | Select-Object -Unique)) {
            $cat=$category
            $button=New-MocButton -Text $cat -Click ({Set-MocCategory -Name $cat}.GetNewClosure())
            $button.FontSize=11; $button.Padding='9,5'; $button.BorderThickness=0
            [void]$script:Ui.Categories.Children.Add($button)
        }
        $script:Ui.SearchBox.Add_TextChanged({Render-MocApps})
        $script:Ui.ClearSelection.Add_Click({$script:Selected.Clear(); Update-MocSelection})
        $script:Ui.DevPreset.Add_Click({foreach ($id in @('Microsoft.VisualStudioCode','Git.Git','OpenJS.NodeJS.LTS','Microsoft.WindowsTerminal')) {$script:Selected[$id]=$true}; Update-MocSelection})
        $script:Ui.BasicPreset.Add_Click({foreach ($id in @('Mozilla.Firefox','7zip.7zip','VideoLAN.VLC','SumatraPDF.SumatraPDF')) {$script:Selected[$id]=$true}; Update-MocSelection})
        $script:Ui.InstallButton.Add_Click({try {Request-MocPackages -Action install -Ids @($script:Selected.Keys)} catch {Show-MocError $_}})
        $script:Ui.UpgradeButton.Add_Click({try {Request-MocPackages -Action upgrade -Ids @($script:Selected.Keys)} catch {Show-MocError $_}})
        $script:Ui.UninstallButton.Add_Click({try {Request-MocPackages -Action uninstall -Ids @($script:Selected.Keys)} catch {Show-MocError $_}})
        $script:Ui.InventoryButton.Add_Click({try {Request-MocPackages -Action list} catch {Show-MocError $_}})
        $script:Ui.StopButton.Add_Click({if ($script:Busy -and $script:Running) {$script:Queue.Clear(); $script:Stopped=$true; $script:Ui.StopButton.IsEnabled=$false; Add-MocLog 'Đã bỏ các mục chờ. Chờ installer hiện tại hoàn tất; không buộc dừng để tránh hỏng cài đặt.'}})
        $script:Ui.CopyLogButton.Add_Click({try {[Windows.Clipboard]::SetText($script:Ui.LogBox.Text)} catch {Show-MocError $_}})
        $script:Ui.DocsButton.Add_Click({try {Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'explorer.exe') -ArgumentList ('"' + (Join-Path $script:ProjectRoot 'docs') + '"')} catch {Show-MocError $_}})
        $script:Ui.LogsButton.Add_Click({try {[void](New-Item -ItemType Directory -Path $script:StateRoot -Force); Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'explorer.exe') -ArgumentList ('"' + $script:StateRoot + '"')} catch {Show-MocError $_}})
        $script:AlternateTheme=$false
        $script:Ui.ThemeButton.Add_Click({
            $script:AlternateTheme=-not $script:AlternateTheme
            $script:Window.Background=if ($script:AlternateTheme) {'#182629'} else {'#1D2021'}
            $script:Ui.Tabs.Background=$script:Window.Background
            $script:Ui.ThemeButton.Content=if ($script:AlternateTheme) {'◐  Jade'} else {'◐  Gruvbox'}
        })
        $script:Window.Add_PreviewKeyDown({param($sender,$e) if ($e.Key -eq 'F' -and ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control)) {$script:Ui.Tabs.SelectedIndex=0; [void]$script:Ui.SearchBox.Focus(); $e.Handled=$true}})
        $script:Window.Add_Closing({param($sender,$e) if ($script:Busy) {$e.Cancel=$true; Add-MocLog 'Tác vụ đang chạy. Hãy dừng hàng đợi và chờ tiến trình hiện tại hoàn tất trước khi đóng.'}})
        Render-MocApps; Render-MocTweaks; Render-MocTools
        $script:Timer=New-Object Windows.Threading.DispatcherTimer
        $script:Timer.Interval=[TimeSpan]::FromMilliseconds(400)
        $script:Timer.Add_Tick({
            try {
                if ($script:Maintenance -and $script:Maintenance.Process.HasExited) {
                    $exitCode=$script:Maintenance.Process.ExitCode
                    Write-MocAudit -Event 'tool-exit' -Detail @{id=$script:Maintenance.Id; code=$exitCode}
                    Add-MocLog "Công cụ Windows kết thúc: exit $exitCode. Xem CBS.log/DISM.log để biết kết quả chi tiết."
                    $script:Maintenance.Process.Dispose(); $script:Maintenance=$null; $script:Busy=$false; $script:Ui.Tabs.IsEnabled=$true; $script:Ui.StatusText.Text='●  CÔNG CỤ ĐÃ KẾT THÚC / xem nhật ký Windows'
                }
                if (-not $script:Running) { return }
                $job=$script:Running
                $seconds=[int]((Get-Date)-$job.Started).TotalSeconds
                $script:Ui.StatusText.Text="●  ĐANG CHẠY / $($job.Plan.Id) · ${seconds}s · $($script:Queue.Count) mục chờ"
                if (-not $job.Process.HasExited -or -not $job.Output.IsCompleted -or -not $job.Error.IsCompleted) { return }
                $code=$job.Process.ExitCode
                $output=$job.Output.GetAwaiter().GetResult(); $err=$job.Error.GetAwaiter().GetResult()
                # Remove ANSI control sequences and spinner backspaces for a readable log.
                $output=[regex]::Replace($output, '\x1B\[[0-?]*[ -/]*[@-~]', '') -replace "`b",''
                if ($output) { Add-MocLog $output.Trim() }; if ($err) { Add-MocLog $err.Trim() }
                Add-MocLog (Get-MocExitDescription -Code $code)
                Write-MocAudit -Event 'process-exit' -Detail @{id=$job.Plan.Id; action=$job.Plan.Action; code=$code}
                $script:Completed++
                if (-not (Test-MocExitBenign -Code $code)) { $script:Failures++; $script:Queue.Clear(); Add-MocLog 'Đã dừng các mục tiếp theo để bạn kiểm tra kết quả trước.' }
                $job.Process.Dispose(); $script:Running=$null
                Start-MocNext
            } catch {
                # If logging fails after a process exits, never leave the UI stuck busy.
                Add-MocLog "Lỗi giám sát: $_"
                if ($script:Running -and $script:Running.Process.HasExited) { $script:Running.Process.Dispose(); $script:Running=$null; $script:Queue.Clear(); $script:Failures++; Start-MocNext }
                if ($script:Maintenance -and $script:Maintenance.Process.HasExited) { $script:Maintenance.Process.Dispose(); $script:Maintenance=$null; $script:Busy=$false; $script:Ui.Tabs.IsEnabled=$true }
            }
        })
        $script:Timer.Start()
        if ($SmokeTest) {
            # UI smoke runs entirely locally. No process, registry, network or audit writes.
            $script:Window.Show(); $script:Window.UpdateLayout()
            $script:Ui.Categories.Children[1].RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
            if ($script:Ui.AppCards.Children.Count -ne 4) { throw 'Category smoke failed.' }
            $script:Ui.Categories.Children[0].RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
            $script:CardChecks[0].IsChecked=$true
            $script:CardChecks[0].RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
            if ($script:Selected.Count -ne 1) { throw 'Selection smoke failed.' }
            $script:Ui.ClearSelection.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
            [void](Confirm-MocPlan -Title 'Test' -Body 'No operation' -Agreements -TestOnly)
            [void](Confirm-MocPlan -Title 'Test' -Body 'No operation' -Destructive -TestOnly)
            $script:Ui.SearchBox.Text='firefox'; $script:Window.UpdateLayout()
            if ($script:Ui.AppCards.Children.Count -ne 1) { throw 'Search smoke failed.' }
            $script:Ui.SearchBox.Text=''; $script:Ui.DevPreset.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
            if ($script:Selected.Count -ne 4) { throw 'Preset smoke failed.' }
            $script:Ui.ClearSelection.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
            if ($script:Selected.Count -ne 0) { throw 'Clear selection smoke failed.' }
            foreach ($index in @(1,2,3,0)) {$script:Ui.Tabs.SelectedIndex=$index; $script:Window.UpdateLayout()}
            $script:Window.UpdateLayout()
            $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$script:Window.ActualWidth,[int]$script:Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
            $bitmap.Render($script:Window)
            $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder; $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $parent=Split-Path $ScreenshotPath -Parent; [void](New-Item -ItemType Directory -Path $parent -Force)
            $stream=[IO.File]::Create($ScreenshotPath); try {$encoder.Save($stream)} finally {$stream.Dispose()}
            $script:Window.Close()
            Write-Output "UI smoke PASS: $($script:Catalog.Count) apps, search, presets, 4 tabs. Screenshot: $ScreenshotPath"
        } else { [void]$script:Window.ShowDialog() }
    } finally {
        if (Get-Variable Timer -Scope Script -ErrorAction SilentlyContinue) { $script:Timer.Stop() }
        $script:Mutex.ReleaseMutex(); $script:Mutex.Dispose()
    }
}

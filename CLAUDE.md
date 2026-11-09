# Claude Code — Mộc Toolkit

Đọc `AGENTS.md` trước. Tệp này bổ sung bối cảnh để tiếp tục dự án mà không cần cuộc trò chuyện gốc.

## Ý định người dùng

Người dùng muốn toolkit Windows giống nhóm chức năng của Chris Titus WinUtil, giao diện cảm hứng Omarchy, hỗ trợ winget và mở phần mềm. Ưu tiên an toàn và ghi chú đầy đủ. Tên tạm: **Mộc**. Không có yêu cầu sao chép WinUtil, thương hiệu hay chạy lệnh `irm ... | iex` trên máy thật.

## Stack và điểm bắt đầu

- `Start-Moc.ps1`: entrypoint, tải assembly WPF rồi dot-source Core/Tweaks/UI.
- `src/MainWindow.xaml`: layout + styles; `src/UI.ps1`: dựng card, dialog, event, timer và queue.
- `src/Core.ps1`: catalog, lập kế hoạch winget, xác minh executable/source, process runner, launch và tools.
- `src/Tweaks.ps1`: registry adapter, snapshot, rollback, read-back.
- `data/apps.json`: dữ liệu thuần, không chứa script hay lệnh.
- `launcher/MocLauncher.cs`: EXE launcher asInvoker, không phải backend.
- `tests/Run-Tests.ps1`: test offline, mock registry; `scripts/Test.ps1 -IncludeUI`: thêm smoke WPF.

## Những việc dễ làm sai

1. PowerShell 7 trong terminal agent **không phải** runtime target; luôn kiểm tra lại bằng Windows PowerShell 5.1.
2. `ConvertFrom-Json` có hành vi enumerate array khác nhau theo phiên bản. Không bọc pipeline đầu vào bằng `@(...)` rồi giả định từng phần tử là app.
3. `GetNewClosure()` tạo module động: `$script:` trong closure có thể trỏ sai scope. Gọi helper để đổi state.
4. `.NET Framework` chưa có `ProcessStartInfo.ArgumentList`. Chỉ nối các token ASCII đã whitelist; không mở rộng thành chuỗi tự do.
5. Không parse bảng `winget list` để suy ra trạng thái cài đặt: đầu ra phụ thuộc locale. Hiện chỉ trình bày nguyên văn.
6. Snapshot có giá trị ban đầu **không tồn tại** phải restore bằng xóa value, không ghi 0. Không xóa cả registry key.
7. Không kill installer khi “Dừng hàng đợi”. Hai pipe stdout/stderr phải được đọc đồng thời.
8. `Moc.exe` chưa ký. SHA256SUMS chỉ giúp đối chiếu nội dung; không chứng minh nhà phát hành khi checksum đi cùng gói tải xuống.

## Lệnh thường dùng

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Test.ps1 -IncludeUI
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Build.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Check-Environment.ps1
```

`Verify-Catalog.ps1` là truy vấn online chỉ đọc, không phải kiểm thử installer. Xem `docs/TESTING.md` để biết bằng chứng thực tế. Không chạy SFC/DISM/installer hoặc tinh chỉnh thật chỉ để “test nhanh”.

## Hướng phát triển

Theo `docs/HANDOFF.md`: ưu tiên máy ảo Windows sạch và integration tests, ký release, process output streaming có giới hạn bộ nhớ, accessibility/DPI, launcher cho nhiều ứng dụng hơn. Mỗi chức năng có tác động hệ thống cần mô tả rủi ro, xem trước và phương án phục hồi phù hợp.

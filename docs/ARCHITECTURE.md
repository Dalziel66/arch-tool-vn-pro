# Kiến trúc

## Các lớp

```text
Moc.exe / Start-Moc.cmd       asInvoker; PowerShell 5.1, STA, no profile
         |
Start-Moc.ps1                WPF assemblies + local source files
         |
UI.ps1 + MainWindow.xaml     search / cards / consent / queue / timer
         |
         +-- Core.ps1        pure plan -> signature/source checks -> process
         +-- Tweaks.ps1      fixed tweak -> snapshot -> registry -> verification
         +-- apps.json       data only; validated IDs and display fields
```

Không có HTTP server, webview, Electron, remote JS, npm dependency hay credential store. WPF có sẵn trên Windows. Launch source trực tiếp không cần build; C# launcher chỉ đóng gói trải nghiệm mở cửa sổ.

## Winget

`New-MocWingetPlan` chỉ nhận action trong allowlist và ID đúng nguyên dạng trong catalog. Arguments chứa token ASCII không khoảng trắng/quote. Dữ liệu tìm kiếm, tên hoặc mô tả không đi vào command line. `install` có `--no-upgrade`; `upgrade` chỉ gói đã chọn, không có `--all`. Gỡ dùng UI của uninstaller. Các nguồn khác như msstore không được chọn tự động.

UI dựng kế hoạch, hiển thị lệnh/tác động, yêu cầu checkbox đồng ý. Gỡ cần thêm đúng `GO`. Sau đó resolver tìm App Installer bằng `Get-AppxPackage`, lấy executable trong package và xác nhận Authenticode của Microsoft. Không tra PATH.

Mỗi lần thực thi, runner tái dựng và so sánh arguments rồi kiểm tra executable, chạy `source export --name winget` và kiểm tra Name, URL, Type, Identifier. Nếu không khớp hoặc không đọc được thì dừng. Preflight source có giới hạn 10 giây, chạy đồng bộ trước installer nên có thể làm UI tạm ngừng phản hồi. Chỉ tiến trình đọc metadata này được phép kill khi timeout.

Installer chạy bằng `ProcessStartInfo.UseShellExecute=false`, hai stream đọc async. `DispatcherTimer` 400ms cập nhật thời gian chờ và thu output sau khi process kết thúc. Đây là **output sau hoàn tất**, chưa phải streaming từng dòng. Queue chạy tuần tự. Exit khác 0 dừng toàn bộ phần còn lại để kiểm tra, kể cả trường hợp cần reboot hoặc không có update; không giả định mọi nonzero là thành công.

`ReadToEndAsync` tránh deadlock pipe nhưng giữ toàn bộ output trong bộ nhớ tới khi xong; log UI được cắt bớt ở các lần thêm log tiếp theo. Đây là giới hạn đã biết, cần bounded streaming cho bản lớn hơn. Audit chỉ lưu command/exit/sự kiện, không lưu full stdout tự động. Người dùng có thể Sao chép output từ UI.

## Tinh chỉnh

ID ánh xạ sang 3 cặp key/value cố định trong HKCU. Chỉ hỗ trợ DWORD, từ chối type khác. `Get-MocRegistryState` và `Set-MocRegistryState` là seam để mock trong tests.

Apply: đọc original -> `CreateNew` snapshot -> flush xuống đĩa -> audit start -> ghi -> read-back -> audit complete. Lỗi ở bước nào được báo, snapshot được giữ. Apply lại bị chặn tới khi restore xong.

Restore: validate schema/ID/SID/machine/type/range -> xác nhận current còn bằng giá trị Mộc áp dụng -> khôi phục existence/value gốc -> read-back -> audit -> archive snapshot. Không dùng đường dẫn/value name từ JSON. Không xóa cả key khi value ban đầu không tồn tại. Registry không có giao dịch nguyên tử với file backup; xem hướng phục hồi trong SECURITY.md.

Mutex theo session chặn hai giao diện đồng thời. Không bảo vệ trước công cụ khác, mã chạy cùng user hoặc session khác; restore có kiểm tra thay đổi ngoài nhưng không chống mọi race.

## Công cụ / mở phần mềm

System tools có ID, executable/URI và arguments cố định trong source. SFC/DISM dùng `runas` của Windows riêng từng tiến trình; UI không chạy admin mặc định. App thường mở bằng fixed candidate path + Authenticode Valid; chưa pin publisher theo từng ứng dụng.

Không có dịch vụ nền. Cửa sổ ngăn đóng khi đang có installer hoặc maintenance process được theo dõi. Với Settings/Task Manager, chỉ yêu cầu mở rồi trả quyền điều khiển cho Windows.

## State trên đĩa

```text
%LOCALAPPDATA%/MocToolkit/
  audit-YYYY-MM.jsonl
  backups/extensions.json
  backups/dark.json
  backups/transparency.json
  backups/*.restored-<guid>.json
```

Không ghi vào thư mục cài ứng dụng lúc chạy bình thường. Test/build ghi vào `artifacts/`, `dist/`. Audit/backup dùng ACL kế thừa từ profile, không mã hóa, không chống sửa bởi cùng user/admin. Không có auto-cleanup.

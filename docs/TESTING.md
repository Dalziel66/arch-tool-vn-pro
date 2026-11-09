# Kiểm thử — 09/11/2026

## Đã xác minh

Môi trường kiểm tra thực tế: Windows build `10.0.26300.0`, Windows PowerShell `5.1.26100.9711`, winget `1.29.380`. Không giả định các nền tảng khác đã được kiểm thử.

| Hạng mục | Kết quả / phạm vi |
| --- | --- |
| Parser PowerShell | Parse toàn bộ script trước khi chạy tests |
| Offline core | 44 kiểm tra pass; toàn bộ 36×4 tổ hợp catalog/action tạo được token an toàn |
| Lệnh không hợp lệ | ID lạ, sai case, injection, whitespace, ID rỗng, plan thêm flag bị từ chối |
| Consent | Install/upgrade thiếu đồng ý bị chặn; gỡ cần interactive, không purge |
| Source | JSON nguồn Microsoft được chấp nhận; URL khác, HTTP, type khác, thiếu metadata bị chặn |
| Backup/restore | Mock registry: snapshot trước write, original không bị ghi đè, restore value/existence, conflict, SID/ID/type/range sai, write failure giữ snapshot |
| Audit | JSONL parse được và có event bắt đầu |
| WPF smoke | Load XAML, 36 card, search, category, chọn checkbox, preset, bỏ chọn, 4 tab, consent và GO, xuất PNG |
| Môi trường winget thật | Resolver xác minh Authenticode Microsoft; source export đúng nguồn chính thức |
| Metadata online | Cả 36 ID trả `exit 0` từ `winget show --id ... --exact --source winget`; không chạy installer |
| Bản đóng gói | `Moc.exe --smoke-test` trả exit 0; 44 core checks pass từ thư mục portable; 26 checksum file khớp |

Ảnh UI: `artifacts/moc-preview.png`. Báo cáo metadata đầy đủ: `artifacts/catalog-validation/report.json`. Các artifact này không nằm trong ZIP mặc định vì có thông tin môi trường/log; core docs đi kèm ZIP.

Sandbox mặc định chặn `Get-AppxPackage`/WindowsApps. Kiểm tra môi trường và metadata đã được chạy ngoài sandbox với quyền truy cập được duyệt; không cần nâng quyền GUI và không đổi nguồn winget. Không cài/gỡ gói, không sửa registry thật hoặc chạy repair để thử.

## Lặp lại

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Test.ps1 -IncludeUI
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Check-Environment.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Verify-Catalog.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Build.ps1
.\dist\MocToolkit-0.1.0\Moc.exe --smoke-test
```

`--smoke-test` mở WPF trong thời gian ngắn, test các tương tác không thay đổi hệ thống, xuất `artifacts/moc-preview.png` cạnh executable rồi đóng. Chạy khi chưa có cửa sổ Mộc khác vì single-instance mutex.

## Chưa xác minh và matrix cần làm trong VM

- Install/upgrade/uninstall thật, user scope/machine scope, installer unsigned, UAC chấp nhận/hủy, package cần dependencies hoặc reboot.
- Thay đổi registry thật và rollback thật, crash giữa snapshot/write/audit, quota/disk-full/ACL denial, trạng thái value do ứng dụng khác đổi đồng thời.
- SFC/DISM thực tế và các loại exit code; nguồn repair Windows Update, mạng hạn chế.
- Windows 10, Windows ARM64, Windows Server, profile/domain policies, language khác, DPI 125–200%, keyboard/screen-reader, 1366×768.
- Chữ ký phát hành/SmartScreen reputation. EXE/scripts hiện là development unsigned.

Các test hiện tại chứng minh logic và wiring UI trong phạm vi trên; không chứng minh installer của bên thứ ba an toàn, mọi máy đều hỗ trợ hoặc toàn bộ thao tác hệ thống luôn hoàn tác được.

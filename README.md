# Mộc — Windows Toolkit

Ứng dụng desktop Windows lấy cảm hứng từ phong cách terminal, màu Gruvbox/Jade của Omarchy và cách gom công cụ của Chris Titus WinUtil. Đây là triển khai độc lập, không sao chép mã hay tài sản thương hiệu của hai dự án.

**Bản 0.1.0:** PowerShell 5.1 + WPF, giao diện tiếng Việt, không cần Node, Python, .NET SDK hay thư viện tải ngoài. Launcher C# dùng .NET Framework có sẵn của Windows. Đây là bản đầu có thể chạy, chưa tương đương toàn bộ WinUtil và chưa phải sản phẩm đã được kiểm toán bảo mật độc lập.

## Mở ứng dụng

### Chạy nhanh bằng `irm` (từ CMD)

```bat
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=3072; irm https://github.com/OWNER/REPO/releases/latest/download/install.ps1 | iex"
```

`install.ps1` chỉ tải đúng `MocToolkit-0.1.0.zip` của release, **so SHA256 đã ghim sẵn**, giải nén vào `%LOCALAPPDATA%\MocToolkit\app\0.1.0` rồi mở Mộc bằng tài khoản thường. Hash sai thì dừng, không giải nén hay chạy gì. Chạy lại lệnh để cài lại; audit/bản sao tinh chỉnh không bị đụng tới.

Phát hành: `scripts\Build.ps1 -Repo OWNER/REPO` sinh `dist\install.ps1`. Tạo GitHub Release tag `v0.1.0`, đính kèm **cả** `MocToolkit-0.1.0.zip` và `install.ps1`. Build lại zip thì phải tải lên cả hai (hash thay đổi). Lưu ý: `irm | iex` tin tưởng tài khoản GitHub chứa release; hash chỉ bảo vệ zip, không bảo vệ chính `install.ps1`.

- Trong thư mục nguồn: nhấp đúp **`Start-Moc.cmd`**.
- Bản portable: giải nén **`dist/MocToolkit-0.1.0.zip`**, mở **`Moc.exe`** trong thư mục giải nén. Giữ nguyên `src`, `data`, `Start-Moc.ps1` bên cạnh EXE.
- Khởi chạy bằng tài khoản thường. Chỉ installer hoặc công cụ hệ thống cần quyền cao mới yêu cầu UAC.
- Mộc dùng App Installer/winget đã cài từ Microsoft Store. Ứng dụng vẫn mở được khi thiếu winget; thao tác gói sẽ báo lỗi rõ ràng.

Launcher chỉ đặt `RemoteSigned` cho **tiến trình PowerShell con**; không ghi ExecutionPolicy toàn máy hay tài khoản, không dùng `Bypass`. Group Policy của tổ chức vẫn có ưu tiên. Bản phát triển chưa ký Authenticode: tệp tải từ Internet có thể bị Windows chặn. Đọc [hướng dẫn xử lý](docs/USER-GUIDE.md), không tắt SmartScreen hoặc chính sách tổ chức để chạy.

Mục tiêu hỗ trợ: Windows 11 x64; có thể chạy Windows 10 có WPF/PowerShell 5.1 và winget phù hợp nhưng chưa kiểm thử trên Windows 10, ARM64, Server hay môi trường doanh nghiệp.

## Có những gì?

| Nhóm | Chức năng |
| --- | --- |
| Ứng dụng | 36 gói; tìm kiếm tên/ID/nhóm; bộ cơ bản/lập trình; chọn nhiều gói |
| Winget | Xem thông tin, cài, cập nhật từng gói đã chọn, gỡ với xác nhận bổ sung, xem danh sách đã cài |
| Mở phần mềm | Nhận diện một số đường dẫn chuẩn; chỉ mở trực tiếp EXE có chữ ký hợp lệ |
| Tinh chỉnh | Hiện đuôi tệp, dark mode cho ứng dụng, giảm transparency; bản sao và hoàn tác HKCU |
| Windows | Update, Storage, Startup, Installed apps, Task Manager, System Protection, SFC, DISM |
| An toàn | Xem trước lệnh; kiểm tra chữ ký winget và URL/identity nguồn; hạn chế tham số; nhật ký JSONL |

Nút “Mở” chưa hỗ trợ mọi gói, ứng dụng CLI, cài đặt tùy chỉnh hoặc bản Store. Nút mờ **không đồng nghĩa** ứng dụng chưa được cài. Dùng “Xem máy đã cài gì” hoặc Start Menu. Các gói có thể đổi phiên bản/ID theo thời gian.

## Nguyên tắc

- Bên trong Mộc không tải script về rồi thực thi bằng `iex`, không tự cập nhật. Lệnh `irm` ở trên là tùy chọn khởi động do người dùng tự chạy, có kiểm tra SHA256.
- Không tắt Defender, Firewall, UAC, Windows Update; không “debloat tất cả”, chỉnh dịch vụ hàng loạt, xóa dữ liệu hoặc bypass kiểm tra hash.
- Không tự nâng quyền cả giao diện, không tự khởi động lại máy.
- Lệnh gói dùng `--id ... --exact --source winget`; không nhận lệnh shell do người dùng nhập.
- Dừng hàng đợi chỉ bỏ các mục **chưa chạy**. Đợi installer hiện tại xong; không kill installer.
- Bản sao tinh chỉnh không phải backup toàn hệ thống. Cài/gỡ/cập nhật ứng dụng và SFC/DISM không có hoàn tác tự động.
- Không có bảo đảm an toàn tuyệt đối: installer bên thứ ba vẫn có quyền/tác động riêng. Xem [SECURITY.md](docs/SECURITY.md).

## Phát triển và kiểm thử

Chạy từ PowerShell tại thư mục dự án:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Test.ps1 -IncludeUI
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Build.ps1
```

Kiểm tra môi trường / metadata thực tế, không cài đặt:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Check-Environment.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Verify-Catalog.ps1
```

`Test.ps1` dùng registry giả trong bộ nhớ. Chỉ ghi kết quả thử trong `artifacts/`; UI smoke không chạy package hoặc công cụ Windows. `Verify-Catalog.ps1` truy cập mạng qua winget và có thể làm mới cache nguồn.

## Tài liệu

- [Hướng dẫn sử dụng và xử lý lỗi](docs/USER-GUIDE.md)
- [Mô hình an toàn, giới hạn, phục hồi](docs/SECURITY.md)
- [Kiến trúc và luồng thực thi](docs/ARCHITECTURE.md)
- [Hướng dẫn đóng góp và mở rộng](docs/DEVELOPMENT.md)
- [Báo cáo kiểm thử](docs/TESTING.md)
- [Bàn giao và việc tiếp theo](docs/HANDOFF.md)
- [Chỉ dẫn cho Claude Code](CLAUDE.md), [quy ước chung cho coding agents](AGENTS.md)

## Nguồn tham khảo

Đã tham khảo ngày 09/11/2026:

- [Omarchy](https://omarchy.org/) — cảm hứng giao diện và bảng màu.
- [Chris Titus WinUtil](https://github.com/ChrisTitusTech/winutil) — tham khảo nhóm chức năng.
- Microsoft: [install](https://learn.microsoft.com/en-us/windows/package-manager/winget/install), [upgrade](https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade), [uninstall](https://learn.microsoft.com/en-us/windows/package-manager/winget/uninstall), [show](https://learn.microsoft.com/en-us/windows/package-manager/winget/show), [list](https://learn.microsoft.com/en-us/windows/package-manager/winget/list), [source](https://learn.microsoft.com/en-us/windows/package-manager/winget/source).
- Microsoft: [Repair a Windows image](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image?view=windows-11).

Mã Mộc phát hành theo MIT. Phần mềm bên thứ ba có giấy phép riêng; việc xuất hiện trong danh mục không phải chứng nhận an toàn hay quyền phân phối lại installer.

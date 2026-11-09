# Phát triển và đóng gói

## Môi trường

Windows PowerShell 5.1 x64 + WPF là runtime chuẩn. Không cần cài Pester, Node hoặc SDK. `scripts/Build.ps1` dùng C# compiler của .NET Framework nằm trong Windows. Giữ mã tương thích 5.1: không dùng toán tử `??`, ternary của PS7 hoặc API .NET mới.

`.ps1` phải UTF-8 BOM vì Windows PowerShell 5.1 có thể đọc sai tiếng Việt nếu không có BOM. JSON/XAML/Markdown dùng UTF-8. Các hàm event nên nhỏ, xử lý lỗi rõ; không để lỗi nuốt im lặng.

## Thêm ứng dụng

1. Xác minh ID từ nguồn winget chính thức bằng `winget show --id <ID> --exact --source winget`.
2. Thêm record `id`, `name`, `category`, `description`, `mark`, `color` vào `data/apps.json`; không thêm command, script hoặc đường dẫn người dùng vào catalog.
3. Mô tả rõ yêu cầu giấy phép, tài khoản, ảo hóa hoặc nguy cơ xóa dữ liệu nếu liên quan.
4. Nếu cần nút Mở, thêm vị trí cố định trong `Get-MocLaunchPath`. Không đọc Shell\Open\Command rồi thực thi, không tìm PATH hoặc đoán `%TEMP%`.
5. Cập nhật số lượng dự kiến trong tests/docs; chạy core tests, UI và xác minh metadata cho ID mới.

Danh mục không đồng nghĩa phần mềm đã được kiểm toán an toàn. Chức năng Mở kiểm tra chữ ký Valid; gói unsigned có thể cài bình thường qua winget nhưng không được mở trực tiếp từ Mộc.

## Thêm tinh chỉnh

Ưu tiên thao tác reversible ít tác động. Hiện chỉ hỗ trợ một DWORD HKCU cho mỗi ID. Tinh chỉnh nhiều value, HKLM, services hoặc driver cần thiết kế mới về quyền, snapshot giao dịch/partial failure và rollback; không nhét vào adapter hiện có.

Mỗi tweak cần: mục đích dễ hiểu, key/value cố định, giá trị mong muốn, yêu cầu đăng nhập lại/reboot, đọc trạng thái gốc, backup existence/type/value, kiểm tra sau ghi, kiểm thử failure và rollback. Không dùng default đoán làm giá trị hoàn tác.

## Thêm công cụ

Giữ mapping ID → executable trong SystemDirectory + arguments cố định trong source. Tách quét và sửa. Tool cần admin phải dùng runas chỉ cho tiến trình đó; review text phải nói tác động và giới hạn khôi phục. Không cho nhập raw argument hoặc command trong UI.

## Test và build

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Test.ps1 -IncludeUI
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Build.ps1
```

Build xuất thư mục portable, EXE, ZIP và SHA256SUMS. Nó tạo staging mới `dist/.build-<guid>/MocToolkit-0.1.0`, copy danh sách explicit và chỉ ZIP staging này để không thu secrets/artifacts hoặc file thừa từ lần chạy trước. Staging giữ lại để xem xét, không tự xóa. Bản tiện dùng ở `dist/MocToolkit-0.1.0` được cập nhật nhưng có thể giữ test artifacts cũ; bản ZIP luôn lấy từ staging mới. Không có signing key trong repo. Không xóa thư mục bằng đường dẫn tính toán chưa kiểm chứng.

Không thiết lập pipeline tải script và tự chạy trên máy người dùng. Nếu sau này muốn cài Mộc qua winget: cần release HTTPS ổn định, version, installer/portable metadata, SHA256 chính xác, publisher/license và quy trình submit manifest upstream. Bản này **hỗ trợ dùng winget cài ứng dụng**, chưa được đăng ký chính Mộc trên winget.

## Release gate

Trước khi phân phối rộng: chạy matrix VM trong TESTING.md, xem lại source/config, kiểm tra package IDs, ký Authenticode, xác minh chữ ký sau packaging, công bố hash qua kênh riêng tin cậy và cập nhật changelog. Không gắn nhãn “an toàn tuyệt đối” hoặc “fully tested” dựa vào unit tests.

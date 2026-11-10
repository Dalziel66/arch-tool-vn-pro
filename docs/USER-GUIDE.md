# Hướng dẫn sử dụng

## Bắt đầu

Mở `Start-Moc.cmd` ở thư mục nguồn, hoặc `Moc.exe` trong gói portable đã giải nén. Không cần mở terminal Administrator. Nếu chỉ tải riêng EXE, chương trình không chạy vì cần các file source/data cạnh nó.

Trong tab Ứng dụng, chọn từng gói hoặc Bộ cơ bản/Bộ lập trình. Preset chỉ **thêm lựa chọn**, không cài và không bỏ các lựa chọn trước đó. Chọn Bỏ chọn để xóa toàn bộ. Tìm kiếm hỗ trợ tên/ID/nhóm, Ctrl+F đưa focus vào ô tìm.

## Cài, cập nhật và gỡ

1. Nút Thông tin truy vấn `winget show`: đọc publisher, version, license và thông tin installer trong output.
2. Chọn gói, bấm Cài đặt/Cập nhật/Gỡ cài đặt.
3. Đọc lệnh đầy đủ và tác động trong cửa sổ xem trước. Chấp nhận điều khoản gói/nguồn khi phù hợp.
4. Gỡ cài đặt cần nhập đúng `GO` và checkbox.
5. Theo dõi trạng thái. Installer có thể hiện cửa sổ riêng hoặc UAC; phản hồi trực tiếp trong cửa sổ đó.

Mộc không ép silent install. Danh sách cập nhật chỉ gồm gói bạn đã chọn; không update toàn máy. Cài có `--no-upgrade`, cập nhật dùng nút riêng. Phiên bản cụ thể do winget xác định tại thời điểm chạy; bản này chưa pin version hay export/import preset người dùng.

Output winget xuất hiện sau khi tác vụ kết thúc. Trong lúc chạy, UI hiện package, thời gian và số mục chờ. “Dừng hàng đợi” bỏ các mục chưa chạy; không hủy installer hiện tại. Nếu installer treo hoặc đợi UAC, xử lý cửa sổ installer; không buộc tắt Mộc trong Task Manager trừ khi chấp nhận nguy cơ cài dở.

Exit khác 0 dừng hàng đợi, trừ “đã cài sẵn” và “không có bản cập nhật”: hai trường hợp này được ghi lại rồi chạy tiếp. “Cần reboot” và mã lạ vẫn dừng để xem lại; không xem các mục còn lại là đã hoàn tất. Nếu winget đã thoát mà ứng dụng vừa cài còn giữ đầu ra, Mộc chờ 5 giây rồi chạy tiếp và không hiện phần đầu ra đó. Sao chép nhật ký nếu cần giữ toàn bộ output; audit trên đĩa chỉ lưu sự kiện/lệnh/exit.

“Xem máy đã cài gì” hiển thị output nguyên văn từ winget. Không suy diễn cài đặt từ nút Mở: nút này chỉ nhận biết một số vị trí chuẩn; tệp còn phải có chữ ký hợp lệ mới được mở.

## Tinh chỉnh

Ba tinh chỉnh áp dụng cho tài khoản đang chạy ứng dụng. Xem đường dẫn registry và giá trị trước khi xác nhận. Snapshot ghi ở `%LOCALAPPDATA%\MocToolkit\backups`. Hoàn tác dùng giá trị gốc đã lưu, không dùng “mặc định phỏng đoán”.

Nếu báo “đã có bản sao”, hãy hoàn tác trước khi áp dụng lại. Nếu báo giá trị thay đổi bên ngoài, xem [SECURITY.md](SECURITY.md); Mộc không tự ghi đè thay đổi của công cụ khác. Các thay đổi giao diện có thể cần mở lại Explorer/ứng dụng hoặc đăng nhập lại. Mộc không tự restart Explorer.

## Bảo trì Windows

- System Protection mở cửa sổ Windows để bạn tạo restore point nếu muốn. Trạng thái protection do Windows quản lý.
- SFC `/verifyonly` kiểm tra, `/scannow` kiểm tra và sửa.
- DISM `/ScanHealth` quét component store; `/RestoreHealth` có thể dùng Windows Update làm nguồn sửa chữa.
- Cần quyền cao thì Windows hỏi UAC cho tiến trình đó. Nếu hủy, Mộc báo lỗi khởi chạy, không giả báo thành công.
- Công cụ mở cửa sổ riêng. Mộc ghi exit code; kết quả chi tiết xem `%WINDIR%\Logs\CBS\CBS.log` và `%WINDIR%\Logs\DISM\dism.log`. Một exit code không thay thế chẩn đoán log.

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Thiếu winget/App Installer | Cài hoặc cập nhật App Installer từ Microsoft Store; mở lại Mộc |
| Chữ ký winget không hợp lệ | Dừng dùng, kiểm tra App Installer; không bỏ kiểm tra chữ ký để chạy |
| Nguồn winget không khớp | Kiểm tra `winget source list` trong terminal; Mộc không tự reset/ghi đè nguồn |
| `Get-AppxPackage: Access denied` trong sandbox | Chạy kiểm tra chỉ đọc ngoài sandbox với quyền truy cập phù hợp; không cần nâng toàn GUI lên admin |
| Nguồn yêu cầu điều khoản | Dùng Thông tin và xác nhận nguồn hoặc đọc hướng dẫn winget; không tự bypass |
| Không có bản cập nhật | Gói có thể đang mới nhất hoặc winget không có upgrade áp dụng; xem output |
| `running scripts is disabled` | Dùng launcher có RemoteSigned cho tiến trình; nếu tổ chức chặn bằng Group Policy, tuân thủ chính sách |
| File tải từ Internet bị chặn | Xác minh nguồn/checksum từ kênh tin cậy, đọc code; chỉ dùng Properties → Unblock cho **đúng file** sau khi tin cậy. Không unblock đệ quy một thư mục tải xuống lẫn lộn |
| SmartScreen báo publisher lạ | Bản này chưa ký; chưa thích hợp phân phối rộng. Không vô hiệu hóa SmartScreen |
| Tác vụ không kết thúc | Kiểm tra UAC/installer đang đợi nhập; Mộc không kill installer |

## Gỡ Mộc

Đóng sau khi tác vụ hoàn tất. Hoàn tác các tweak nếu muốn, lưu backup/log cần giữ, rồi xóa **riêng thư mục portable**. Mộc không cài service/task nền. Thư mục `%LOCALAPPDATA%\MocToolkit` không tự xóa; giữ lại nếu cần phục hồi. Gỡ Mộc không gỡ các ứng dụng bạn đã cài qua winget.

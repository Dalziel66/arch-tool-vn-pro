# An toàn và giới hạn

Không có “an toàn tuyệt đối”. Mục tiêu của Mộc là giảm thay đổi không rõ tác động, không thực thi dữ liệu như mã và dừng khi không xác minh được. Bản 0.1.0 chưa được kiểm toán độc lập hoặc ký phát hành.

## Ranh giới tin cậy

| Nguồn | Cách xử lý |
| --- | --- |
| Chuỗi tìm kiếm | Chỉ lọc UI, không vào command |
| Catalog JSON | Validate kiểu, ID, trùng lặp; ID phải thuộc catalog lúc chạy |
| Command plan | Tái dựng từ action/ID và so sánh từng token tại boundary |
| winget.exe | Từ App Installer đăng ký; chữ ký hợp lệ với Microsoft; không PATH |
| Source tên winget | Export JSON, xác minh URL HTTPS và identity nguồn Microsoft |
| Backup JSON | Không chứa lệnh thực thi; chỉ dùng ID đã biết, existence và DWORD; kiểm tra SID/machine |
| Installer bên thứ ba | Chạy qua winget, giữ kiểm tra hash mặc định; không thể kiểm soát mọi hành vi |
| Ứng dụng đã cài | Đường dẫn cố định, chữ ký Valid; chưa pin danh tính publisher từng app |

Catalog là một phần của source tin cậy. Kẻ có quyền sửa thư mục ứng dụng cũng có thể sửa PowerShell code; allowlist không chống được kẻ đã sửa code hoặc máy đã bị chiếm quyền. Không dựa vào ExecutionPolicy như một security boundary. Hash đi kèm ZIP không thay thế chữ ký nhà phát hành hoặc checksum lấy từ kênh độc lập.

## Những việc ứng dụng không tự làm

Không tắt bảo vệ, update hay firewall; không sửa dịch vụ hàng loạt; không “tối ưu” mạng/registry không kiểm chứng; không xóa telemetry hệ thống; không gỡ app Windows mặc định hàng loạt; không bypass TLS/hash/signature; không chạy mã tải qua `iex`; không tự reboot.

Các lệnh SFC/DISM có khả năng sửa hệ thống, không có rollback do Mộc quản lý. Bước xác nhận nói rõ tác động, đề nghị backup/restore point. System Protection chỉ mở giao diện Windows; **không tuyên bố đã tạo restore point**.

## Snapshot và phục hồi

- Snapshot ghi trước mọi registry write và không ghi đè lần đầu.
- Restore chỉ quay lại giá trị gốc của đúng value, không thay toàn key.
- Nếu giá trị đổi bên ngoài sau apply, Mộc từ chối restore để tránh ghi đè.
- Nếu write fail, backup vẫn còn. Nếu giá trị vẫn giống original, chưa có thay đổi cần hoàn tác; GUI có thể chặn apply/restore vì snapshot tồn tại/current không khớp. Giữ bản sao, kiểm tra JSON và giá trị hiện tại bằng Registry Editor, rồi **chuyển riêng snapshot sang thư mục lưu trữ** sau khi xác nhận đúng trạng thái. Không tự động xóa snapshot.
- Nếu crash sau write nhưng trước audit, dùng snapshot và read-back để đối chiếu. Nếu crash trước write, có thể chỉ có snapshot mà chưa đổi gì.
- Snapshot không đủ phục hồi app đã gỡ hoặc dữ liệu cá nhân. Sao lưu dữ liệu riêng trước khi gỡ/sửa.

## Quyền và dữ liệu

Mộc không có telemetry. Winget tải metadata/installer theo mạng và chính sách riêng. Các ứng dụng bên thứ ba có thể thu dữ liệu theo cấu hình của chúng. Source show/list có thể làm mới cache winget.

Audit ghi thời gian UTC, command, package ID, đường dẫn app được mở, exit code, trạng thái tweak. Không ghi bí mật có chủ ý, nhưng đường dẫn có thể chứa tên tài khoản. Kiểm tra trước khi chia sẻ log. File nằm trong profile người dùng, không mã hóa hoặc ký; không phải chứng cứ chống sửa đổi.

Nếu không ghi được audit, ứng dụng dừng trước khi bắt đầu thao tác mới. Nếu ghi log thất bại sau thay đổi thì thao tác đã có thể xảy ra; xem trạng thái thực tế thay vì retry mù.

## Còn cần gia cố trước khi phát hành rộng

1. Ký Authenticode launcher và scripts bằng chứng chỉ phù hợp, kèm timestamp; xuất checksum qua kênh tin cậy.
2. Thử trong Windows VM sạch với tài khoản thường, UAC hủy, mất mạng, disk full, installer reboot/pending, nhiều locale.
3. Giới hạn bộ nhớ output và bổ sung journal phục hồi khi crash; mã hiện tại không phải transaction engine.
4. Chống source/executable TOCTOU mạnh hơn nếu threat model cần; hiện kiểm tra ngay trước chạy nhưng không khóa cấu hình nguồn suốt quá trình.
5. Hỗ trợ publisher allowlist cho mở app nếu cần đảm bảo danh tính thay vì chỉ chữ ký hợp lệ.
6. Audit độc lập trước mọi chức năng chỉnh registry hệ thống, services, boot, driver hoặc firewall. Không thêm các chức năng này như “tweak nhanh”.

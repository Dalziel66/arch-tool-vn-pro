# Bàn giao — 09/11/2026

## Đã làm

- Tạo dự án độc lập trong `F:\Tools`, tên Mộc, version 0.1.0.
- PowerShell/WPF desktop tiếng Việt; Gruvbox làm nền, tùy chọn đổi nền Jade; 4 tab, search/category, presets, preview/consent, queue, log.
- 36 ứng dụng; install/upgrade/uninstall/show/list qua winget; mở một số EXE ở vị trí chuẩn và có chữ ký Valid.
- Source/executable validation, no shell eval, process runner tuần tự, dừng queue khi lỗi, audit JSONL.
- 3 tweaks HKCU với snapshot/restore/read-back; 10 công cụ Windows gồm thao tác Settings và SFC/DISM.
- Launcher C# asInvoker, portable packaging và checksums; toàn bộ source/docs đi kèm.
- Core tests không sửa registry thật; WPF smoke và ảnh preview.

## Quyết định thiết kế

Chọn PowerShell 5.1 + WPF vì máy có runtime sẵn nhưng không có .NET SDK. Không cần cài dependency chỉ để mở giao diện. Không fork WinUtil vì mục tiêu là triển khai rõ ràng, dễ audit và giới hạn tác động. Không chạy lệnh `irm christitus.com/win | iex`.

Registry tweaks giới hạn HKCU DWORD để rollback có thể hiểu được. Không tự tạo restore point rồi tuyên bố mọi thao tác đều đảo ngược được. SFC/DISM có preview và UAC riêng nhưng chưa được chạy thật trong quá trình xây dựng này.

## Việc cần biết trước khi tiếp tục

- Chưa signed release; checksum không là bằng chứng publisher.
- Chưa installer integration tests trong VM. Metadata check chỉ chứng minh ID tồn tại/query được ở thời điểm kiểm tra.
- Không stream stdout từng dòng; `ReadToEndAsync` giữ output đến khi xong. Preflight source sync tối đa 10 giây.
- Không parse installed state hoặc update availability thành badge; nhận diện executable chỉ hỗ trợ fixed locations.
- Chưa import/export preset người dùng, tự cập nhật Mộc, pin version, toàn bộ apps/tweaks của CTT, hoặc multi-language UI.
- Theme button hiện đổi nền Gruvbox/Jade, chưa restyle toàn bộ palette. Không quảng cáo như theme engine đầy đủ.
- Snapshot pending do crash/write failure có thể cần đối chiếu thủ công; xem SECURITY.md.

## Ưu tiên tiếp theo

1. Windows VM sạch: install/uninstall một gói thử ít tác động; user/machine scope; UAC hủy; offline; error exit; reboot pending.
2. Kiểm thử tinh chỉnh thật trong VM, gồm value chưa tồn tại/type lạ và quyền bị từ chối.
3. Bounded stdout streaming, progress và thông báo pending installer rõ hơn; giữ nguyên nguyên tắc không kill installer.
4. Ký phát hành, nhận diện launcher publisher, thêm CI Windows chạy tests không mutation.
5. Accessibility: high DPI, screen reader, high contrast, 1366×768, keyboard-only. Giao diện hiện có scroll và min size, nhưng chưa kiểm tra đủ.
6. App launch có publisher allowlist và khả năng nhận diện installed app ổn định hơn. Nếu dùng WinGet COM API, thiết kế abstraction và test riêng.

Không phải phần việc đã hoàn thành: đăng ký chính Mộc lên winget, mã hóa/chống sửa audit, tự rollback installer hoặc sửa Windows toàn diện.


## Cập nhật 09/11/2026 (Claude Code)

- Đổi Python 3.13 → 3.14 trong catalog; GIMP.GIMP.3 vẫn là ID hiện hành. Các gói khác không ghim phiên bản nên winget luôn cài bản mới nhất.
- Ghi chú `[VI]` cho toàn bộ mã. Đã chạy lại `Test.ps1 -IncludeUI`, `Build.ps1`, `Verify-Catalog.ps1` trên Windows PowerShell 5.1.
- Khi Python 3.15 lên winget (`Python.Python.3.15`), đổi ID trong `data/apps.json` và chạy lại Verify-Catalog.
- Bootstrap irm: xem README. Đã thử đầu cuối từ CMD qua file:// + smoke test bản đã cài; chưa thử với GitHub Release thật. Thông báo trong install.ps1 không dấu vì irm có thể giải mã sai UTF-8.

## Cập nhật 10/11/2026 (Claude Code)

- Rà soát toàn bộ mã; chi tiết trong CHANGELOG. Sửa kẹt hàng đợi khi tiến trình con giữ pipe (đã tái hiện mẫu lỗi bằng `cmd /c start /b ping`; chưa thử với installer thật).
- Đã đối chiếu release v0.1.0: SHA256 trong `install.ps1` khớp digest của zip; `Get-FileHash`/`Expand-Archive` chạy được cả khi ExecutionPolicy là Restricted.
- Sau khi đổi mã phải build lại và tải **cả hai** file lên release thì người dùng lệnh `irm` mới nhận được bản sửa.
- Vẫn chưa chạy installer thật; cửa sổ SFC/DISM tự đóng khi xong nên kết quả chỉ xem được trong CBS.log/DISM.log.

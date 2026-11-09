# Changelog

## Unreleased — 2026-11-09

- Sửa: cài gói đã có sẵn (winget 0x8A150061) không còn bị tính là lỗi và dừng hàng đợi; báo "Đã cài sẵn" và chạy tiếp. 0x8A15002B (không có bản cập nhật) cũng vậy. 3010 và mã lạ vẫn dừng để xem lại.
- Smoke test UI dùng mutex riêng, chạy được khi người dùng đang mở Mộc.
- Catalog: `Python.Python.3.13` → `Python.Python.3.14` (bản Python mới nhất có trên nguồn winget lúc kiểm tra; winget 1.29.380).
- Thêm ghi chú tiếng Việt (`[VI]`) cho mọi hàm PowerShell, script, launcher C#, `Start-Moc.cmd` và các vùng chính của XAML. Không đổi hành vi.
- Thêm bootstrap `irm | iex`: `scripts/Install.template.ps1`, `Build.ps1 -Repo` sinh `dist/install.ps1` ghim URL + SHA256 zip; 4 test mới (file://, hash sai, cài lại).

## 0.1.0 — 2026-11-09

- First Vietnamese WPF desktop implementation with Omarchy-inspired colors and typography.
- Curated app catalog, reviewed winget operations, safe process queue and audit summaries.
- Three current-user settings with original-state backups and conflict-aware restore.
- Built-in Windows tools and individually elevated SFC/DISM actions.
- Portable asInvoker launcher, reproducible source workflow, offline core/UI tests.
- Documentation, architecture, threat model and Claude Code handoff.

Initial development release; unsigned; real installers and system repair actions require further VM validation.

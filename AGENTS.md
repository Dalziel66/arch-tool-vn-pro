# Working agreements for this repository

## Context

Mộc is a Vietnamese Windows desktop toolkit. It is an independent PowerShell 5.1/WPF implementation. Read README.md, docs/ARCHITECTURE.md, docs/SECURITY.md and docs/HANDOFF.md before changing execution behavior.

## Engineering rules

- Keep Windows PowerShell 5.1 compatibility. Save `.ps1` files as UTF-8 **with BOM** (Vietnamese strings); JSON/XAML/Markdown use UTF-8.
- Prefer small dependency-free changes. The development machine may have no .NET SDK, npm packages, Pester or internet access.
- Do not install/uninstall software, modify real registry settings, run system repairs, or reboot a user's workstation just to test the code. Use mocked adapters; use a disposable VM for installer/system integration tests when authorized.
- Do not introduce Invoke-Expression, runtime-downloaded scripts, arbitrary shell execution, string-built PowerShell commands, user-supplied executable paths, or unvalidated arguments.
- Preserve exact package ID validation, official source identity verification, executable signature verification, preview/consent, fail-closed behavior, and per-action UAC.
- Never disable Defender, Firewall, UAC, SmartScreen, security updates, signature or installer hash checks. No silent mass debloat, forced reboot, mass update or process killing.
- Never silently replace the first tweak snapshot. Restore is restricted to fixed current-user registry keys and original value/existence/type. Treat snapshot JSON as untrusted.
- UI `GetNewClosure()` handlers have dynamic module scope. Do not mutate `$script:` state from those closures; call an ordinary helper function instead. Existing smoke checks catch category/confirmation regressions.
- Log failures accurately. A launched process is not a successful operation. Installer 3010 needs reboot and unknown exit codes remain errors requiring review.
- Preserve user changes and files. No recursive deletion/moving of arbitrary computed paths. Build includes explicit directories only.

## Validation and handoff

Run `powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Test.ps1 -IncludeUI` after substantive changes; inspect `artifacts/moc-preview.png` after layout changes. Run `scripts/Build.ps1` for packaging. Repeat online catalog verification only if package IDs or winget integration changed.

Document what changed, test evidence, untested areas, and security limitations. Update docs/HANDOFF.md and CHANGELOG.md. Do not claim production safety, full WinUtil parity, signed releases, installer rollback, or test coverage that does not exist.

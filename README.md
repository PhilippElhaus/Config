# Configuration Repository

Versioned shell, editor, public-key, runner, synchronization, and media helpers for Philipp's workstations. This repository does not contain private keys or runtime secrets.

Windows Terminal defaults to PowerShell 7. Its separate PowerShell 5.1 profile
remains available for compatibility. Keep this default when applying the
terminal settings. Do not replace unrelated local profiles or settings.
RAM-disk task definitions prefer the installed absolute PowerShell 7 path.
They use the absolute Windows PowerShell 5.1 path only when PowerShell 7 is
absent. Existing tasks and deployed RAM-disk scripts require a separate,
reviewed action update; running the installer also runs the storage payload.

## Map

| Path | Scope |
| --- | --- |
| `bash/` | Bash and terminal configuration. |
| `powershell/` | PowerShell profile and terminal settings. |
| `Public Keys/` | Public SSH and OpenPGP keys only. |
| `scripts/` | Codex setup, RAM-disk, media, branch, and NAS synchronization helpers. |
| `scripts/gh-register/` | GitHub organization runner reconciliation. Read its [README](scripts/gh-register/README.md) before use. |
| `vscode/` | Shared editor configuration. |

## Safety and validation

Inspect a helper before execution. Several scripts change runner registration, branches, mounted storage, or synchronized files. Keep credentials and private keys outside this repository.

Run the syntax checker for each changed script, then run `git diff --check`. Do not execute synchronization, registration, or branch helpers as routine tests.
Run `pwsh -NoProfile -File tests/Test-PowerShellSelection.ps1` and the same
fixture with `powershell.exe`. These tests load only task helper definitions,
replace task registration with fixtures, and never run RAM-disk setup.

# Configuration Repository

Versioned shell, editor, public-key, runner, synchronization, and media helpers for Philipp's workstations. This repository does not contain private keys or runtime secrets.

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

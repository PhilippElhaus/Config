# GitHub Org Runner Reconciliation (Windows + WSL)

Automated, idempotent boot-time reconciliation for org-level self-hosted runners in `elhaus-labs`.

## Environment

- Windows runners:
  - `NUC-WIN-1` on `D:\`
  - `NUC-WIN-2` on `E:\`
- WSL runners (Ubuntu-24.04):
  - `NUC-LINUX-3` on `/mnt/f`
  - `NUC-LINUX-4` on `/mnt/g`
  - `NUC-LINUX-5` on `/mnt/h`

Each runner directory must already exist and contain runner files (`config.cmd` / `config.sh`).

## What The Scripts Do

- `install.ps1` (Windows):
  - Runs as `SYSTEM`
  - Lists org runners
  - If runner exists: ensures it is running
  - If missing: registers in-place (remove/retry if locally configured) and starts it
- `install.sh` (WSL):
  - Same reconciliation logic for Linux runners
  - Auto-loads `GITHUB_PAT` from env, `/etc/profile.d/github_pat.sh`, or `/etc/environment`
  - Starts runner via `svc.sh`, fallback `run.sh`

## Required PAT

Fine-grained PAT for org `elhaus-labs` with:

- `Self-hosted runners: Read and write`
- SSO authorization enabled for org (if SAML is enabled)

## Install / Setup

1. Windows script deployment:
   - Copy `install.ps1` to `C:\scripts\ensure-org-runners.ps1`
   - Set machine PAT:
     - `[Environment]::SetEnvironmentVariable("GITHUB_PAT","<PAT>","Machine")`

2. Linux script deployment:
   - Copy `install.sh` to `/usr/local/bin/ensure-org-runners.sh`
   - `chmod +x /usr/local/bin/ensure-org-runners.sh`

3. WSL PAT source (one of these):
   - `/etc/profile.d/github_pat.sh` exporting `GITHUB_PAT`
   - or `/etc/environment` containing `GITHUB_PAT=...`

4. Scheduled tasks:
   - Windows task (On startup, user `SYSTEM`):
     - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\scripts\ensure-org-runners.ps1`
   - WSL task (On startup):
     - `wsl.exe -d Ubuntu-24.04 -- bash -lc '/usr/local/bin/ensure-org-runners.sh'`

## Logs

- Windows: `C:\scripts\logs\ensure-org-runners.log`
- WSL runtime log: `/var/log/ensure-org-runners.log` (fallback `/tmp/ensure-org-runners.log`)
- WSL bootstrap trace: `C:\scripts\logs\ensure-org-runners-wsl-bootstrap.log`

## Quick Verification

- Reboot host
- Confirm logs show script version/startup lines
- Confirm runners are online in org settings
- Reboot again and verify no duplicate runners are created

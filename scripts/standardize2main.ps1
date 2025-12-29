# ==============================================================================
# Enforces `main` as the local default branch for all Git repos under a root path.
# Public Domain, 2025 — Philipp Elhaus
# ==============================================================================
# Recursively discovers repositories (.git directory or gitfile-based).
# Fetches and prunes origin, ensures local `main` tracks `origin/main`.
# Renames local `master` to `main` or creates `main` if missing.
# Deletes local `master` only if it has no unique commits; otherwise renames to backup.
# Updates origin/HEAD to point to `main`.
# Never deletes repositories, remotes, or commits.#
# Usage:
# .\standardize2main.ps1 -Root "<RepoDriveOrFolder>"

param(
	[string]$Root = (Get-Location).Path
)

function Get-GitExe {
	$cmd = Get-Command git -ErrorAction SilentlyContinue
	if ($null -eq $cmd) { throw "git executable not found in PATH." }
	$cmd.Source
}

$GitExe = Get-GitExe

function Exec-Git {
	param(
		[Parameter(Mandatory = $true)][string]$Repo,
		[Parameter(Mandatory = $true)][string[]]$Args
	)

	$output = & $GitExe -C $Repo @Args 2>&1
	$code = $LASTEXITCODE

	$text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
	$text = $text.Trim()

	[pscustomobject]@{
		Code = $code
		Out  = if ($code -eq 0) { $text } else { "" }
		Err  = if ($code -ne 0) { $text } else { "" }
		All  = $text
	}
}

function Has-LocalBranch {
	param([string]$Repo, [string]$Name)
	((Exec-Git $Repo @("show-ref","--verify","--quiet","refs/heads/$Name")).Code -eq 0)
}

function Has-RemoteBranch {
	param([string]$Repo, [string]$Remote, [string]$Name)
	((Exec-Git $Repo @("show-ref","--verify","--quiet","refs/remotes/$Remote/$Name")).Code -eq 0)
}

function WorkingTreeClean {
	param([string]$Repo)
	$r = Exec-Git $Repo @("status","--porcelain")
	($r.Code -eq 0 -and [string]::IsNullOrWhiteSpace($r.Out))
}

function UniqueCommitCount {
	param([string]$Repo, [string]$From, [string]$To)
	$r = Exec-Git $Repo @("rev-list","--count","$From..$To")
	if ($r.Code -ne 0 -or [string]::IsNullOrWhiteSpace($r.Out)) { return $null }
	[int]$r.Out
}

function Get-GitRepos {
	param([string]$ScanRoot)

	$excludeRegex = '\\(\$RECYCLE\.BIN|System Volume Information)\\'
	$repoPaths = @()

	$gitDirs = Get-ChildItem -Path $ScanRoot -Directory -Recurse -Force -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -ieq ".git" -and $_.FullName -notmatch $excludeRegex }

	foreach ($d in $gitDirs) {
		$repoPaths += $d.Parent.FullName
	}

	$gitFiles = Get-ChildItem -Path $ScanRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -ieq ".git" -and $_.FullName -notmatch $excludeRegex }

	foreach ($f in $gitFiles) {
		$repoPaths += $f.Directory.FullName
	}

	$repoPaths | Sort-Object -Unique
}

Write-Host "Scanning for git repos under: $Root"

$repos = Get-GitRepos -ScanRoot $Root
Write-Host ("Found {0} repo(s)." -f ($repos | Measure-Object).Count)

foreach ($repo in $repos) {
	Write-Host ""
	Write-Host "Repo: $repo"

	$top = Exec-Git $repo @("rev-parse","--show-toplevel")
	if ($top.Code -ne 0 -or [string]::IsNullOrWhiteSpace($top.Out)) {
		Write-Host "  Skip: git does not recognize this as a working tree"
		if (-not [string]::IsNullOrWhiteSpace($top.All)) {
			Write-Host "  Git error: $($top.All)"
		}
		continue
	}

	if (-not (WorkingTreeClean $repo)) {
		Write-Host "  Skip: working tree not clean"
		continue
	}

	$f = Exec-Git $repo @("fetch","origin","--prune")
	if ($f.Code -ne 0) {
		Write-Host "  Skip: fetch failed: $($f.All)"
		continue
	}

	if (-not (Has-RemoteBranch $repo "origin" "main")) {
		Write-Host "  Skip: origin/main does not exist"
		continue
	}

	$hasMain = Has-LocalBranch $repo "main"
	$hasMaster = Has-LocalBranch $repo "master"

	if (-not $hasMain) {
		if ($hasMaster) {
			$r = Exec-Git $repo @("branch","-m","master","main")
			if ($r.Code -ne 0) {
				Write-Host "  Skip: cannot rename master->main: $($r.All)"
				continue
			}
			$hasMain = $true
			$hasMaster = $false
		} else {
			$c = Exec-Git $repo @("checkout","-b","main","--track","origin/main")
			if ($c.Code -ne 0) {
				Write-Host "  Skip: cannot create main: $($c.All)"
				continue
			}
			$hasMain = $true
		}
	}

	$co = Exec-Git $repo @("checkout","main")
	if ($co.Code -ne 0) {
		Write-Host "  Skip: cannot checkout main: $($co.All)"
		continue
	}

	$u = Exec-Git $repo @("branch","--set-upstream-to","origin/main","main")
	if ($u.Code -ne 0) {
		Write-Host "  Skip: cannot set upstream: $($u.All)"
		continue
	}

	$hasMaster = Has-LocalBranch $repo "master"
	if ($hasMaster) {
		$unique = UniqueCommitCount $repo "main" "master"
		if ($null -eq $unique) {
			Write-Host "  Note: could not compare main..master; leaving master as-is"
		} elseif ($unique -eq 0) {
			Exec-Git $repo @("branch","-D","master") | Out-Null
			Write-Host "  OK: deleted local master (no unique commits)"
		} else {
			$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
			$backup = "master-backup-$stamp"
			Exec-Git $repo @("branch","-m","master",$backup) | Out-Null
			Write-Host "  OK: master had $unique unique commit(s); renamed to $backup"
		}
	}

	Exec-Git $repo @("remote","set-head","origin","-a") | Out-Null

	Write-Host "  OK: main enforced and tracking origin/main"
}

Write-Host ""
Write-Host "Done."

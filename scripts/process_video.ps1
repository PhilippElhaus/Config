# ==============================================================================
# AV1 Batch Transcoder
# Public Domain, 2025 — Philipp Elhaus
# ==============================================================================
# Converts all .mp4 files in a folder to AV1 .webm in a subfolder (default: .\Out).
# Removes audio. Uses Intel QSV AV1 hardware encoding (av1_qsv) when available and
# working; otherwise falls back to high-quality 2-pass software AV1 (libaom-av1).
# Shows progress via ffmpeg -progress.

param(
	[string]$InputDir = ".",
	[string]$OutSubDir = "Out",

	[int]$Width = 960,
	[int]$Fps = 30,

	[int]$TargetKbps = 650,
	[int]$MaxKbps = 900,

	[int]$GopSeconds = 8,

	[int]$CpuUsed = 4,
	[int]$Threads = [int]$env:NUMBER_OF_PROCESSORS,

	[string]$QsvRc = "icq",
	[int]$QsvGlobalQuality = 30,
	[int]$QsvAsyncDepth = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Quote-Arg([string]$s) {
	'"' + ($s -replace '"','\"') + '"'
}

function Get-DurationSeconds([string]$Path) {
	$d = 0.0
	$dur = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Path
	[void][double]::TryParse(($dur | Select-Object -First 1), [ref]$d)
	[math]::Max(0.0, $d)
}

function Test-Encoder([string]$Name) {
	$enc = & ffmpeg -hide_banner -encoders 2>$null
	($enc | Out-String) -match ("(?m)^\s*[A-Z\.]{6}\s+$([regex]::Escape($Name))\b")
}

function Invoke-FfmpegWithProgress {
	param(
		[int]$Id,
		[int]$ParentId,
		[string]$Activity,
		[string]$Status,
		[double]$DurationSeconds,
		[string]$Arguments
	)

	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = "ffmpeg"
	$psi.Arguments = $Arguments
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.CreateNoWindow = $true

	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $psi
	[void]$p.Start()

	$lastPct = -1
	while (-not $p.StandardOutput.EndOfStream) {
		$line = $p.StandardOutput.ReadLine()
		if ($DurationSeconds -gt 0 -and $line -match '^out_time_ms=(\d+)$') {
			$sec = ([double]$matches[1]) / 1000000.0
			$pct = [int][math]::Min(99, [math]::Max(0, ($sec / $DurationSeconds) * 100))
			if ($pct -ne $lastPct) {
				Write-Progress -Id $Id -ParentId $ParentId -Activity $Activity -Status $Status -PercentComplete $pct
				$lastPct = $pct
			}
		}
	}

	$p.WaitForExit()
	if ($p.ExitCode -ne 0) {
		$err = ($p.StandardError.ReadToEnd() -split "`r?`n") | Where-Object { $_ } | Select-Object -First 1
		throw ("ffmpeg failed (exit {0}): {1}" -f $p.ExitCode, $err)
	}

	Write-Progress -Id $Id -ParentId $ParentId -Activity $Activity -Status $Status -PercentComplete 100
}

$InputDir = (Resolve-Path -LiteralPath $InputDir).Path
$OutDir = Join-Path $InputDir $OutSubDir
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$files = @(Get-ChildItem -LiteralPath $InputDir -File -Filter "*.mp4")
$total = $files.Count

if ($total -lt 1) {
	Write-Host "No .mp4 files found in: $InputDir"
	return
}
$i = 0
$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

$hasQsv = Test-Encoder -Name "av1_qsv"

foreach ($f in $files) {
	$i++
	$inFile = $f.FullName
	$outFile = Join-Path $OutDir ($f.BaseName + ".webm")

	$dur = Get-DurationSeconds -Path $inFile
	$pctAll = [int](($i / [math]::Max(1, $total)) * 100)
	$eta = if ($i -gt 1) {
		$avg = $swTotal.Elapsed.TotalSeconds / ($i - 1)
		[int]($avg * ($total - $i + 1))
	} else { 0 }

	$vf = "fps=$Fps,scale=${Width}:-2:flags=lanczos"
	$gop = [math]::Max(1, $Fps * $GopSeconds)

	Write-Progress -Id 1 -Activity "AV1 -> $OutSubDir" `
		-Status ("File {0}/{1} ({2}%) | ETA ~{3}s | {4}" -f $i, $total, $pctAll, $eta, $f.Name) `
		-PercentComplete $pctAll

	$didQsv = $false

	if ($hasQsv) {
		try {
			$args = @(
				"-hide_banner","-loglevel","error","-y",
				"-i",(Quote-Arg $inFile),
				"-an",
				"-vf",(Quote-Arg $vf),
				"-c:v","av1_qsv",
				"-rc","$QsvRc",
				"-global_quality","$QsvGlobalQuality",
				"-g","$gop",
				"-async_depth","$QsvAsyncDepth",
				"-progress","pipe:1",
				(Quote-Arg $outFile)
			) -join " "

			Invoke-FfmpegWithProgress -Id 2 -ParentId 1 -Activity "Encode (AV1 QSV)" -Status $f.Name -DurationSeconds $dur -Arguments $args
			$didQsv = $true
		} catch {
			$didQsv = $false
		}
	}

	if (-not $didQsv) {
		$passLog = Join-Path $env:TEMP ("ffmpeg_av1pass_{0}_{1}" -f $PID, $f.BaseName)

		$common = @(
			"-hide_banner","-loglevel","error","-y",
			"-i",(Quote-Arg $inFile),
			"-an",
			"-vf",(Quote-Arg $vf),
			"-c:v","libaom-av1",
			"-b:v","${TargetKbps}k",
			"-maxrate","${MaxKbps}k",
			"-bufsize","${MaxKbps}k",
			"-cpu-used","$CpuUsed",
			"-g","$gop",
			"-row-mt","1",
			"-threads","$Threads",
			"-passlogfile",(Quote-Arg $passLog),
			"-progress","pipe:1"
		) -join " "

		Invoke-FfmpegWithProgress -Id 2 -ParentId 1 -Activity "Pass 1/2 (CPU)" -Status $f.Name -DurationSeconds $dur -Arguments (
			"$common -pass 1 -f null NUL"
		)

		Invoke-FfmpegWithProgress -Id 2 -ParentId 1 -Activity "Pass 2/2 (CPU)" -Status $f.Name -DurationSeconds $dur -Arguments (
			"$common -pass 2 $(Quote-Arg $outFile)"
		)

		Remove-Item -LiteralPath ($passLog + "*") -Force -ErrorAction SilentlyContinue
	}
}

Write-Progress -Id 2 -Activity "Done" -Completed
Write-Progress -Id 1 -Activity "Done" -Completed

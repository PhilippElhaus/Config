param(
	[string]$Org = "elhaus-labs",
	[string]$PatEnvVar = "GITHUB_PAT",
	[string]$LogDir = "C:\scripts\logs"
)

$ScriptVersion = "2026-02-28.7"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# TLS for GitHub API on Windows PowerShell 5.1
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

if (-not (Test-Path $LogDir)) {
	New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$logFile = Join-Path $LogDir "ensure-org-runners.log"
$lockFile = Join-Path $LogDir "ensure-org-runners.lock"

# Prevent overlapping runs
$lockHandle = $null
try {
	$lockHandle = [System.IO.File]::Open($lockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
} catch {
	exit 0
}

# Stable logger (single writer)
$logStream = $null
$logWriter = $null

function Init-Logger {
	$script:logStream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
	$script:logWriter = New-Object System.IO.StreamWriter($script:logStream, (New-Object System.Text.UTF8Encoding($false)))
	$script:logWriter.AutoFlush = $true
}

function Close-Logger {
	if ($script:logWriter) { $script:logWriter.Dispose() }
	if ($script:logStream) { $script:logStream.Dispose() }
}

function Write-Log {
	param([string]$Msg)
	$script:logWriter.WriteLine(("[{0}] {1}" -f (Get-Date -Format o), (Redact-SensitiveText -Text $Msg)))
}

function Redact-SensitiveText {
	param([AllowNull()][string]$Text)
	if ($null -eq $Text) { return "" }

	# Mask common secret shapes in logs without changing control flow.
	$redacted = $Text
	$redacted = [regex]::Replace($redacted, '(?i)(Authorization''?\s*[:=]\s*''?Bearer\s+)[^''\s]+', '$1[REDACTED]')
	$redacted = [regex]::Replace($redacted, '(?i)("token"\s*:\s*")[^"]+(")', '$1[REDACTED]$2')
	$redacted = [regex]::Replace($redacted, '(?i)(--token\s+)\S+', '$1[REDACTED]')
	$redacted = [regex]::Replace($redacted, '(?i)(GITHUB_PAT\s*=\s*)\S+', '$1[REDACTED]')
	return $redacted
}

function Get-BodySnippet {
	param([string]$Body, [int]$MaxLen = 400)
	if ([string]::IsNullOrEmpty($Body)) { return "" }
	$safe = (Redact-SensitiveText -Text $Body) -replace "[\r\n\t]+", " "
	return $safe.Substring(0, [Math]::Min($MaxLen, $safe.Length))
}

function Get-FailureRootCause {
	param(
		[Nullable[int]]$Status,
		[string]$ContentType,
		[string]$Body,
		[string]$ErrorMessage
	)

	$ct = ""
	if ($ContentType) { $ct = $ContentType.ToLowerInvariant() }
	$text = ("{0} {1}" -f $Body, $ErrorMessage).ToLowerInvariant()

	if ($Status -eq 401) { return "auth.invalid_or_expired_token" }

	if ($Status -eq 403) {
		if ($text -match "sso|saml") { return "auth.sso_not_authorized" }
		if ($text -match "resource not accessible|insufficient|permission|forbidden") { return "auth.missing_org_permission" }
		return "auth.access_forbidden"
	}

	if ($Status -eq 429) { return "api.rate_limited" }
	if ($Status -ge 500 -and $Status -le 599) { return "api.server_error" }

	if ($ct -like "text/html*") { return "network.proxy_or_tls_intercept_html_response" }
	if ($text -match "proxy") { return "network.proxy_error" }
	if ($text -match "ssl|tls|certificate|trust relationship|secure channel|handshake") { return "network.tls_error" }
	if ($text -match "name resolution|dns|could not resolve|no such host") { return "network.dns_error" }
	if ($text -match "timed out|timeout") { return "network.timeout" }

	return "unknown"
}

function Get-Pat {
	param([string]$EnvVarName)

	$script:PatSource = ""
	$script:PatPresence = "Machine=0 Process=0 User=0"

	$token = [Environment]::GetEnvironmentVariable($EnvVarName, "Machine")
	$hasMachine = -not [string]::IsNullOrWhiteSpace($token)

	$processToken = [Environment]::GetEnvironmentVariable($EnvVarName, "Process")
	$hasProcess = -not [string]::IsNullOrWhiteSpace($processToken)

	$userToken = [Environment]::GetEnvironmentVariable($EnvVarName, "User")
	$hasUser = -not [string]::IsNullOrWhiteSpace($userToken)

	$script:PatPresence = ("Machine={0} Process={1} User={2}" -f ([int]$hasMachine), ([int]$hasProcess), ([int]$hasUser))

	if ($hasMachine) {
		$script:PatSource = "Machine"
		return $token
	}

	if ($hasProcess) {
		$script:PatSource = "Process"
		return $processToken
	}

	if ($hasUser) {
		$script:PatSource = "User"
		return $userToken
	}

	return $null
}

function Get-GitHubHeaders {
	param([string]$Token)
	return @{
		"Authorization" = "Bearer $Token"
		"Accept" = "application/vnd.github+json"
		"X-GitHub-Api-Version" = "2022-11-28"
		"User-Agent" = "ensure-org-runners"
	}
}

function Read-ResponseBody {
	param($Response)

	try {
		if ($Response -and $Response.Content) { return [string]$Response.Content }
	} catch {}

	# For WebException responses
	try {
		$stream = $Response.GetResponseStream()
		if ($stream) {
			$reader = New-Object System.IO.StreamReader($stream)
			$text = $reader.ReadToEnd()
			$reader.Dispose()
			return [string]$text
		}
	} catch {}

	return ""
}

function Convert-JsonSafe {
	param([string]$Text)

	if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
	try {
		return ($Text | ConvertFrom-Json)
	} catch {
		return $null
	}
}

function Invoke-GitHubJson {
	param(
		[string]$Method,
		[string]$Uri,
		[hashtable]$Headers
	)

	$maxAttempts = 6
	for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
		try {
			$resp = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Uri -Headers $Headers -TimeoutSec 30
			$status = [int]$resp.StatusCode
			$ctype = ""
			try { $ctype = [string]$resp.Headers["Content-Type"] } catch {}

			$body = Read-ResponseBody -Response $resp
			$data = Convert-JsonSafe -Text $body
			$snip = Get-BodySnippet -Body $body
			Write-Log "GitHub response received. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype'"

			if ($status -ge 200 -and $status -le 299) {
				if (-not $data) {
					$cause = Get-FailureRootCause -Status $status -ContentType $ctype -Body $body -ErrorMessage ""
					Write-Log "GitHub response parse failure. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause BodySnippet='$snip'"
					return $null
				}
				$propNames = ""
				try { $propNames = (($data.PSObject.Properties.Name) -join ",") } catch { $propNames = "<no-properties>" }
				Write-Log "GitHub JSON parse success. Method=$Method Uri=$Uri Properties='$propNames'"
				return $data
			}

			# Non-2xx
			$msg = $null
			if ($data -and ($data.PSObject.Properties.Name -contains "message")) {
				$msg = [string]$data.message
			} else {
				$msg = $snip
			}
			$cause = Get-FailureRootCause -Status $status -ContentType $ctype -Body $body -ErrorMessage $msg

			if ($status -eq 401 -or $status -eq 403) {
				Write-Log "GitHub auth/access error. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause Message='$msg' BodySnippet='$snip'"
				return $null
			}

				if ($status -eq 429 -or ($status -ge 500 -and $status -le 599)) {
					$delay = [Math]::Min(60, [Math]::Pow(2, $attempt))
					$retryAfter = $null
					try { $retryAfter = $resp.Headers["Retry-After"] } catch {}

					if ($retryAfter) {
						$tmp = 0
						if ([int]::TryParse([string]$retryAfter, [ref]$tmp) -and $tmp -gt 0) {
							$delay = [Math]::Min(120, $tmp)
						}
					}

					if ($attempt -eq $maxAttempts) {
						Write-Log "GitHub transient error final. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause Attempt=$attempt/$maxAttempts Message='$msg' BodySnippet='$snip'"
						return $null
					}

					Write-Log "GitHub transient error. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause RetryIn=${delay}s Attempt=$attempt/$maxAttempts Message='$msg' BodySnippet='$snip'"
					Start-Sleep -Seconds $delay
					continue
				}

			Write-Log "GitHub API error. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause Message='$msg' BodySnippet='$snip'"
			return $null
		} catch {
			# Network/TLS/proxy errors often land here
			$we = $_.Exception
			$respObj = $null
			try { $respObj = $we.Response } catch {}

			$status = $null
			$ctype = ""
			$body = ""

			if ($respObj) {
				try { $status = [int]$respObj.StatusCode } catch { $status = $null }
				try { $ctype = [string]$respObj.ContentType } catch { $ctype = "" }
				$body = Read-ResponseBody -Response $respObj
			}

			$snip = Get-BodySnippet -Body $body
			$cause = Get-FailureRootCause -Status $status -ContentType $ctype -Body $body -ErrorMessage $we.Message

			$transient = ($status -eq 429) -or ($status -ge 500 -and $status -le 599) -or (-not $status)
			if (-not $transient -or $attempt -eq $maxAttempts) {
				Write-Log "GitHub request exception final. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause Error='$($we.Message)' BodySnippet='$snip'"
				return $null
			}

			$delay = [Math]::Min(60, [Math]::Pow(2, $attempt))
			Write-Log "GitHub request exception transient. Method=$Method Uri=$Uri HttpStatus=$status ContentType='$ctype' RootCause=$cause RetryIn=${delay}s Attempt=$attempt/$maxAttempts Error='$($we.Message)' BodySnippet='$snip'"
			Start-Sleep -Seconds $delay
		}
	}

	return $null
}

function Get-OrgRunnerNames {
	param([string]$Org, [hashtable]$Headers)

	$names = New-Object System.Collections.Generic.HashSet[string]
	$page = 1

	while ($true) {
		$uri = "https://api.github.com/orgs/$Org/actions/runners?per_page=100&page=$page"
		$data = Invoke-GitHubJson -Method "Get" -Uri $uri -Headers $Headers

		if (-not $data) {
			Write-Log "Get-OrgRunnerNames: received null data for page=$page."
			return $null
		}
		if (-not ($data.PSObject.Properties.Name -contains "runners")) {
			if ($data.PSObject.Properties.Name -contains "message") {
				Write-Log ("GitHub returned message for runners list: " + [string]$data.message)
			} else {
				Write-Log "GitHub runners list response missing 'runners' field."
			}
			return $null
		}

		$runnerPage = @($data.runners)
		foreach ($r in $runnerPage) {
			if ($r -and $r.name) { [void]$names.Add([string]$r.name) }
		}

		if ($runnerPage.Count -lt 100) { break }
		$page++
	}

	# Prevent PowerShell from enumerating an empty collection into $null.
	Write-Output -NoEnumerate $names
}

$script:CachedRegToken = $null
function Get-RegistrationTokenCached {
	param([string]$Org, [hashtable]$Headers)

	if ($script:CachedRegToken) { return $script:CachedRegToken }

	$uri = "https://api.github.com/orgs/$Org/actions/runners/registration-token"
	$data = Invoke-GitHubJson -Method "Post" -Uri $uri -Headers $Headers

	if (-not $data -or -not ($data.PSObject.Properties.Name -contains "token") -or [string]::IsNullOrWhiteSpace([string]$data.token)) {
		Write-Log "Failed to obtain registration token from GitHub."
		return $null
	}

	$script:CachedRegToken = [string]$data.token
	return $script:CachedRegToken
}

$script:CachedRemoveToken = $null
function Get-RemoveTokenCached {
	param([string]$Org, [hashtable]$Headers)

	if ($script:CachedRemoveToken) { return $script:CachedRemoveToken }

	$uri = "https://api.github.com/orgs/$Org/actions/runners/remove-token"
	$data = Invoke-GitHubJson -Method "Post" -Uri $uri -Headers $Headers

	if (-not $data -or -not ($data.PSObject.Properties.Name -contains "token") -or [string]::IsNullOrWhiteSpace([string]$data.token)) {
		Write-Log "Failed to obtain remove token from GitHub."
		return $null
	}

	$script:CachedRemoveToken = [string]$data.token
	return $script:CachedRemoveToken
}

function Resolve-RunnerRoot {
	param([string]$DriveLetter)

	$root = "$DriveLetter`:\"
	if (-not (Test-Path $root)) { return $null }

	if (Test-Path (Join-Path $root "config.cmd")) { return $root }

	$child = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Select-Object -First 50
	foreach ($d in $child) {
		if (Test-Path (Join-Path $d.FullName "config.cmd")) { return $d.FullName }
	}

	return $null
}

function Invoke-RunnerNative {
	param(
		[string]$FilePath,
		[string[]]$Arguments,
		[string]$ActionLabel
	)

	if (-not (Test-Path $FilePath)) {
		Write-Log "$ActionLabel skipped: file not found ($FilePath)."
		return $false
	}

	try {
		& $FilePath @Arguments *> $null
	} catch {
		Write-Log "$ActionLabel threw exception: $($_.Exception.Message)"
		return $false
	}
	$code = $LASTEXITCODE
	if ($null -eq $code) { $code = 0 }

	if ($code -ne 0) {
		Write-Log "$ActionLabel failed with exit code $code."
		return $false
	}

	return $true
}

function Get-RunnerServiceName {
	param([string]$RunnerRoot)

	$serviceFile = Join-Path $RunnerRoot ".service"
	if (-not (Test-Path $serviceFile)) { return $null }

	try {
		$name = (Get-Content -Path $serviceFile -Raw -ErrorAction Stop).Trim()
		if ([string]::IsNullOrWhiteSpace($name)) { return $null }
		return $name
	} catch {
		Write-Log "Failed to read service name from '$serviceFile': $($_.Exception.Message)"
		return $null
	}
}

function Is-RunnerProcessRunning {
	param([string]$RunnerRoot)

	try {
		$expected = [System.IO.Path]::Combine($RunnerRoot, "bin", "Runner.Listener.exe").ToLowerInvariant()
		$procs = Get-CimInstance Win32_Process -Filter "Name='Runner.Listener.exe'" -ErrorAction Stop
		foreach ($p in $procs) {
			$exe = ""
			try { $exe = [string]$p.ExecutablePath } catch { $exe = "" }
			if (-not [string]::IsNullOrWhiteSpace($exe) -and $exe.ToLowerInvariant() -eq $expected) {
				return $true
			}
		}
	} catch {}

	return $false
}

function Ensure-RunnerStarted {
	param(
		[string]$RunnerName,
		[string]$RunnerRoot,
		[string]$SvcCmd
	)

	$serviceName = Get-RunnerServiceName -RunnerRoot $RunnerRoot
	if (Test-Path $SvcCmd) {
		$startOk = Invoke-RunnerNative -FilePath $SvcCmd -Arguments @("start") -ActionLabel "Runner '$RunnerName' service start"
		if (-not $startOk) {
			Write-Log "Runner '$RunnerName': service start failed; attempting install+start."
			[void](Invoke-RunnerNative -FilePath $SvcCmd -Arguments @("install") -ActionLabel "Runner '$RunnerName' service install")
			[void](Invoke-RunnerNative -FilePath $SvcCmd -Arguments @("start") -ActionLabel "Runner '$RunnerName' service start retry")
		}
	}

	if (-not [string]::IsNullOrWhiteSpace($serviceName)) {
		$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
		if ($svc -and $svc.Status -eq "Running") {
			Write-Log "Runner '$RunnerName': service '$serviceName' is running."
			return $true
		}
		Write-Log "Runner '$RunnerName': service '$serviceName' not running after start attempts."
	}

	$runCmd = Join-Path $RunnerRoot "run.cmd"
	if (Test-Path $runCmd) {
		try {
			Start-Process -FilePath $runCmd -WorkingDirectory $RunnerRoot -WindowStyle Hidden | Out-Null
			Start-Sleep -Seconds 2
			if (Is-RunnerProcessRunning -RunnerRoot $RunnerRoot) {
				Write-Log "Runner '$RunnerName': started via run.cmd fallback."
				return $true
			}
			Write-Log "Runner '$RunnerName': run.cmd fallback launched but listener process not detected."
		} catch {
			Write-Log "Runner '$RunnerName': run.cmd fallback failed: $($_.Exception.Message)"
		}
	}

	Write-Log "Runner '$RunnerName': failed to start runner process/service."
	return $false
}

function Ensure-Runner {
	param(
		[string]$RunnerName,
		[string]$DriveLetter,
		[System.Collections.Generic.HashSet[string]]$OrgRunnerNames,
		[string]$Org,
		[hashtable]$Headers
	)

	$runnerRoot = Resolve-RunnerRoot -DriveLetter $DriveLetter
	if (-not $runnerRoot) {
		Write-Log "Runner '$RunnerName': could not find config.cmd on $DriveLetter`:\ or first-level subfolders."
		return $false
	}

	$configCmd = Join-Path $runnerRoot "config.cmd"
	$svcCmd = Join-Path $runnerRoot "svc.cmd"

	Write-Log "Runner '$RunnerName' mapped to $DriveLetter`: => $runnerRoot"

	if (($null -ne $OrgRunnerNames) -and $OrgRunnerNames.Contains($RunnerName)) {
		Write-Log "Runner '$RunnerName' exists in org. Ensuring service is started."
		return (Ensure-RunnerStarted -RunnerName $RunnerName -RunnerRoot $runnerRoot -SvcCmd $svcCmd)
	}

	$regToken = Get-RegistrationTokenCached -Org $Org -Headers $Headers
	if ([string]::IsNullOrWhiteSpace($regToken)) {
		Write-Log "Runner '$RunnerName': cannot re-register because registration token could not be obtained."
		return $false
	}

	Write-Log "Runner '$RunnerName' missing in org. Re-registering in-place."

	Push-Location $runnerRoot
	try {
		$configArgs = @(
			"--url", "https://github.com/$Org",
			"--token", $regToken,
			"--unattended",
			"--name", $RunnerName,
			"--work", "_work",
			"--replace"
		)

		$configOk = Invoke-RunnerNative -FilePath $configCmd -Arguments $configArgs -ActionLabel "Runner '$RunnerName' config"
		if (-not $configOk) {
			Write-Log "Runner '$RunnerName': config failed, attempting local remove + re-register."
			$removeToken = Get-RemoveTokenCached -Org $Org -Headers $Headers
			if (-not [string]::IsNullOrWhiteSpace($removeToken)) {
				[void](Invoke-RunnerNative -FilePath $configCmd -Arguments @("remove", "--unattended", "--token", $removeToken) -ActionLabel "Runner '$RunnerName' config remove")
			}

			$configOk = Invoke-RunnerNative -FilePath $configCmd -Arguments $configArgs -ActionLabel "Runner '$RunnerName' config retry"
			if (-not $configOk) { return $false }
		}

		if (-not (Ensure-RunnerStarted -RunnerName $RunnerName -RunnerRoot $runnerRoot -SvcCmd $svcCmd)) {
			return $false
		}
	} catch {
		Write-Log "Runner '$RunnerName' config/service failed: $($_.Exception.Message)"
		return $false
	} finally {
		Pop-Location
	}
	return $true
}

$exitCode = 0
try {
	Init-Logger
	$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	Write-Log "ScriptVersion=$ScriptVersion ScriptPath=$PSCommandPath"
	Write-Log "Execution identity=$identity; Host=$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
	Write-Log "Starting reconciliation for org=$Org"

	$pat = Get-Pat -EnvVarName $PatEnvVar
	if ([string]::IsNullOrWhiteSpace($pat)) {
		Write-Log "PAT not available in env var '$PatEnvVar'. Presence: $script:PatPresence. (SYSTEM typically requires Machine scope.)"
		$exitCode = 1
	} else {
		Write-Log "PAT source scope=$script:PatSource"
		$headers = Get-GitHubHeaders -Token $pat

		$orgRunnerNames = Get-OrgRunnerNames -Org $Org -Headers $headers
		if ($null -eq $orgRunnerNames) {
			Write-Log "Could not retrieve org runners list. No changes applied. If no GitHub diagnostic lines appear above, this is likely an outdated script path/version."
			$exitCode = 1
		} else {
			Write-Log ("Org runners (count={0}): {1}" -f $orgRunnerNames.Count, (($orgRunnerNames | Sort-Object) -join ", "))

			$runnerFailure = $false
			if (-not (Ensure-Runner -RunnerName "NUC-WIN-1" -DriveLetter "D" -OrgRunnerNames $orgRunnerNames -Org $Org -Headers $headers)) {
				$runnerFailure = $true
			}
			if (-not (Ensure-Runner -RunnerName "NUC-WIN-2" -DriveLetter "E" -OrgRunnerNames $orgRunnerNames -Org $Org -Headers $headers)) {
				$runnerFailure = $true
			}

			if ($runnerFailure) {
				Write-Log "Completed with runner reconciliation errors."
				$exitCode = 1
			}

			Write-Log "Done."
		}
	}
} catch {
	# Never crash the console; log and exit nonzero
	try {
		if ($logWriter) { Write-Log "FATAL: $($_.Exception.Message)" }
	} catch {}
	$exitCode = 1
} finally {
	Close-Logger
	if ($lockHandle) { $lockHandle.Dispose() }
	exit $exitCode
}

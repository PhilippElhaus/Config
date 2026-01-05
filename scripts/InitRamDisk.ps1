# ----------------------------------------
# InitRamDisk.ps1
# 2026, Philipp Elhaus, Public Domain
# Idempotent RAM-disk setup (R:)
# - Creates folders
# - Moves TEMP/TMP (system + user) to R:
# - Sets Chrome/Edge cache dirs via policy
# - Installs scheduled tasks (startup + logon)
# ----------------------------------------

[CmdletBinding()]
param(
	[ValidateSet('Run','Install')]
	[string]$Mode = 'Run'
)

$ErrorActionPreference = 'Stop'

$TaskStartupName = 'InitRamDisk-Startup'
$TaskLogonName = 'InitRamDisk-Logon'

$RamDrive = 'R:\'

$Paths = @(
	'R:\Temp\System',
	'R:\Temp\User',
	'R:\ChromeCache',
	'R:\EdgeCache',
	'R:\ChromeCodeCache',
	'R:\Installer'
)

function Test-RamDiskReady {
	return (Test-Path -LiteralPath $RamDrive)
}

function Ensure-Directories {
	foreach ($p in $Paths) {
		if (-not (Test-Path -LiteralPath $p)) {
			New-Item -ItemType Directory -Path $p -Force | Out-Null
		}
	}
}

function Set-RegistryValueIfDifferent {
	param(
		[Parameter(Mandatory)][string]$Path,
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][object]$Value,
		[Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::String
	)

	if (-not (Test-Path -LiteralPath $Path)) {
		New-Item -Path $Path -Force | Out-Null
	}

	$current = $null
	try {
		$current = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name
	} catch {
		$current = $null
	}

	if ($current -ne $Value) {
		New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
		return $true
	}

	return $false
}

function Broadcast-EnvironmentChange {
	Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeMethods {
	[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
	public static extern IntPtr SendMessageTimeout(
		IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
		uint fuFlags, uint uTimeout, out UIntPtr lpdwResult
	);
}
"@ -ErrorAction SilentlyContinue | Out-Null

	$HWND_BROADCAST = [IntPtr]0xffff
	$WM_SETTINGCHANGE = 0x001A
	$SMTO_ABORTIFHUNG = 0x0002
	[UIntPtr]$result = [UIntPtr]::Zero

	[Win32.NativeMethods]::SendMessageTimeout(
		$HWND_BROADCAST,
		$WM_SETTINGCHANGE,
		[UIntPtr]::Zero,
		'Environment',
		$SMTO_ABORTIFHUNG,
		2000,
		[ref]$result
	) | Out-Null
}

function Ensure-SystemTemp {
	$changed = $false
	$envPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
	$changed = (Set-RegistryValueIfDifferent -Path $envPath -Name 'TEMP' -Value 'R:\Temp\System') -or $changed
	$changed = (Set-RegistryValueIfDifferent -Path $envPath -Name 'TMP' -Value 'R:\Temp\System') -or $changed
	if ($changed) { Broadcast-EnvironmentChange }
}

function Ensure-UserTemp {
	$changed = $false
	$envPath = 'HKCU:\Environment'
	$changed = (Set-RegistryValueIfDifferent -Path $envPath -Name 'TEMP' -Value 'R:\Temp\User') -or $changed
	$changed = (Set-RegistryValueIfDifferent -Path $envPath -Name 'TMP' -Value 'R:\Temp\User') -or $changed
	if ($changed) { Broadcast-EnvironmentChange }
}

function Ensure-ChromeEdgeCachePolicies {
	$changed = $false

	# Chrome policy
	$chromePol = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
	$changed = (Set-RegistryValueIfDifferent -Path $chromePol -Name 'DiskCacheDir' -Value 'R:\ChromeCache') -or $changed
	$changed = (Set-RegistryValueIfDifferent -Path $chromePol -Name 'DiskCacheSize' -Value 1073741824 -Type DWord) -or $changed

	# Edge policy
	$edgePol = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
	$changed = (Set-RegistryValueIfDifferent -Path $edgePol -Name 'DiskCacheDir' -Value 'R:\EdgeCache') -or $changed
	$changed = (Set-RegistryValueIfDifferent -Path $edgePol -Name 'DiskCacheSize' -Value 1073741824 -Type DWord) -or $changed

	if ($changed) { }
}

function Ensure-ScheduledTasks {
	param(
		[Parameter(Mandatory)][string]$ScriptPath
	)

	# Startup task (SYSTEM) for machine-level settings
	if (-not (Get-ScheduledTask -TaskName $TaskStartupName -ErrorAction SilentlyContinue)) {
		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Mode Run"
		$trigger = New-ScheduledTaskTrigger -AtStartup

		Register-ScheduledTask -TaskName $TaskStartupName `
			-Action $action `
			-Trigger $trigger `
			-Description 'Init RAM-disk folders and machine-wide TEMP + browser cache policy' `
			-User 'SYSTEM' `
			-RunLevel Highest | Out-Null
	}

	# Logon task (current user) for HKCU TEMP/TMP
	if (-not (Get-ScheduledTask -TaskName $TaskLogonName -ErrorAction SilentlyContinue)) {
		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Mode Run"
		$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:UserName

		Register-ScheduledTask -TaskName $TaskLogonName `
			-Action $action `
			-Trigger $trigger `
			-Description 'Init RAM-disk folders and user TEMP/TMP' `
			-User $env:UserName `
			-RunLevel Highest | Out-Null
	}
}

function Main-Run {
	if (-not (Test-RamDiskReady)) {
		return
	}

	Ensure-Directories

	# Try both: if not elevated, system changes will fail (silently skip).
	try { Ensure-SystemTemp } catch { }
	try { Ensure-ChromeEdgeCachePolicies } catch { }

	# User temp should work under the interactive user context.
	try { Ensure-UserTemp } catch { }
}

function Main-Install {
	$scriptPath = $MyInvocation.MyCommand.Definition

	if (-not (Test-Path -LiteralPath $scriptPath)) {
		throw "Script path not found: $scriptPath"
	}

	Ensure-ScheduledTasks -ScriptPath $scriptPath

	# Run once now as well
	Main-Run
}

if ($Mode -eq 'Install') {
	Main-Install
} else {
	Main-Run
}

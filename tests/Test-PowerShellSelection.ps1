Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../scripts/InitRamDisk.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'RAM-disk source syntax is invalid.' }
foreach ($name in @('Get-PreferredPowerShellExecutable', 'Ensure-ScheduledTasks')) {
    $definitions = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true))
    if ($definitions.Count -ne 1) { throw 'Expected one bounded task helper.' }
    # Load only two definitions. Never run the RAM-disk or installation payload.
    Invoke-Expression $definitions[0].Extent.Text
}
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if ([IO.Path]::GetPathRoot($temporaryRoot) -eq 'D:\') { throw 'Fixtures must stay off D:.' }
$fixture = Join-Path $temporaryRoot ('config-powershell-test-' + [guid]::NewGuid().ToString('N'))
$programFiles = Join-Path $fixture 'ProgramFiles'
$windows = Join-Path $fixture 'Windows'
$preferred = Join-Path $programFiles 'PowerShell\7\pwsh.exe'
$fallback = Join-Path $windows 'System32\WindowsPowerShell\v1.0\powershell.exe'
try {
    foreach ($file in @($preferred, $fallback)) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force
        [IO.File]::WriteAllBytes($file, [byte[]]@())
    }
    if ((Get-PreferredPowerShellExecutable $programFiles $windows) -cne $preferred) { throw 'PowerShell 7 must have priority.' }
    Remove-Item -LiteralPath $preferred
    if ((Get-PreferredPowerShellExecutable $programFiles $windows) -cne $fallback) { throw 'PowerShell 5.1 must remain the absence fallback.' }
    Remove-Item -LiteralPath $fallback
    $refused = $false
    try { Get-PreferredPowerShellExecutable $programFiles $windows | Out-Null }
    catch { $refused = $true }
    if (-not $refused) { throw 'Missing engines must fail.' }

    $script:actions = @()
    $script:registrations = @()
    function Get-ScheduledTask { param($TaskName, $ErrorAction) return $null }
    function New-ScheduledTaskAction {
        param($Execute, $Argument)
        $value = [pscustomobject]@{ Execute = $Execute; Arguments = $Argument }
        $script:actions += $value
        return $value
    }
    function New-ScheduledTaskTrigger { param([switch]$AtStartup, [switch]$AtLogOn, $User) return 'fixture-trigger' }
    function Register-ScheduledTask {
        param($TaskName, $Action, $Trigger, $Description, $User, $RunLevel)
        $script:registrations += $TaskName
    }
    $TaskStartupName = 'InitRamDisk-Startup'
    $TaskLogonName = 'InitRamDisk-Logon'
    $expected = Get-PreferredPowerShellExecutable
    Ensure-ScheduledTasks -ScriptPath 'C:\fixture\InitRamDisk.ps1'
    if ($script:actions.Count -ne 2 -or $script:registrations.Count -ne 2) { throw 'Both task definitions must use the shared selector.' }
    foreach ($action in $script:actions) {
        if ($action.Execute -cne $expected -or $action.Arguments -cne '-NoProfile -ExecutionPolicy Bypass -File "C:\fixture\InitRamDisk.ps1" -Mode Run') {
            throw 'Task engine or existing payload arguments changed.'
        }
    }
    Write-Output ('PowerShell selection fixtures passed under ' + $PSVersionTable.PSVersion.Major)
} finally {
    if (Test-Path -LiteralPath $fixture) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        if (-not $resolved.StartsWith($temporaryRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($resolved) -notmatch '^config-powershell-test-[0-9a-f]{32}$') { throw 'Unsafe fixture cleanup path.' }
        $entries = @(Get-Item -LiteralPath $resolved -Force) + @(Get-ChildItem -LiteralPath $resolved -Recurse -Force)
        foreach ($entry in $entries) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked fixture content was preserved.' }
            if (-not $entry.PSIsContainer -and $entry.FullName -notin @($preferred, $fallback)) { throw 'Unknown fixture content was preserved.' }
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

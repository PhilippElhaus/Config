# ==============================================================================
# PowerShell Config
# Public Domain, 2025 — Philipp Elhaus
# ==============================================================================

Remove-Item Alias:ls -ErrorAction SilentlyContinue


$culture     = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
$esc         = [char]27
$DirColor    = "$esc[34m"   # blue
$HiddenColor = "$esc[33m"   # yellow
$FileColor   = "$esc[37m"   # white/gray
$ResetColor  = "$esc[0m"


function ls {
	Get-ChildItem -Force |
		Sort-Object @{
			Expression = {
				if ($_.PSIsContainer) { 0 }
				elseif ( (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0) -or ($_.Name -like '.*') ) { 1 }
				else { 2 }
			}
		}, Name |
		Select-Object @{
			Name       = 'Name'
			Expression = {
				$isHidden = (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0) -or ($_.Name -like '.*')

				if ($_.PSIsContainer) {
					"$DirColor$($_.Name)$ResetColor"
				} elseif ($isHidden) {
					"$HiddenColor$($_.Name)$ResetColor"
				} else {
					"$FileColor$($_.Name)$ResetColor"
				}
			}
		} |
		Format-Wide -Column 4
}


function ll {
	Get-ChildItem -Force |
		Sort-Object -Property @{
			Expression = {
				if ($_.PSIsContainer) { 0 }
				elseif ( (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0) -or ($_.Name -like '.*') ) { 1 }
				else { 2 }
			}
		}, Name |
		Select-Object `
			Mode,
			@{
				Name       = 'LastWriteTime'
				Expression = { $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
			},
			@{
				Name       = 'Size(MB)'
				Expression = {
					if ($_.PSIsContainer) {
						''
					} else {
						$mb = $_.Length / 1MB
						$mb.ToString('N2', $culture) + ' MB'
					}
				}
			},
			@{
				Name       = 'Name'
				Expression = {
					$isHidden = (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0) -or ($_.Name -like '.*')

					if ($_.PSIsContainer) {
						"$DirColor$($_.Name)$ResetColor"
					} elseif ($isHidden) {
						"$HiddenColor$($_.Name)$ResetColor"
					} else {
						"$FileColor$($_.Name)$ResetColor"
					}
				}
			} |
		Format-Table -AutoSize
}
Remove-Item Alias:history -ErrorAction SilentlyContinue

function history {
	$path = (Get-PSReadLineOption).HistorySavePath
	if (-not (Test-Path $path)) { return }

	$all = Get-Content -Path $path
	if (-not $all) { return }

	$seen   = @{}
	$unique = New-Object System.Collections.Generic.List[string]

	for ($i = $all.Count - 1; $i -ge 0 -and $unique.Count -lt 100; $i--) {
		$line = $all[$i].Trim()
		if ([string]::IsNullOrWhiteSpace($line)) { continue }
		if (-not $seen.ContainsKey($line)) {
			$seen[$line] = $true
			$unique.Add($line)
		}
	}

	$arr = $unique.ToArray()
	[array]::Reverse($arr)

	for ($i = 0; $i -lt $arr.Length; $i++) {
		"  {0}  {1}" -f ($i + 1), $arr[$i]
	}
}
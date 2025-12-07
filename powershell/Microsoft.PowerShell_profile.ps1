# ==============================================================================
# PowerShell Config
# Public Domain, 2025 — Philipp Elhaus
# Features:
#   - ls: colored column view, sorted: directories → hidden/dot-files → regular
#   - ll: long listing, 24h timestamps, size in MB, colored names, same sorting
# ==============================================================================

Remove-Item Alias:ls -ErrorAction SilentlyContinue

$culture    = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
$esc        = [char]27
$DirColor   = "$esc[34m"
$HiddenColor= "$esc[33m"
$FileColor  = "$esc[37m"
$ResetColor = "$esc[0m"

function ls {
	Get-ChildItem -Force |
	Sort-Object @{
		Expression = {
			if ($_.PSIsContainer) { 0 }
			elseif (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0 -or $_.Name -like '.*') { 1 }
			else { 2 }
		}
	}, Name |
	Select-Object @{
		Name       = 'Name'
		Expression = {
			$isHidden = (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0) -or ($_.Name -like '.*')
			if ($_.PSIsContainer) { "$DirColor$($_.Name)$ResetColor" }
			elseif ($isHidden)   { "$HiddenColor$($_.Name)$ResetColor" }
			else                 { "$FileColor$($_.Name)$ResetColor" }
		}
	} |
	Format-Wide -Column 4
}

function ll {
	Get-ChildItem -Force |
	Sort-Object @{
		Expression = {
			if ($_.PSIsContainer) { 0 }
			elseif (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0 -or $_.Name -like '.*') { 1 }
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
				if ($_.PSIsContainer) { '' }
				else {
					$mb = $_.Length / 1MB
					$mb.ToString('N2', $culture) + ' MB'
				}
			}
		},
		@{
			Name       = 'Name'
			Expression = {
				$isHidden = (($_.Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0) -or ($_.Name -like '.*')
				if ($_.PSIsContainer) { "$DirColor$($_.Name)$ResetColor" }
				elseif ($isHidden)   { "$HiddenColor$($_.Name)$ResetColor" }
				else                 { "$FileColor$($_.Name)$ResetColor" }
			}
		} |
	Format-Table
}

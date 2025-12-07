# ==============================================================================
# PowerShell directory helpers
# Public Domain, 2025 — Philipp Elhaus
# Features:
#   - ls: colored column view, sorted: directories → hidden/dot-files → regular
#   - ll: long listing, 24h timestamps, size in MB, colored names, same sorting
#   - Optimized for speed (no AutoSize, single global formatting state)
# ==============================================================================

# Remove built-in alias so our ls is used
Remove-Item Alias:ls -ErrorAction SilentlyContinue

# ==============================================================================
# Global formatting resources (faster than recreating on each call)
# ==============================================================================
$culture     = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
$esc         = [char]27
$DirColor    = "$esc[34m"   # blue
$HiddenColor = "$esc[33m"   # yellow
$FileColor   = "$esc[37m"   # white/gray
$ResetColor  = "$esc[0m"

# ==============================================================================
# ls (colored column view)
# ==============================================================================
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

# ==============================================================================
# ll (long listing, colored, sorted, MB sizes, optimized)
# ==============================================================================
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
		Format-Table
}

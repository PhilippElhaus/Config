Set-Alias -Name ll -Value 'dir'

function string {
    param (
        [string]$Pattern
    )
    Get-ChildItem -Recurse | Select-String -Pattern $Pattern
}
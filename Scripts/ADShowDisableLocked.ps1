Import-Module ActiveDirectory

Clear-host


$lockedAccounts = Search-ADAccount -LockedOut | Select-Object Name, SAMAccountName, LockedOut
$disabledAccounts = Search-ADAccount -AccountDisabled | Select-Object Name, SAMAccountName, Enabled

if ($lockedAccounts.Count -eq 0 -and $disabledAccounts.Count -eq 0) {
    Write-Output "No locked or disabled profiles found."
} else {
    if ($lockedAccounts.Count -gt 0) {
        Write-Output "Locked Accounts:"
        $lockedAccounts | Format-Table
    }
    
    if ($disabledAccounts.Count -gt 0) {
        Write-Output "Disabled Accounts:"
        $disabledAccounts | Format-Table
    }
}

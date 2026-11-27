#Requires -Version 5.1
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Lists Active Directory accounts that are locked out or disabled.

.DESCRIPTION
    Prints two on-screen tables: accounts Search-ADAccount reports as locked,
    and accounts it reports as disabled. Nothing is written to a file.

    Requires the Active Directory module (RSAT) and an account that can read
    the domain.

.EXAMPLE
    .\ADShowDisableLocked.ps1
#>
Import-Module ActiveDirectory

Clear-Host

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

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

# @() around the pipeline, not around a variable. In Windows PowerShell 5.1 a
# single Search-ADAccount result is a scalar, and .Count on that scalar is $null,
# so one locked or disabled account was skipped. An empty pipeline inside @()
# is Count 0. @($null) is Count 1 on 5.1, which is why this is not
# $x = ...; $x = @($x).
$lockedAccounts = @(Search-ADAccount -LockedOut | Select-Object Name, SAMAccountName, LockedOut)
$disabledAccounts = @(Search-ADAccount -AccountDisabled | Select-Object Name, SAMAccountName, Enabled)

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

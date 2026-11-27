#Requires -Modules ActiveDirectory, ImportExcel
<#
.SYNOPSIS
    Exports AD users and computers with their last-logon times to an Excel workbook.

.DESCRIPTION
    Output is written OUTSIDE this repository by default. This report contains real
    account names and machine names -- do not commit it to source control.

    Note on accuracy: LastLogonTimestamp only replicates every ~9-14 days, so values
    can lag reality by up to two weeks. Fine for stale-account triage; do not use it
    to prove exactly when someone last signed in.

.EXAMPLE
    .\ADLastLogin.ps1
.EXAMPLE
    .\ADLastLogin.ps1 -OutputFolder D:\Reports
#>
[CmdletBinding()]
param(
    # Defaults to Documents\ADReports -- deliberately not $PSScriptRoot.
    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ADReports')
)

if (-not (Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

$stamp         = Get-Date -Format 'yyyyMMdd_HHmmss'
$excelFilePath = Join-Path $OutputFolder "UserComputer_$stamp.xlsx"

# Convert a raw LastLogonTimestamp to a sortable DateTime, or $null if never used.
$toDate = { if ($_.LastLogonTimestamp) { [datetime]::FromFileTime($_.LastLogonTimestamp) } else { $null } }

Write-Verbose 'Retrieving users...'
$users = Get-ADUser -Filter * -Properties GivenName,Surname,SamAccountName,LastLogonTimestamp |
    Select-Object GivenName,Surname,SamAccountName,
        @{Name='LastLogon'; Expression=$toDate} |
    # Sort on the real DateTime (nulls first) so we never compare a date to a string.
    Sort-Object @{Expression={ if ($null -eq $_.LastLogon) { [datetime]::MinValue } else { $_.LastLogon } }} |
    Select-Object GivenName,Surname,SamAccountName,
        @{Name='LastLogon'; Expression={ if ($_.LastLogon) { $_.LastLogon } else { 'Never Logged On' } }}

Write-Verbose 'Retrieving computers...'
$computers = Get-ADComputer -Filter * -Properties Name,Description,LastLogonTimestamp |
    Select-Object Name,Description,
        @{Name='LastLogon'; Expression=$toDate} |
    Sort-Object @{Expression={ if ($null -eq $_.LastLogon) { [datetime]::MinValue } else { $_.LastLogon } }} |
    Select-Object Name,Description,
        @{Name='LastLogon'; Expression={ if ($_.LastLogon) { $_.LastLogon } else { 'Never Logged On' } }}

Write-Host "Users retrieved:     $($users.Count)"
Write-Host "Computers retrieved: $($computers.Count)"

$users     | Export-Excel -Path $excelFilePath -WorksheetName 'USERS'     -AutoSize -BoldTopRow -FreezeTopRow
$computers | Export-Excel -Path $excelFilePath -WorksheetName 'COMPUTERS' -AutoSize -BoldTopRow -FreezeTopRow

Write-Host "Report written to $excelFilePath" -ForegroundColor Green
Write-Warning 'This file contains real account and machine names. Do not commit it to source control.'

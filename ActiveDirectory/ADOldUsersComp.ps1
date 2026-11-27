#Requires -Modules ActiveDirectory, ImportExcel
<#
.SYNOPSIS
    Reports AD users and computers that have not logged on in N days.

.DESCRIPTION
    FIXED: the previous version called Get-ADUser/Get-ADComputer without
    -Properties LastLogonDate. That property is not returned by default, so every
    object's value was $null, the comparison never matched, and the script silently
    reported zero inactive objects on every run while appearing to succeed.

    Output is written OUTSIDE this repository -- it contains real account names.

.EXAMPLE
    .\ADOldUsersComp.ps1
.EXAMPLE
    .\ADOldUsersComp.ps1 -Days 180 -MailTo it@example.com -SmtpServer smtp.example.com
#>
[CmdletBinding()]
param(
    [int]$Days = 90,
    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ADReports'),
    # Email is opt-in. Leave these unset to just write the file.
    [string]$MailTo,
    [string]$MailFrom,
    [string]$SmtpServer
)

$threshold = (Get-Date).AddDays(-$Days)

# -Properties LastLogonDate is REQUIRED -- this is the bug that made the old version
# silently report nothing.
$users     = Get-ADUser     -Filter * -Properties LastLogonDate
$computers = Get-ADComputer -Filter * -Properties LastLogonDate

$inactiveUsers = $users | Where-Object {
    $null -ne $_.LastLogonDate -and $_.LastLogonDate -lt $threshold
} | ForEach-Object {
    [PSCustomObject]@{
        ObjectName = $_.Name
        ObjectType = 'User'
        LastLogon  = $_.LastLogonDate
        DaysStale  = [int]((Get-Date) - $_.LastLogonDate).TotalDays
        DeleteYN   = 'N'
    }
} | Sort-Object LastLogon

$inactiveComputers = $computers | Where-Object {
    $null -ne $_.LastLogonDate -and $_.LastLogonDate -lt $threshold
} | ForEach-Object {
    [PSCustomObject]@{
        ObjectName = $_.Name
        ObjectType = 'Computer'
        LastLogon  = $_.LastLogonDate
        DaysStale  = [int]((Get-Date) - $_.LastLogonDate).TotalDays
        DeleteYN   = 'N'
    }
} | Sort-Object LastLogon

# Objects that have NEVER logged on are reported separately -- a null LastLogonDate is
# not the same as "inactive", and lumping them together hides freshly created accounts.
$neverUsers = @($users     | Where-Object { $null -eq $_.LastLogonDate }).Count
$neverComps = @($computers | Where-Object { $null -eq $_.LastLogonDate }).Count

Write-Host "Inactive users (>$Days days):     $(@($inactiveUsers).Count)"
Write-Host "Inactive computers (>$Days days): $(@($inactiveComputers).Count)"
Write-Host "Never logged on:                  $neverUsers users, $neverComps computers"

if (@($inactiveUsers).Count -eq 0 -and @($inactiveComputers).Count -eq 0) {
    Write-Host 'Nothing inactive found. No report written.' -ForegroundColor Green
    return
}

if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }
$excelPath = Join-Path $OutputFolder "InactiveObjects_$(Get-Date -Format 'yyyyMMdd_HHmmss').xlsx"

# One Export-Excel call per sheet. The old version passed $data.Keys (an ARRAY) into
# -WorksheetName, which takes a single string -- it could never produce two sheets.
if (@($inactiveUsers).Count     -gt 0) { $inactiveUsers     | Export-Excel -Path $excelPath -WorksheetName 'Inactive Users'     -AutoSize -BoldTopRow -FreezeTopRow }
if (@($inactiveComputers).Count -gt 0) { $inactiveComputers | Export-Excel -Path $excelPath -WorksheetName 'Inactive Computers' -AutoSize -BoldTopRow -FreezeTopRow }

Write-Host "Report written to $excelPath" -ForegroundColor Green
Write-Warning 'This file contains real account and machine names. Do not commit it to source control.'

if ($MailTo -and $MailFrom -and $SmtpServer) {
    # Send-MailMessage is obsolete and cannot guarantee a secure connection.
    # Replace with Microsoft Graph or Mailozaurr when convenient.
    Write-Warning 'Send-MailMessage is deprecated by Microsoft; sending anyway.'
    $body = "The attached objects have not connected to Active Directory in more than $Days days."
    Send-MailMessage -To $MailTo -From $MailFrom -SmtpServer $SmtpServer `
        -Subject 'Inactive Objects Report' -Body $body -Attachments $excelPath
} else {
    Write-Host 'Email not sent (pass -MailTo, -MailFrom and -SmtpServer to enable).' -ForegroundColor DarkGray
}

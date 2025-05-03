#!/usr/bin/env pwsh

# Import the necessary modules
Import-Module ActiveDirectory
Import-Module ImportExcel

# Define the Excel file path
$excelFilePath = Join-Path $PSScriptRoot "UserComputer.xlsx"

# Get all AD users
$users = Get-ADUser -Filter * -Property GivenName,Surname,SamAccountName,LastLogonTimestamp |
    Select-Object GivenName,Surname,SamAccountName,@{Name='LastLogonTimestamp';Expression={
        if ($_.LastLogonTimestamp) { [datetime]::FromFileTime($_.LastLogonTimestamp) } else { "Never Logged On" }
    }} |
    Sort-Object LastLogonTimestamp

# Output user information to console for debugging
Write-Host "Users Retrieved:" ($users | Format-Table -AutoSize | Out-String)

# Get all AD computers
$computers = Get-ADComputer -Filter * -Property Name,Description,LastLogonTimestamp |
    Select-Object Name,Description,@{Name='LastLogonTimestamp';Expression={
        if ($_.LastLogonTimestamp) { [datetime]::FromFileTime($_.LastLogonTimestamp) } else { "Never Logged On" }
    }} |
    Sort-Object LastLogonTimestamp

# Output computer information to console for debugging
Write-Host "Computers Retrieved:" ($computers | Format-Table -AutoSize | Out-String)

# Create or replace the Excel file
Remove-Item $excelFilePath -ErrorAction Ignore

# Export USERS data to Excel
$users | Export-Excel -Path $excelFilePath -WorksheetName "USERS"

# Export COMPUTERS data to Excel
$computers | Export-Excel -Path $excelFilePath -WorksheetName "COMPUTERS" -Append

Write-Host "Excel file created/replaced successfully at $excelFilePath"

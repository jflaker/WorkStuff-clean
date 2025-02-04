# PowerShell Menu Script with CSV Creation
# This script creates a CSV file with utility script details and allows you to execute them from a menu.

function Show-Menu {
    param (
        [array]$menuItems
    )
    Write-Host "==== Utility Script Menu ====" -ForegroundColor Cyan
    for ($i = 0; $i -lt $menuItems.Length; $i++) {
        Write-Host "$($i + 1). $($menuItems[$i].Description)"
    }
    Write-Host "0. Exit"
    Write-Host "============================="
}

function Get-UserChoice {
    param (
        [int]$maxChoice
    )
    do {
        $choice = Read-Host "Enter your choice (0-$maxChoice)"
    } while ($choice -notmatch '^\d+$' -or [int]$choice -lt 0 -or [int]$choice -gt $maxChoice)
    return [int]$choice
}

function Execute-UtilityScript {
    param (
        [string]$scriptPath
    )
    . $scriptPath
}

function Load-UtilityScripts {
    param (
        [string]$csvFilePath
    )
    $scripts = Import-Csv -Path $csvFilePath | Where-Object { $_.ActiveYN -eq 'Y' }
    return $scripts
}

function Create-ExampleCSV {
    param (
        [string]$csvFilePath
    )
    $exampleData = @(
        [PSCustomObject]@{ Description = "Example Utility Script"; Path = "$env:USERPROFILE\exampleScript.ps1"; Filename = "exampleScript.ps1"; ActiveYN = "Y" }
    )
    $exampleData | Export-Csv -Path $csvFilePath -NoTypeInformation
}

# Path to the CSV file
$csvFilePath = "$env:USERPROFILE\utilityScripts.csv"

# Create the CSV file with example data if it doesn't exist
if (-Not (Test-Path -Path $csvFilePath)) {
    Create-ExampleCSV -csvFilePath $csvFilePath
    Write-Host "Example CSV file created at $csvFilePath" -ForegroundColor Green
} else {
    Write-Host "CSV file already exists at $csvFilePath" -ForegroundColor Yellow
}

# Load utility scripts from CSV
$utilityScripts = Load-UtilityScripts -csvFilePath $csvFilePath

# Main menu loop
do {
    Show-Menu -menuItems $utilityScripts
    $choice = Get-UserChoice -maxChoice $utilityScripts.Length
    if ($choice -gt 0) {
        Execute-UtilityScript -scriptPath $utilityScripts[$choice - 1].Path
    }
} while ($choice -ne 0)

Write-Host "Goodbye!" -ForegroundColor Green

#Requires -Version 5.1
<#
.SYNOPSIS
    Maps the network drives listed in drives.csv next to this script.

.DESCRIPTION
    Reads columns DriveLetter and NetworkPath. Prompts once with Get-Credential.
    Each letter that is not already present is mapped with New-PSDrive -Persist.
    Letters that are already connected are left alone.

    The drives.csv in this folder uses placeholder servers (FILESERVER01,
    FILESERVER02) and placeholder share names. Put the real paths in a local
    copy, and keep that copy out of git.

.EXAMPLE
    .\Connect-NetworkDrives.ps1
#>
$csvPath = Join-Path $PSScriptRoot "drives.csv"
$drives = Import-Csv -Path $csvPath
$credential = Get-Credential
Clear-Host

foreach ($drive in $drives) {
    $driveLetter = $drive.DriveLetter
    $networkPath = $drive.NetworkPath

    if (!(Test-Path -Path "$driveLetter\")) {
        Write-Output "$driveLetter is not connected. Attempting to reconnect..."
        New-PSDrive -Name $driveLetter.TrimEnd(':') -PSProvider FileSystem -Root $networkPath -Credential $credential -Persist
        if (Test-Path -Path "$driveLetter\") {
            Write-Output "$driveLetter has been successfully reconnected."
        } else {
            Write-Output "Failed to reconnect $driveLetter."
        }
    } else {
        Write-Output "$driveLetter is already connected."
    }
}

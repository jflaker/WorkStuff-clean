#Requires -Version 5.1
<#
.SYNOPSIS
    Deletes the current user's default Chrome and Edge profiles, and the Firefox profiles folder.

.DESCRIPTION
    Removes these paths when they exist:
      %LOCALAPPDATA%\Google\Chrome\User Data\Default
      %LOCALAPPDATA%\Microsoft\Edge\User Data\Default
      %APPDATA%\Mozilla\Firefox\Profiles

    Does not stop the browsers first, so a running browser can lock files and
    Remove-Item will fail on those. Chrome and Edge profiles other than Default
    are left in place. Firefox loses the whole Profiles folder.

    Clear-BrowserUserData.ps1 stops the three browsers and deletes the full
    Chrome and Edge user-data trees as well as the Firefox profiles folder.

.EXAMPLE
    .\Remove-BrowserProfileFolders.ps1
#>
# Define browser profile paths
$browserProfiles = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default",
    "$env:APPDATA\Mozilla\Firefox\Profiles"
)

# Loop through each path and remove folders
foreach ($profile in $browserProfiles) {
    if (Test-Path $profile) {
        Remove-Item -Path $profile -Recurse -Force
        Write-Output "Deleted: $profile"
    } else {
        Write-Output "Not found: $profile"
    }
}

Write-Output "Browser history cleanup complete!"

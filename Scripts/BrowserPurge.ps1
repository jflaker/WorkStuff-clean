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

# Function to delete Chrome and Firefox data folders
function Clear-BrowserData {
    Write-Output "Clearing all Chrome and Firefox data..."
    
    # Stop browser processes
    Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
    Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue

    # Delete Chrome data folder
    $chromeDataPath = "$env:LocalAppData\Google\Chrome\User Data"
    if (Test-Path $chromeDataPath) {
        Remove-Item -Path $chromeDataPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Chrome data folder deleted."
    } else {
        Write-Output "Chrome data folder not found."
    }

    # Delete Firefox data folder
    $firefoxDataPath = "$env:AppData\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxDataPath) {
        Remove-Item -Path $firefoxDataPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Firefox data folder deleted."
    } else {
        Write-Output "Firefox data folder not found."
    }

    Write-Output "All browser data has been cleared."
    Pause
}

# Execute the function
Clear-BrowserData

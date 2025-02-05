# Function to delete browser data folders
function Clear-BrowserData {
    Write-Output "Clearing all Chrome, Firefox, and Edge data..."
    
    # Stop browser processes
    Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
    Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
    Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue

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

    # Delete Edge data folder
    $edgeDataPath = "$env:LocalAppData\Microsoft\Edge\User Data"
    if (Test-Path $edgeDataPath) {
        Remove-Item -Path $edgeDataPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Edge data folder deleted."
    } else {
        Write-Output "Edge data folder not found."
    }

    Write-Output "All browser data has been cleared."
    Pause
}

# Execute the function
Clear-BrowserData

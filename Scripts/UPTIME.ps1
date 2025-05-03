# Get system uptime details
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$uptime = $osInfo.LastBootUpTime
$elapsed = (Get-Date) - $uptime

# Format current time
$currentTime = Get-Date -Format "HH:mm:ss"

# Retrieve active user sessions, excluding background services
$userCount = (query user 2>$null | Where-Object { $_ -match "Active" -and $_ -notmatch "services" } | Measure-Object).Count

# Construct output to mimic Linux uptime format
$formattedUptime = "{0} up {1} days, {2}:{3}, {4} users, load average: 0.00, 0.01, 0.05" -f `
    $currentTime, $elapsed.Days, $elapsed.Hours, $elapsed.Minutes, $userCount

# Display formatted uptime
Write-Output $formattedUptime

# Pause to keep the window open
Write-Host "`nPress any key to exit..." -NoNewline
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
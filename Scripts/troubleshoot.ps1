# PowerShell Script: Startup Troubleshooting Toolkit

 

# Run System File Checker

Write-Host "Running SFC..."

sfc /scannow

 

# Run DISM Health Restore

Write-Host "Running DISM..."

DISM /Online /Cleanup-Image /RestoreHealth

 

# Check Disk Health

Write-Host "Checking Physical Disk Health..."

Get-PhysicalDisk | Select MediaType, Size, SerialNumber, HealthStatus

 

# Schedule CHKDSK (will prompt for reboot)

Write-Host "Scheduling CHKDSK..."

chkdsk C: /f /r

 

# Check SMART Predictive Failure Status

Write-Host "Checking SMART Predictive Failure..."

Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus

 

# Check for Problem Devices

Write-Host "Checking for Problem Devices..."

Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | Select Name, Status

 

# List Startup Programs

Write-Host "Listing Startup Programs..."

Get-CimInstance Win32_StartupCommand | Select Name, Command, Location

 

# Get Recent System Errors

Write-Host "Getting Recent System Errors..."

Get-EventLog -LogName System -EntryType Error -Newest 20 | Format-Table TimeGenerated, Source, EventID, Message -AutoSize

 

# Enable Boot Logging

Write-Host "Enabling Boot Logging..."

bcdedit /set {current} bootlog Yes


 

# Define the time range for log search (last 30 days)
$startTime = (Get-Date).AddDays(-30)

# Gather error and warning events from common logs
$logsToCheck = @("System", "Application", "Security")
$eventList = foreach ($log in $logsToCheck) {
    Get-WinEvent -FilterHashtable @{
        LogName = $log
        Level = 1, 2, 3   # 1=Critical, 2=Error, 3=Warning
        StartTime = $startTime
    } -ErrorAction SilentlyContinue | Select-Object TimeCreated, LevelDisplayName, LogName, Id, Message
}

# Define the output path
$desktopPath = [Environment]::GetFolderPath("Desktop")
$outputPath = Join-Path $desktopPath "EventLogReport.csv"

# Write custom header row
$headerInfo = "Computer: $env:COMPUTERNAME | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $outputPath -Value $headerInfo
Add-Content -Path $outputPath -Value ""  # Add blank line for spacing

# Export event data
$eventList | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8 -Append

Write-Output "30-day log report saved to $outputPath"

# Define the path for the report (saved to the Desktop)
$reportPath = [System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'), "SystemLogReport.txt")

# Increase log span to 30 days
$startDate = (Get-Date).AddDays(-30)

# Define which log sources to check
$logSources = @("System", "Application")

# Prepare the header for the report
$report = @()
$report += "============== System Health Check Report =============="
$report += "Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Date Range: $startDate to $(Get-Date)"
$report += "=========================================================="
$report += ""

# Loop through each log source
foreach ($log in $logSources) {
    $report += "`n[$log Log]"
    
    # Retrieve only Warning (Level 3) and Error (Level 2) events
    $events = Get-WinEvent -FilterHashtable @{LogName=$log; Level=2,3; StartTime=$startDate} -ErrorAction SilentlyContinue

    if ($events) {
        # Create summary counts for errors and warnings
        $errorCount = ($events | Where-Object { $_.LevelDisplayName -eq "Error" }).Count
        $warningCount = ($events | Where-Object { $_.LevelDisplayName -eq "Warning" }).Count
        
        $report += "Summary: Total Errors = $errorCount, Total Warnings = $warningCount"
        $report += "--------------------------------------------------------------"
        
        # Sort events by timestamp for easier reading
        foreach ($event in $events | Sort-Object TimeCreated) {
            # Extract the first line of the message for a concise preview
            $messageSummary = $event.Message.Split("`n")[0]
            $report += "{0:yyyy-MM-dd HH:mm:ss} | {1} | Event ID: {2} | {3}" -f $event.TimeCreated, $event.LevelDisplayName, $event.Id, $messageSummary
        }
    }
    else {
        $report += "No warning or error entries found for the past 30 days in the $log log."
    }
    
    $report += "`n=============================================================="
}

# Output the final report to the Desktop
$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Detailed report saved to $reportPath"

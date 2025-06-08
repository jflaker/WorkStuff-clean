$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$now = Get-Date
$uptimeSpan = $now - $uptime
$users = (Get-Process | Where-Object {$_.ProcessName -eq "explorer"}).Count # Rough estimate of interactive users
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue / 100

# Generate mock load averages
$loadAvgValues = @($cpuLoad, ($cpuLoad + (Get-Random -Minimum -0.05 -Maximum 0.05)), ($cpuLoad + (Get-Random -Minimum -0.1 -Maximum 0.1)))
$loadAvg = "{0:N2}, {1:N2}, {2:N2}" -f $loadAvgValues[0], $loadAvgValues[1], $loadAvgValues[2]

# Format output to resemble Linux uptime
$output = "{0} up {1} days, {2:hh} hours, {2:mm} minutes, {3} users, load average: {4}" -f $now.ToString("hh:mm:ss tt"), $uptimeSpan.Days, $uptimeSpan, $users, $loadAvg

Write-Output $output

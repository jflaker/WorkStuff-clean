#!/usr/bin/env pwsh


# Importing Active Directory module
Import-Module ActiveDirectory

# Retrieving all computer objects from Active Directory
$computers = Get-ADComputer -Filter *

# Looping through each computer object
foreach ($computer in $computers) {
    # Checking if the computer is up and running
    if (Test-Connection -ComputerName $computer.Name -Count 1 -Quiet) {
        # Retrieving the uptime of the computer
        $uptime = (Get-WmiObject -ComputerName $computer.Name -Class Win32_OperatingSystem |
                   Select-Object @{Name = "Uptime"; Expression = {((Get-Date) - $_.LastBootUpTime)}}).Uptime
        # Converting uptime to days
        $uptimeDays = $uptime.TotalDays

        # Checking if uptime is greater than 30 days
        if ($uptimeDays -gt 30) {
            # Checking if current time is after 6 PM on a weekday or anytime on the weekend
            $currentDayOfWeek = (Get-Date).DayOfWeek
            if (($currentDayOfWeek -ne "Saturday" -and $currentDayOfWeek -ne "Sunday" -and (Get-Date).Hour -ge 18) `
                 -or ($currentDayOfWeek -eq "Saturday" -or $currentDayOfWeek -eq "Sunday")) {
                # Checking if the computer is idle for at least 45 minutes or not logged into
                $isIdle = (Get-CimInstance -ComputerName $computer.Name Win32_ComputerSystem | 
                           Select-Object -ExpandProperty UserName) -eq $null
                if ($isIdle) {
                    $lastInput = (Get-CimInstance -ComputerName $computer.Name -Class Win32_ComputerSystem |
                                  Select-Object -ExpandProperty LastInputTime)
                    $idleTime = (New-TimeSpan -Start $lastInput)
                    if ($idleTime.TotalMinutes -ge 45) {
                        # Scheduling a reboot of the computer
                        Restart-Computer -ComputerName $computer.Name -Force
                    }
                }
            }
        }
    } else {
        # Writing to a spreadsheet with the reason why the computer could not be contacted
        $reason = "The computer is not responding"
        Add-Content -Path "C:\RebootScheduleLog.csv" -Value "$($computer.Name),$($reason)"
    }
}

# Checking if the spreadsheet has at least 1 entry, and emailing it to admin@example.com
if ((Import-Csv -Path "C:\RebootScheduleLog.csv").Count -ge 1) {
    $emailBody = "There are issues scheduling reboots on some computers in Active Directory. Please check the attached log file."
    Send-MailMessage -To "admin@example.com" -Subject "Reboot Schedule Log" -Body $emailBody -Attachment "C:\RebootScheduleLog.csv" -SmtpServer "smtp.example.com"
}

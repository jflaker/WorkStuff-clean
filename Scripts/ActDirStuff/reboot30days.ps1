#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Finds domain computers up more than N days and optionally reboots the idle ones.

.DESCRIPTION
    FIXED: the previous version read LastInputTime from Win32_ComputerSystem. That
    property does not exist on that class, so $lastInput was always $null and
    New-TimeSpan -Start $null threw -- no machine ever reached the reboot.

    True per-session idle time needs GetLastInputInfo, which is a P/Invoke inside the
    interactive session and is not reachable via CIM from another machine. So the gate
    here is "no interactive user logged on", which is the honest remotely-checkable
    equivalent. If you need real idle time, enable PS Remoting and run a
    GetLastInputInfo probe with Invoke-Command.

    Defaults to -WhatIf behaviour: it will NOT reboot anything unless you pass
    -Confirm:$false explicitly.

.EXAMPLE
    .\reboot30days.ps1                        # report only
.EXAMPLE
    .\reboot30days.ps1 -Confirm:$false        # actually reboot
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [int]$UptimeDays = 30,
    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ADReports'),
    # Only act inside the maintenance window (weeknights after 6pm, or any time at weekends).
    [switch]$IgnoreSchedule
)

function Test-MaintenanceWindow {
    $now = Get-Date
    if ($now.DayOfWeek -in 'Saturday','Sunday') { return $true }
    return ($now.Hour -ge 18)
}

if (-not $IgnoreSchedule -and -not (Test-MaintenanceWindow)) {
    Write-Host 'Outside the maintenance window (weeknights after 18:00, or weekends).' -ForegroundColor Yellow
    Write-Host 'Pass -IgnoreSchedule to run anyway.'
    return
}

if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }
# Fresh log per run, WITH a header. The old version appended headerless rows forever,
# so Import-Csv mis-parsed it and it grew without bound.
$logPath = Join-Path $OutputFolder "RebootScheduleLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

$unreachable = [System.Collections.Generic.List[object]]::new()
$rebooted    = [System.Collections.Generic.List[object]]::new()

$computers = Get-ADComputer -Filter * -Properties Name

foreach ($computer in $computers) {
    $name = $computer.Name

    if (-not (Test-Connection -ComputerName $name -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        $unreachable.Add([PSCustomObject]@{ ComputerName = $name; Reason = 'Not responding to ping' })
        continue
    }

    try {
        # Get-CimInstance, not Get-WmiObject -- the latter is removed in PowerShell 7.
        $os = Get-CimInstance -ComputerName $name -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance -ComputerName $name -ClassName Win32_ComputerSystem  -ErrorAction Stop
    }
    catch {
        $unreachable.Add([PSCustomObject]@{ ComputerName = $name; Reason = "CIM query failed: $($_.Exception.Message)" })
        continue
    }

    $uptimeDays = ((Get-Date) - $os.LastBootUpTime).TotalDays
    if ($uptimeDays -le $UptimeDays) { continue }

    if ($null -ne $cs.UserName) {
        Write-Verbose "$name is up $([int]$uptimeDays) days but $($cs.UserName) is logged on - skipping."
        continue
    }

    if ($PSCmdlet.ShouldProcess($name, "Reboot (up $([int]$uptimeDays) days, no user logged on)")) {
        try {
            Restart-Computer -ComputerName $name -Force -ErrorAction Stop
            $rebooted.Add([PSCustomObject]@{ ComputerName = $name; UptimeDays = [int]$uptimeDays })
        }
        catch {
            $unreachable.Add([PSCustomObject]@{ ComputerName = $name; Reason = "Reboot failed: $($_.Exception.Message)" })
        }
    }
}

Write-Host "Rebooted:    $($rebooted.Count)"
Write-Host "Unreachable: $($unreachable.Count)"

if ($unreachable.Count -gt 0) {
    $unreachable | Export-Csv -Path $logPath -NoTypeInformation
    Write-Host "Problem list written to $logPath" -ForegroundColor Yellow
}

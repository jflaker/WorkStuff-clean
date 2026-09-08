#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Startup troubleshooting toolkit: component store repair, disk health, boot config.

.DESCRIPTION
    REWRITTEN. Changes from the previous version:

      * DISM now runs BEFORE SFC. SFC repairs system files by copying known-good
        copies OUT of the component store; DISM /RestoreHealth repairs the store
        itself. Running SFC first means that if the store is corrupt, SFC fails and
        then DISM fixes the thing SFC needed. The old order made the common case
        fail.
      * chkdsk /f /r is now OPT-IN (-RunChkdsk). /r does a full surface scan at next
        boot and can take HOURS on a spinning disk, leaving the machine unusable.
        Firing that unattended is not a diagnostic, it is an outage.
      * Boot logging is opt-in (-EnableBootLog) since it modifies BCD.
      * Get-WmiObject -> Get-CimInstance and Get-EventLog -> Get-WinEvent. Both old
        cmdlets are removed in PowerShell 7; the script would not run there at all.
      * Everything is transcripted to a log file instead of scrolling past.

.EXAMPLE
    .\troubleshoot.ps1
.EXAMPLE
    .\troubleshoot.ps1 -RunChkdsk -EnableBootLog
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RunChkdsk,
    [switch]$EnableBootLog,
    [string]$LogFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Diagnostics')
)

if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$log = Join-Path $LogFolder "Troubleshoot_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $log | Out-Null

try {
    Write-Host '=== 1. DISM component store repair (runs BEFORE SFC) ===' -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'DISM /Online /Cleanup-Image /RestoreHealth')) {
        DISM /Online /Cleanup-Image /RestoreHealth
    }

    Write-Host "`n=== 2. System File Checker ===" -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'sfc /scannow')) {
        sfc /scannow
    }

    Write-Host "`n=== 3. Physical disk health ===" -ForegroundColor Cyan
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType,
        @{N='Size(GB)';E={[math]::Round($_.Size/1GB,1)}}, SerialNumber, HealthStatus, OperationalStatus |
        Format-Table -AutoSize

    Write-Host "`n=== 4. SMART predictive failure ===" -ForegroundColor Cyan
    Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue |
        Select-Object InstanceName, PredictFailure, Reason | Format-Table -AutoSize

    Write-Host "`n=== 5. Problem devices ===" -ForegroundColor Cyan
    $bad = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    if ($bad) { $bad | Select-Object Name, Status, ConfigManagerErrorCode | Format-Table -AutoSize }
    else      { Write-Host 'No problem devices reported.' -ForegroundColor Green }

    Write-Host "`n=== 6. Startup programs ===" -ForegroundColor Cyan
    Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location | Format-Table -AutoSize

    Write-Host "`n=== 7. Recent system errors (last 20) ===" -ForegroundColor Cyan
    Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 20 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, ProviderName,
            @{N='Message';E={($_.Message -split "`n")[0]}} | Format-Table -AutoSize

    if ($EnableBootLog) {
        Write-Host "`n=== 8. Enabling boot logging ===" -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess('BCD', 'Enable boot logging')) {
            bcdedit /set '{current}' bootlog Yes
            Write-Host 'Boot log will be written to C:\Windows\ntbtlog.txt after the next restart.'
        }
    }

    if ($RunChkdsk) {
        Write-Host "`n=== 9. Scheduling CHKDSK ===" -ForegroundColor Yellow
        Write-Warning 'chkdsk /f /r runs at next boot and can take SEVERAL HOURS on a mechanical disk.'
        Write-Warning 'The machine is unusable while it runs.'
        if ($PSCmdlet.ShouldProcess('C:', 'chkdsk /f /r at next boot')) {
            'Y' | chkdsk C: /f /r
        }
    } else {
        Write-Host "`nCHKDSK not scheduled. Pass -RunChkdsk if you want it." -ForegroundColor DarkGray
    }
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "`nFull log: $log" -ForegroundColor Green
}

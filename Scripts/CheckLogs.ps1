#Requires -Version 5.1
<#
.SYNOPSIS
    Pulls Windows event-log errors/warnings from one or more REMOTE machines and
    summarises them into a triage report on YOUR machine.

.DESCRIPTION
    Designed to be run from a technician's workstation against remote computers over
    WinRM. The design goal is that the person sitting at the target machine never
    notices it running.

    How that goal is met:

      * The REMOTE side does the absolute minimum: one Get-WinEvent query, server-side
        filtered to just errors and warnings in the window, capped by -MaxEvents. It
        returns raw event records and nothing else.
      * ALL the expensive work -- grouping, sorting, building the report -- happens
        locally on YOUR machine. The target never spends CPU on it, so it does not
        slow to a crawl for the user.
      * The remote query runs at BelowNormal process priority as a second belt.
      * Event messages are rendered ON the target (where the provider metadata lives),
        so they come back as complete strings. Pulling raw events cross-machine and
        rendering locally often yields blank messages -- this avoids that.

    One machine failing (offline, WinRM off, access denied) does not stop the others;
    each is reported and the sweep continues.

    Requires WinRM on the targets (Enable-PSRemoting -Force) and that your account can
    read their event logs.

.PARAMETER ComputerName
    One or more targets. Omit to run against the local machine.

.EXAMPLE
    .\CheckLogs.ps1 -ComputerName PC-104
.EXAMPLE
    .\CheckLogs.ps1 -ComputerName PC-104,PC-105,PC-106 -Days 7
.EXAMPLE
    .\CheckLogs.ps1 -ComputerName (Get-Content .\machines.txt) -Credential (Get-Credential)
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [pscredential]$Credential,

    [ValidateRange(1, 365)]
    [int]$Days = 30,

    [string[]]$LogSources = @('System', 'Application'),

    [switch]$IncludeSecurity,

    # Hard cap on events pulled PER LOG PER MACHINE. Protects your network and the
    # report from a badly-infected box dumping hundreds of thousands of events.
    [int]$MaxEvents = 20000,

    # Chronological detail lines per log in the report. Summary counts are always full.
    [int]$MaxDetail = 300,

    [switch]$Csv,

    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Diagnostics')
)

# Event IDs worth surfacing on their own -- the ones that usually explain a sick box.
$significant = @{
    'Microsoft-Windows-Kernel-Power'             = @{ 41 = 'Unexpected shutdown / power loss (did not shut down cleanly)' }
    'Microsoft-Windows-WER-SystemErrorReporting' = @{ 1001 = 'Bugcheck (blue screen)' }
    'EventLog'                                   = @{ 6008 = 'Previous shutdown was unexpected' }
    'disk'                                       = @{ 7 = 'Bad block on disk'; 51 = 'Paging error on disk'; 153 = 'IO operation retried' }
    'Ntfs'                                       = @{ 55 = 'Filesystem corruption detected (run chkdsk)'; 137 = 'Volume transaction issue' }
    'Service Control Manager'                    = @{ 7031 = 'Service terminated unexpectedly'; 7034 = 'Service terminated unexpectedly'; 7000 = 'Service failed to start' }
    'Application Error'                          = @{ 1000 = 'Application crash' }
}

# ---------------------------------------------------------------------------------
# This runs ON THE TARGET. Keep it minimal: query, render, return. No processing.
# ---------------------------------------------------------------------------------
$remoteFetch = {
    param($LogSources, $Days, $MaxEvents)

    # Be a good guest: drop our own priority so we never elbow the logged-on user.
    try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch { }

    $start = (Get-Date).AddDays(-$Days)
    $out   = [System.Collections.Generic.List[object]]::new()

    foreach ($log in $LogSources) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 2, 3; StartTime = $start } `
                        -MaxEvents $MaxEvents -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -match 'No events were found') { continue }
            # Surface the reason to the caller as a sentinel object.
            $out.Add([pscustomobject]@{ __LogError = $log; Reason = $_.Exception.Message })
            continue
        }
        foreach ($e in $events) {
            # Render the message HERE, where provider metadata exists.
            $out.Add([pscustomobject]@{
                TimeCreated = $e.TimeCreated
                LogName     = $log
                Level       = $e.Level
                LevelName   = $e.LevelDisplayName
                Provider    = $e.ProviderName
                Id          = $e.Id
                Message     = ($e.Message -split "`r?`n")[0].Trim()
            })
        }
    }
    ,$out.ToArray()
}

# ---------------------------------------------------------------------------------
# LOCAL: build the per-machine report from the raw events the target returned.
# ---------------------------------------------------------------------------------
function Format-MachineReport {
    param([string]$Machine, [object[]]$Events, [System.Collections.Generic.List[string]]$R)

    $R.Add('')
    $R.Add('#' * 78)
    $R.Add("#  $Machine")
    $R.Add('#' * 78)

    $logErrors = $Events | Where-Object { $_.PSObject.Properties.Name -contains '__LogError' }
    $events    = $Events | Where-Object { $_.PSObject.Properties.Name -notcontains '__LogError' }

    foreach ($le in $logErrors) {
        if ($le.Reason -match 'Access is denied|UnauthorizedAccess') {
            $R.Add("  '$($le.__LogError)' log: ACCESS DENIED (need admin rights on $Machine).")
        } else {
            $R.Add("  '$($le.__LogError)' log: $($le.Reason)")
        }
    }

    if (-not $events) { $R.Add('  No errors or warnings in the window.'); return }

    foreach ($log in ($events.LogName | Sort-Object -Unique)) {
        $set = @($events | Where-Object { $_.LogName -eq $log })
        $err = @($set | Where-Object { $_.Level -eq 2 }).Count
        $wrn = @($set | Where-Object { $_.Level -eq 3 }).Count
        $R.Add('')
        $R.Add("### $log  --  $err error(s), $wrn warning(s), $($set.Count) total")
        $R.Add('-' * 78)

        $R.Add('Most frequent (provider / id):')
        $set | Group-Object Provider, Id | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object {
            $s = $_.Group[0]
            $first = ($_.Group | Measure-Object TimeCreated -Minimum).Minimum
            $last  = ($_.Group | Measure-Object TimeCreated -Maximum).Maximum
            $t = $s.Message; if ($t.Length -gt 84) { $t = $t.Substring(0, 81) + '...' }
            $R.Add(('  {0,6}x  {1,-34} id {2,-6} {3}' -f $_.Count, $s.Provider, $s.Id, $t))
            $R.Add(('          first {0:yyyy-MM-dd HH:mm}  last {1:yyyy-MM-dd HH:mm}' -f $first, $last))
        }

        $hits = $set | Where-Object {
            $significant.ContainsKey($_.Provider) -and $significant[$_.Provider].ContainsKey([int]$_.Id)
        }
        if ($hits) {
            $R.Add('')
            $R.Add('NOTABLE:')
            $hits | Group-Object Provider, Id | Sort-Object Count -Descending | ForEach-Object {
                $s = $_.Group[0]
                $R.Add(('  {0,4}x  {1} (id {2}) - {3}' -f $_.Count, $s.Provider, $s.Id, $significant[$s.Provider][[int]$s.Id]))
                $R.Add(('          most recent: {0:yyyy-MM-dd HH:mm:ss}' -f ($_.Group | Measure-Object TimeCreated -Maximum).Maximum))
            }
        }

        $detail = $set | Sort-Object TimeCreated -Descending | Select-Object -First $MaxDetail
        $R.Add('')
        $R.Add("Detail (most recent $($detail.Count) of $($set.Count), newest first):")
        foreach ($e in $detail) {
            $R.Add(('  {0:yyyy-MM-dd HH:mm:ss} | {1,-7} | {2,-30} | {3,-6} | {4}' -f `
                $e.TimeCreated, $e.LevelName, $e.Provider, $e.Id, $e.Message))
        }
        if ($set.Count -gt $MaxDetail) {
            $R.Add("  ... $($set.Count - $MaxDetail) older entries omitted (use -MaxDetail or -Csv).")
        }
    }
}

# ---------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------
if ($IncludeSecurity) { $LogSources += 'Security' }
if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }

$stamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $OutputFolder "SystemLogReport_$stamp.txt"
$report     = [System.Collections.Generic.List[string]]::new()
$allEvents  = [System.Collections.Generic.List[object]]::new()

$report.Add('=' * 78)
$report.Add("  Event Log Triage")
$report.Add("  Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') by $env:USERNAME on $env:COMPUTERNAME")
$report.Add("  Window    : last $Days day(s)")
$report.Add("  Targets   : $($ComputerName -join ', ')")
$report.Add('=' * 78)

$invokeCommon = @{ ScriptBlock = $remoteFetch; ArgumentList = @($LogSources, $Days, $MaxEvents) }
if ($Credential) { $invokeCommon.Credential = $Credential }

foreach ($machine in $ComputerName) {
    Write-Host "Querying $machine..." -ForegroundColor Cyan
    $isLocal = $machine -in @($env:COMPUTERNAME, 'localhost', '.', '127.0.0.1')

    try {
        if ($isLocal) {
            # No WinRM hop needed for the local box.
            $raw = & $remoteFetch $LogSources $Days $MaxEvents
        } else {
            $raw = Invoke-Command @invokeCommon -ComputerName $machine -ErrorAction Stop
        }
    }
    catch {
        $report.Add('')
        $report.Add('#' * 78)
        $report.Add("#  $machine  --  UNREACHABLE")
        $report.Add("#  $($_.Exception.Message)")
        $report.Add('#' * 78)
        Write-Warning "$machine unreachable: $($_.Exception.Message)"
        continue
    }

    $raw = @($raw)
    Format-MachineReport -Machine $machine -Events $raw -R $report

    $raw | Where-Object { $_.PSObject.Properties.Name -notcontains '__LogError' } |
        ForEach-Object { $allEvents.Add(($_ | Add-Member -NotePropertyName Computer -NotePropertyValue $machine -PassThru)) }
}

$report.Add('')
$report.Add('=' * 78)
Set-Content -Path $reportPath -Value $report -Encoding UTF8
Write-Host "Report: $reportPath" -ForegroundColor Green

if ($Csv -and $allEvents.Count) {
    $csvPath = Join-Path $OutputFolder "SystemLogEvents_$stamp.csv"
    $allEvents |
        Select-Object Computer, TimeCreated, LogName, LevelName, Provider, Id, Message |
        Sort-Object Computer, TimeCreated -Descending |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "CSV:    $csvPath" -ForegroundColor Green
}

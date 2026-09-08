#Requires -Version 5.1
<#
.SYNOPSIS
    Summarises Windows event log errors and warnings into a triage report.

.DESCRIPTION
    Moved here from the repository root.

    Changes from the previous version:

    * SUMMARY FIRST. The old version wrote a chronological dump of every error and
      warning. Thirty days of System + Application on a busy machine is easily tens
      of thousands of lines, and the thing you actually want -- "this one provider
      threw 4,000 errors" -- is invisible in it. This groups by provider and event ID
      with counts and first/last seen, then shows detail underneath.

    * KNOWN-SIGNIFICANT EVENTS called out separately: unexpected shutdowns, bugchecks,
      disk errors, filesystem corruption, service crashes. These are the ones worth
      looking at first on a machine that is misbehaving.

    * PERFORMANCE. The old version built the report with $report += in a loop, which
      reallocates the whole array on every append -- O(n^2). At 50,000 events that is
      minutes of CPU doing nothing useful. Uses a List[string] now.

    * -MaxDetail caps the chronological section so the report stays readable.

    * Errors from Get-WinEvent are reported rather than swallowed by
      -ErrorAction SilentlyContinue, so "no results" and "access denied" stop looking
      identical. (The Security log needs elevation; without it you got a silent blank.)

.EXAMPLE
    .\CheckLogs.ps1
.EXAMPLE
    .\CheckLogs.ps1 -Days 7 -MaxDetail 200
.EXAMPLE
    .\CheckLogs.ps1 -Days 30 -IncludeSecurity -Csv
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 365)]
    [int]$Days = 30,

    [string[]]$LogSources = @('System', 'Application'),

    # Security needs an elevated session.
    [switch]$IncludeSecurity,

    # Cap the chronological detail section. Summary counts are always complete.
    [int]$MaxDetail = 500,

    # Also emit a .csv of every event, for filtering in Excel.
    [switch]$Csv,

    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Diagnostics')
)

# Event IDs worth surfacing on their own -- the ones that usually explain a sick machine.
$significant = @{
    'Microsoft-Windows-Kernel-Power'   = @{ 41  = 'Unexpected shutdown / power loss (machine did not shut down cleanly)' }
    'Microsoft-Windows-WER-SystemErrorReporting' = @{ 1001 = 'Bugcheck (blue screen)' }
    'EventLog'                         = @{ 6008 = 'Previous shutdown was unexpected' }
    'disk'                             = @{ 7 = 'Bad block on disk'; 51 = 'Paging error on disk'; 153 = 'IO operation retried' }
    'Ntfs'                             = @{ 55 = 'Filesystem corruption detected (run chkdsk)'; 137 = 'Volume transaction issue' }
    'Service Control Manager'          = @{ 7031 = 'Service terminated unexpectedly'; 7034 = 'Service terminated unexpectedly'; 7000 = 'Service failed to start' }
    'Application Error'                = @{ 1000 = 'Application crash' }
}

if ($IncludeSecurity) { $LogSources += 'Security' }

if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null }
$stamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $OutputFolder "SystemLogReport_$stamp.txt"

$startDate = (Get-Date).AddDays(-$Days)
$report    = [System.Collections.Generic.List[string]]::new()
$allEvents = [System.Collections.Generic.List[object]]::new()

function Add-Line { param([string]$Text = '') ; $report.Add($Text) }

Add-Line ('=' * 78)
Add-Line "  System Health Check - $env:COMPUTERNAME"
Add-Line "  Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "  Window    : last $Days day(s), from $($startDate.ToString('yyyy-MM-dd HH:mm'))"
Add-Line ('=' * 78)

foreach ($log in $LogSources) {
    Add-Line
    Add-Line "### $log log"
    Add-Line ('-' * 78)

    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 2, 3; StartTime = $startDate } -ErrorAction Stop
    }
    catch [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] {
        Add-Line "Log '$log' not found on this machine."; continue
    }
    catch [System.UnauthorizedAccessException] {
        Add-Line "ACCESS DENIED reading '$log'. Re-run this script as Administrator."; continue
    }
    catch {
        # Get-WinEvent throws a plain exception when a filter matches nothing.
        if ($_.Exception.Message -match 'No events were found') {
            Add-Line "No errors or warnings in the last $Days day(s)."; continue
        }
        Add-Line "Could not read '$log': $($_.Exception.Message)"; continue
    }

    $events | ForEach-Object { $allEvents.Add($_) }

    $errors   = @($events | Where-Object { $_.Level -eq 2 }).Count
    $warnings = @($events | Where-Object { $_.Level -eq 3 }).Count
    Add-Line "Totals: $errors error(s), $warnings warning(s), $($events.Count) combined."
    Add-Line

    # --- what is actually noisy -------------------------------------------------
    Add-Line 'Most frequent (provider / event ID):'
    $events | Group-Object ProviderName, Id |
        Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object {
            $sample = $_.Group[0]
            $first  = ($_.Group | Measure-Object TimeCreated -Minimum).Minimum
            $last   = ($_.Group | Measure-Object TimeCreated -Maximum).Maximum
            $text   = ($sample.Message -split "`r?`n")[0].Trim()
            if ($text.Length -gt 90) { $text = $text.Substring(0, 87) + '...' }
            Add-Line ("  {0,6}x  {1,-38} id {2,-6} {3}" -f $_.Count, $sample.ProviderName, $sample.Id, $text)
            Add-Line ("          first {0:yyyy-MM-dd HH:mm}  last {1:yyyy-MM-dd HH:mm}" -f $first, $last)
        }

    # --- the ones that usually matter -------------------------------------------
    $hits = $events | Where-Object {
        $significant.ContainsKey($_.ProviderName) -and $significant[$_.ProviderName].ContainsKey([int]$_.Id)
    }
    if ($hits) {
        Add-Line
        Add-Line 'NOTABLE EVENTS:'
        $hits | Group-Object ProviderName, Id | Sort-Object Count -Descending | ForEach-Object {
            $s = $_.Group[0]
            Add-Line ("  {0,4}x  {1} (id {2}) - {3}" -f $_.Count, $s.ProviderName, $s.Id, $significant[$s.ProviderName][[int]$s.Id])
            Add-Line ("          most recent: {0:yyyy-MM-dd HH:mm:ss}" -f ($_.Group | Measure-Object TimeCreated -Maximum).Maximum)
        }
    }

    # --- chronological detail, capped -------------------------------------------
    Add-Line
    $detail = $events | Sort-Object TimeCreated -Descending | Select-Object -First $MaxDetail
    Add-Line "Detail (most recent $($detail.Count) of $($events.Count), newest first):"
    foreach ($e in $detail) {
        $line = ($e.Message -split "`r?`n")[0].Trim()
        Add-Line ('  {0:yyyy-MM-dd HH:mm:ss} | {1,-7} | {2,-34} | {3,-6} | {4}' -f `
            $e.TimeCreated, $e.LevelDisplayName, $e.ProviderName, $e.Id, $line)
    }
    if ($events.Count -gt $MaxDetail) {
        Add-Line "  ... $($events.Count - $MaxDetail) older entries omitted. Use -MaxDetail to show more, or -Csv for all of them."
    }
}

Add-Line
Add-Line ('=' * 78)
Set-Content -Path $reportPath -Value $report -Encoding UTF8
Write-Host "Report: $reportPath" -ForegroundColor Green

if ($Csv) {
    $csvPath = Join-Path $OutputFolder "SystemLogEvents_$stamp.csv"
    $allEvents |
        Select-Object TimeCreated, LogName, LevelDisplayName, ProviderName, Id,
            @{N='Message'; E={ ($_.Message -split "`r?`n")[0].Trim() }} |
        Sort-Object TimeCreated -Descending |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "CSV:    $csvPath" -ForegroundColor Green
}

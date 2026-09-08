#Requires -Version 5.1
<#
.SYNOPSIS
    Prints a Linux-style `uptime` line for a Windows machine, safe to ingest from Linux.

.DESCRIPTION
    Human form:
        22:01:43 up 5 days, 3:14,  2 users,  load average: 0.42, 0.38, 0.51

    Machine form (-LoadAvg), matches the first three fields of /proc/loadavg:
        0.42 0.38 0.51

    Notes on load average -- the old version faked it:

      * Linux load average is RUN-QUEUE LENGTH (threads runnable or waiting), averaged
        by the kernel over 1/5/15 min. It is NOT CPU percent. The old script sampled
        CPU once and used Get-Random to invent the 5- and 15-min columns -- pure noise.
      * Windows keeps no such history, so this samples '\System\Processor Queue Length'
        (the real analog) and keeps a small rolling history file. The 1/5/15 columns
        are averaged from actual samples in each window. Run on a schedule and the
        longer windows fill with genuine history; a cold first run repeats the current
        sample across all three, like Linux just after boot.

    Locale-safe for automated ingestion: all numbers use InvariantCulture, so the
    decimal point is always '.' regardless of the machine's regional settings. A
    German-locale box will NOT emit '0,42' and break your parser.

.PARAMETER LoadAvg
    Print only "1min 5min 15min" as space-separated invariant floats (parser-friendly).
.PARAMETER Pretty
    Emulate `uptime -p`.
.PARAMETER Since
    Emulate `uptime -s` (boot time, yyyy-MM-dd HH:mm:ss).

.EXAMPLE
    .\UPTIME.ps1
.EXAMPLE
    # From a Linux box over SSH: read the 1-minute load
    .\UPTIME.ps1 -LoadAvg | awk '{print $1}'
#>
[CmdletBinding(DefaultParameterSetName = 'Full')]
param(
    [Parameter(ParameterSetName = 'Load')]  [switch]$LoadAvg,
    [Parameter(ParameterSetName = 'Pretty')][switch]$Pretty,
    [Parameter(ParameterSetName = 'Since')] [switch]$Since,
    [string]$HistoryPath = (Join-Path $env:LOCALAPPDATA 'uptime_loadhistory.json')
)

$inv  = [System.Globalization.CultureInfo]::InvariantCulture
$os   = Get-CimInstance Win32_OperatingSystem
$boot = $os.LastBootUpTime
$now  = Get-Date
$span = $now - $boot

if ($Since) { return $boot.ToString('yyyy-MM-dd HH:mm:ss', $inv) }

# --- real load average from processor queue length ------------------------------
# Returns a [double[]] of (1min, 5min, 15min), or $null if the counter is unavailable.
function Get-LoadAverageValues {
    param([string]$Path)
    try {
        $sample = [double](Get-Counter '\System\Processor Queue Length' -ErrorAction Stop).CounterSamples[0].CookedValue
    } catch { return $null }

    $history = @()
    if (Test-Path $Path) {
        try { $history = @(Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json) } catch { $history = @() }
    }
    $cutoff  = (Get-Date).AddMinutes(-15)
    $history = @($history | Where-Object { try { [datetime]$_.t -ge $cutoff } catch { $false } })
    $history += [pscustomobject]@{ t = (Get-Date).ToString('o'); q = $sample }
    try { $history | ConvertTo-Json -Compress | Set-Content -Path $Path -Encoding UTF8 -ErrorAction Stop } catch { }

    $win = foreach ($m in 1, 5, 15) {
        $c    = (Get-Date).AddMinutes(-$m)
        $vals = @($history | Where-Object { try { [datetime]$_.t -ge $c } catch { $false } } | ForEach-Object { [double]$_.q })
        if ($vals.Count) { ($vals | Measure-Object -Average).Average } else { $sample }
    }
    [double[]]$win
}

# --- machine mode: bail out early with just the numbers -------------------------
if ($LoadAvg) {
    $v = Get-LoadAverageValues -Path $HistoryPath
    if (-not $v) { Write-Error 'Processor Queue Length counter unavailable.'; exit 1 }
    return ('{0} {1} {2}' -f $v[0].ToString('F2', $inv), $v[1].ToString('F2', $inv), $v[2].ToString('F2', $inv))
}

# --- Linux-style duration -------------------------------------------------------
function Format-Uptime {
    param([TimeSpan]$Span)
    $d = [int]$Span.Days
    if ($d -gt 0) {
        $w = if ($d -eq 1) { 'day' } else { 'days' }
        return ('{0} {1}, {2}:{3:00}' -f $d, $w, $Span.Hours, $Span.Minutes)
    }
    if ($Span.TotalMinutes -ge 60) { return ('{0}:{1:00}' -f $Span.Hours, $Span.Minutes) }
    return ('{0} min' -f $Span.Minutes)
}

if ($Pretty) {
    $parts = @()
    if ($span.Days    -gt 0) { $parts += '{0} day{1}'    -f $span.Days,    $(if ($span.Days    -ne 1) {'s'}) }
    if ($span.Hours   -gt 0) { $parts += '{0} hour{1}'   -f $span.Hours,   $(if ($span.Hours   -ne 1) {'s'}) }
    if ($span.Minutes -gt 0) { $parts += '{0} minute{1}' -f $span.Minutes, $(if ($span.Minutes -ne 1) {'s'}) }
    if (-not $parts) { $parts = @('less than a minute') }
    return 'up ' + ($parts -join ', ')
}

# --- logged-on session count (the real 'users' analog) --------------------------
function Get-SessionCount {
    try { $q = quser 2>$null; if ($q) { return (@($q).Count - 1) } } catch { }
    try {
        return @(Get-CimInstance Win32_LogonSession -Filter 'LogonType=2 OR LogonType=10' |
                 Select-Object -ExpandProperty LogonId -Unique).Count
    } catch { return 0 }
}
$sessions = Get-SessionCount
$userWord = if ($sessions -eq 1) { 'user' } else { 'users' }

$v    = Get-LoadAverageValues -Path $HistoryPath
$line = '{0} up {1},  {2} {3}' -f $now.ToString('HH:mm:ss', $inv), (Format-Uptime $span), $sessions, $userWord
if ($v) {
    $line += ',  load average: {0}, {1}, {2}' -f `
        $v[0].ToString('F2', $inv), $v[1].ToString('F2', $inv), $v[2].ToString('F2', $inv)
}
Write-Output $line

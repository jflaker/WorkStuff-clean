#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-time setup on a display-board PC: schedules the image sync and the kiosk browser.

.DESCRIPTION
    This is the piece that was missing before. The sync script itself was fine, but
    nothing ever ran it, so the board reloaded the same stale playlist indefinitely.

    Creates two scheduled tasks:
      DisplayBoard-Sync    at startup, then every N minutes -- pulls images, rewrites
                           playlist.js only if something changed.
      DisplayBoard-Kiosk   at logon -- opens Chrome full screen on the local HTML file.

    Both run as the logged-on user ("run only when user is logged on"), which is the
    right choice for an autologon kiosk: the task inherits that user's access to the
    share, so no password has to be stored anywhere.

.EXAMPLE
    .\Install-DisplayBoard.ps1 -SourcePath \\FILESERVER01\Slideshow\images
.EXAMPLE
    .\Install-DisplayBoard.ps1 -SourcePath \\FS01\Signage -IntervalMinutes 10 -Uninstall:$false
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName = 'Install')]
    [string]$SourcePath,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateRange(1, 1440)]
    [int]$IntervalMinutes = 15,

    [Parameter(ParameterSetName = 'Uninstall')]
    [switch]$Uninstall
)

$syncTask  = 'DisplayBoard-Sync'
$kioskTask = 'DisplayBoard-Kiosk'
$root      = $PSScriptRoot

if ($Uninstall) {
    foreach ($t in $syncTask, $kioskTask) {
        if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess($t, 'Unregister scheduled task')) {
                Unregister-ScheduledTask -TaskName $t -Confirm:$false
                Write-Host "Removed $t" -ForegroundColor Yellow
            }
        }
    }
    return
}

# --- sanity checks ---------------------------------------------------------------
$syncScript = Join-Path $root 'SlideshowSync.ps1'
$page       = Join-Path $root 'slideshow.html'
foreach ($f in $syncScript, $page) {
    if (-not (Test-Path $f)) { throw "Missing required file: $f" }
}

if (-not (Test-Path $SourcePath)) {
    Write-Warning "Source '$SourcePath' is not reachable right now."
    Write-Warning 'Continuing -- the sync task retries on its own schedule and leaves the board alone when the share is down.'
}

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) { throw 'Chrome not found. Install it, or edit this script to point at another browser.' }

$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive

# --- 1. sync task ----------------------------------------------------------------
$syncAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -SourcePath "{1}"' -f $syncScript, $SourcePath)

# At startup, and repeating for a very long duration so it effectively never stops.
$atStartup = New-ScheduledTaskTrigger -AtLogOn
$repeating = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration ([TimeSpan]::FromDays(3650))

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

if ($PSCmdlet.ShouldProcess($syncTask, "Register (every $IntervalMinutes min)")) {
    Register-ScheduledTask -TaskName $syncTask -Action $syncAction -Trigger $atStartup, $repeating `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "Registered $syncTask (at logon + every $IntervalMinutes minutes)" -ForegroundColor Green
}

# --- 2. kiosk task ---------------------------------------------------------------
$fileUrl = 'file:///' + ($page -replace '\\', '/')
$kioskArgs = '--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble ' +
             '--disable-features=TranslateUI --no-first-run --disable-pinch "{0}"' -f $fileUrl

$kioskAction  = New-ScheduledTaskAction -Execute $chrome -Argument $kioskArgs
$kioskTrigger = New-ScheduledTaskTrigger -AtLogOn
# Give the sync task a head start so the first playlist exists before the browser opens.
$kioskTrigger.Delay = 'PT30S'
$kioskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)

if ($PSCmdlet.ShouldProcess($kioskTask, 'Register')) {
    Register-ScheduledTask -TaskName $kioskTask -Action $kioskAction -Trigger $kioskTrigger `
        -Principal $principal -Settings $kioskSettings -Force | Out-Null
    Write-Host "Registered $kioskTask" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host "  Images sync from : $SourcePath"
Write-Host "  Display page     : $fileUrl"
Write-Host ''
Write-Host 'Run the first sync now with:' -ForegroundColor Cyan
Write-Host "  Start-ScheduledTask -TaskName $syncTask"
Write-Host 'Then check sync.log in this folder.'

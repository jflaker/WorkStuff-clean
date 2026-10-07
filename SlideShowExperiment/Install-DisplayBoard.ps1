#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    One-time setup on a display-board PC: schedules the image sync and the kiosk browser.

.DESCRIPTION
    Reads source path and sync interval from config.json (or -SourcePath / -IntervalMinutes).

    Creates two scheduled tasks:
      DisplayBoard-Sync    at logon, then every N minutes -- pulls images, rewrites playlist.js
      DisplayBoard-Kiosk   at logon -- opens Chrome full screen on the local HTML file

.EXAMPLE
    # Edit config.json first, then:
    .\Install-DisplayBoard.ps1
.EXAMPLE
    .\Install-DisplayBoard.ps1 -SourcePath \\FILESERVER01\Slideshow\images -IntervalMinutes 10
.EXAMPLE
    .\Install-DisplayBoard.ps1 -Uninstall
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ParameterSetName = 'Install')]
    [string]$SourcePath,

    [Parameter(ParameterSetName = 'Install')]
    [ValidateRange(1, 1440)]
    [int]$IntervalMinutes,

    [Parameter(ParameterSetName = 'Install')]
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),

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

$fileCfg = $null
if (Test-Path -LiteralPath $ConfigPath) {
    try { $fileCfg = (Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8) | ConvertFrom-Json }
    catch { Write-Warning "Could not parse config.json: $($_.Exception.Message)" }
}

if (-not $SourcePath -and $fileCfg -and $fileCfg.sourcePath) {
    $SourcePath = [string]$fileCfg.sourcePath
}
if (-not $PSBoundParameters.ContainsKey('IntervalMinutes')) {
    if ($fileCfg -and $fileCfg.syncIntervalMinutes) {
        $IntervalMinutes = [int]$fileCfg.syncIntervalMinutes
    } else {
        $IntervalMinutes = 15
    }
}

if (-not $SourcePath) {
    throw @"
No source path set.

Edit config.json and set sourcePath to your UNC folder, e.g.:
  \\FILESERVER01\Slideshow\images

Or pass -SourcePath explicitly.
"@
}

try {
    $toSave = [ordered]@{
        sourcePath          = $SourcePath
        localPath           = if ($fileCfg -and $fileCfg.localPath) { [string]$fileCfg.localPath } else { 'images' }
        syncIntervalMinutes = $IntervalMinutes
        pollMinutes         = if ($fileCfg -and $fileCfg.pollMinutes) { [int]$fileCfg.pollMinutes } else { 5 }
        slideSeconds        = if ($fileCfg -and $fileCfg.slideSeconds) { [int]$fileCfg.slideSeconds } else { 8 }
        extensions          = if ($fileCfg -and $fileCfg.extensions) { @($fileCfg.extensions) } else {
            @('.jpg','.jpeg','.png','.gif','.bmp','.webp')
        }
    }
    ($toSave | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    Write-Host "Updated $ConfigPath" -ForegroundColor Green
} catch {
    Write-Warning "Could not write config.json: $($_.Exception.Message)"
}

$apply = Join-Path $root 'Apply-Config.ps1'
if (Test-Path $apply) {
    & $apply -ConfigPath $ConfigPath
}

$syncScript = Join-Path $root 'SlideshowSync.ps1'
$page       = Join-Path $root 'slideshow.html'
foreach ($f in $syncScript, $page) {
    if (-not (Test-Path $f)) { throw "Missing required file: $f" }
}

if (-not (Test-Path $SourcePath)) {
    Write-Warning "Source '$SourcePath' is not reachable right now."
    Write-Warning 'Continuing -- the sync task retries on its schedule and leaves the board alone when the share is down.'
}

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) { throw 'Chrome not found. Install it, or edit this script to point at another browser.' }

$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive

# Task reads config.json each run -- change path later without reinstalling.
$syncAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $syncScript)

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

$fileUrl = 'file:///' + ($page -replace '\\', '/')
$kioskArgs = '--kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble ' +
             '--disable-features=TranslateUI --no-first-run --disable-pinch "{0}"' -f $fileUrl

$kioskAction  = New-ScheduledTaskAction -Execute $chrome -Argument $kioskArgs
$kioskTrigger = New-ScheduledTaskTrigger -AtLogOn
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
Write-Host "  Interval         : every $IntervalMinutes minute(s)"
Write-Host "  Display page     : $fileUrl"
Write-Host "  Config file      : $ConfigPath"
Write-Host ''
Write-Host 'Change path/timing later by editing config.json (or settings.html), then:' -ForegroundColor Cyan
Write-Host '  .\Apply-Config.ps1 -TriggerSync'
Write-Host ''
Write-Host 'First sync now:' -ForegroundColor Cyan
Write-Host "  Start-ScheduledTask -TaskName $syncTask"

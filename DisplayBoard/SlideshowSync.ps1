#Requires -Version 5.1
<#
.SYNOPSIS
    Syncs display-board images from a network share and regenerates the playlist.

.DESCRIPTION
    Run by Task Scheduler at boot and every N minutes (interval from config.json).

    Drop or delete image files in the UNC folder; this script mirrors them locally
    with robocopy /MIR and rewrites playlist.js only when the set actually changed.
    slideshow.html polls playlist.js and picks up updates without a full page reload.

    Configuration (in order of precedence):
      1. -SourcePath / -LocalPath parameters
      2. config.json beside this script (sourcePath, localPath, extensions, ...)
      3. Environment variable SLIDESHOW_SOURCE

    Also writes config.js so the browser can read poll/slide timings from file://.

.EXAMPLE
    .\SlideshowSync.ps1
.EXAMPLE
    .\SlideshowSync.ps1 -SourcePath \\FILESERVER01\Slideshow\images
#>
[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$LocalPath,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [string]$LogPath = (Join-Path $PSScriptRoot 'sync.log'),
    [string[]]$Extensions
)

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch { }
}

function Read-DisplayConfig {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $cfg = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
        return $cfg
    } catch {
        Write-Log "Could not parse config.json: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Write-ConfigJs {
    param($Cfg, [string]$OutPath)
    $exts = @($Cfg.extensions)
    if (-not $exts.Count) { $exts = @('.jpg','.jpeg','.png','.gif','.bmp','.webp') }
    $extJson = ($exts | ForEach-Object { "'$_'" }) -join ', '
    $src = ([string]$Cfg.sourcePath -replace '\\', '\\' -replace "'", "\'")
    $local = ([string]$Cfg.localPath -replace '\\', '\\' -replace "'", "\'")
    $syncMin = if ($Cfg.syncIntervalMinutes) { [int]$Cfg.syncIntervalMinutes } else { 15 }
    $poll = if ($Cfg.pollMinutes) { [int]$Cfg.pollMinutes } else { 5 }
    $slide = if ($Cfg.slideSeconds) { [int]$Cfg.slideSeconds } else { 8 }
    $content = @"
// AUTO-GENERATED -- edit config.json, then re-run sync or Apply-Config.ps1
window.SLIDESHOW_CONFIG = {
  sourcePath: '$src',
  localPath: '$local',
  syncIntervalMinutes: $syncMin,
  pollMinutes: $poll,
  slideSeconds: $slide,
  extensions: [$extJson]
};
"@
    Set-Content -LiteralPath $OutPath -Value $content -Encoding UTF8
}

if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 1MB)) {
    Set-Content -Path $LogPath -Value "--- truncated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
}

$fileCfg = Read-DisplayConfig -Path $ConfigPath

if (-not $SourcePath) {
    if ($fileCfg -and $fileCfg.sourcePath) { $SourcePath = [string]$fileCfg.sourcePath }
    elseif ($env:SLIDESHOW_SOURCE) { $SourcePath = $env:SLIDESHOW_SOURCE }
}
if (-not $LocalPath) {
    if ($fileCfg -and $fileCfg.localPath) {
        $lp = [string]$fileCfg.localPath
        $LocalPath = if ([IO.Path]::IsPathRooted($lp)) { $lp } else { Join-Path $PSScriptRoot $lp }
    } else {
        $LocalPath = Join-Path $PSScriptRoot 'images'
    }
}
if (-not $Extensions -or $Extensions.Count -eq 0) {
    if ($fileCfg -and $fileCfg.extensions) { $Extensions = @($fileCfg.extensions) }
    else { $Extensions = @('.jpg','.jpeg','.png','.gif','.bmp','.webp') }
}

if ($fileCfg) {
    $jsCfg = [pscustomobject]@{
        sourcePath          = $SourcePath
        localPath           = if ($fileCfg.localPath) { $fileCfg.localPath } else { 'images' }
        syncIntervalMinutes = $fileCfg.syncIntervalMinutes
        pollMinutes         = $fileCfg.pollMinutes
        slideSeconds        = $fileCfg.slideSeconds
        extensions          = $Extensions
    }
    Write-ConfigJs -Cfg $jsCfg -OutPath (Join-Path $PSScriptRoot 'config.js')
}

if (-not $SourcePath) {
    Write-Log 'No sourcePath. Set it in config.json or pass -SourcePath.' 'ERROR'
    exit 1
}

if (-not (Test-Path $LocalPath)) {
    New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
    Write-Log "Created local image folder $LocalPath"
}

if ([string]::IsNullOrWhiteSpace($LocalPath)) {
    Write-Log '-LocalPath is empty. Refusing to run.' 'ERROR'
    exit 1
}
try { $resolvedLocal = [IO.Path]::GetFullPath($LocalPath).TrimEnd('\') }
catch {
    Write-Log "-LocalPath '$LocalPath' is not a usable path: $($_.Exception.Message)" 'ERROR'
    exit 1
}
$protected = @(
    [Environment]::GetFolderPath('MyPictures')
    [Environment]::GetFolderPath('MyDocuments')
    [Environment]::GetFolderPath('Desktop')
    [Environment]::GetFolderPath('MyVideos')
    [Environment]::GetFolderPath('MyMusic')
    [Environment]::GetFolderPath('UserProfile')
) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }

if ($protected -contains $resolvedLocal) {
    Write-Log "REFUSING to run: -LocalPath '$resolvedLocal' is a real user folder. Point localPath at a disposable cache such as .\images." 'ERROR'
    exit 1
}

try {
    $resolvedSource = [IO.Path]::GetFullPath($SourcePath).TrimEnd('\')
    if ($resolvedSource -eq $resolvedLocal) {
        Write-Log "REFUSING to run: source and destination are the same folder ('$resolvedLocal')." 'ERROR'
        exit 1
    }
} catch { }

if (-not (Test-Path $SourcePath)) {
    Write-Log "Source '$SourcePath' unreachable. Keeping the existing local images." 'WARN'
    exit 0
}

$filter = $Extensions | ForEach-Object { "*$_" }
$roboArgs = @($SourcePath, $LocalPath) + $filter + @('/MIR','/NJH','/NJS','/NP','/NDL','/R:2','/W:5')
$roboOut = & robocopy @roboArgs 2>&1
$rc = $LASTEXITCODE

if ($rc -ge 8) {
    Write-Log "robocopy failed with exit code $rc. Local images left untouched." 'ERROR'
    $roboOut | Where-Object { $_ } | Select-Object -Last 5 | ForEach-Object { Write-Log "  $_" 'ERROR' }
    exit 1
}
Write-Log "robocopy completed (exit $rc)."

$images = Get-ChildItem -Path $LocalPath -File |
    Where-Object { $Extensions -contains $_.Extension.ToLower() } |
    Sort-Object Name

$signature = ($images | ForEach-Object { '{0}|{1}|{2}' -f $_.Name, $_.Length, $_.LastWriteTimeUtc.Ticks }) -join "`n"
$hash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($signature))).Replace('-','').Substring(0,16)

$playlistPath = Join-Path $PSScriptRoot 'playlist.js'
if (Test-Path $playlistPath) {
    $existing = Get-Content $playlistPath -Raw -ErrorAction SilentlyContinue
    if ($existing -match "generated:\s*'([0-9A-F]{16})'" -and $Matches[1] -eq $hash) {
        Write-Log "No change ($($images.Count) images). Playlist left as is."
        exit 0
    }
}

$folderName = Split-Path $LocalPath -Leaf
$entries = $images | ForEach-Object {
    "    '{0}/{1}'" -f $folderName, [uri]::EscapeDataString($_.Name)
}

$content = @"
// AUTO-GENERATED by SlideshowSync.ps1 -- do not edit by hand.
// Written $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
window.SLIDESHOW = {
  generated: '$hash',
  images: [
$($entries -join ",`r`n")
  ]
};
"@

Set-Content -Path $playlistPath -Value $content -Encoding UTF8
Write-Log "Playlist updated: $($images.Count) image(s), signature $hash."

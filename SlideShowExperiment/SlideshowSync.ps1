#Requires -Version 5.1
<#
.SYNOPSIS
    Syncs display-board images from a network share and regenerates the playlist.

.DESCRIPTION
    Run by Task Scheduler at boot and every N minutes. Nobody should ever run this
    by hand -- that was the flaw in the previous version (SlideshowPrep.ps1), which
    had to be run manually, so the board kept reloading the same stale list forever
    while looking like it was working.

    Design notes:

    * robocopy /MIR, not delete-then-copy. The old script deleted every local image
      first, which left a window where the folder was empty (blank board if the page
      reloaded mid-run) and re-copied everything on every pass. /MIR adds, updates
      and removes in one go and only transfers what actually changed.

    * If the share is unreachable, this exits WITHOUT touching the local copy, so the
      board keeps showing the last good set instead of going blank.

    * playlist.js is only rewritten when the image set actually changes (compared by
      name + size + timestamp). The display polls that file; rewriting it every run
      would make the board rebuild itself for no reason.

.EXAMPLE
    .\SlideshowSync.ps1 -SourcePath \\FILESERVER01\Slideshow\images

.EXAMPLE
    # Any folder works, local or UNC -- handy for trying it out before wiring up a share.
    .\SlideshowSync.ps1 -SourcePath "$env:USERPROFILE\Pictures"
#>
[CmdletBinding()]
param(
    # UNC path holding the images. Use a normal share, NOT an admin share (C$).
    [string]$SourcePath = $env:SLIDESHOW_SOURCE,

    # Local folder the board reads from. Defaults to .\images next to this script.
    [string]$LocalPath = (Join-Path $PSScriptRoot 'images'),

    [string]$LogPath = (Join-Path $PSScriptRoot 'sync.log'),

    [string[]]$Extensions = @('.jpg','.jpeg','.png','.gif','.bmp','.webp')
)

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch { }
}

# Keep the log from growing without bound.
if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 1MB)) {
    Set-Content -Path $LogPath -Value "--- truncated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
}

if (-not $SourcePath) {
    Write-Log 'No -SourcePath given and SLIDESHOW_SOURCE is not set. Nothing to do.' 'ERROR'
    exit 1
}

if (-not (Test-Path $LocalPath)) {
    New-Item -Path $LocalPath -ItemType Directory -Force | Out-Null
    Write-Log "Created local image folder $LocalPath"
}

# --- 0. Refuse to mirror ONTO a real folder. -------------------------------------
# robocopy /MIR deletes anything in the destination that is not in the source. If
# -LocalPath were ever pointed at a folder that holds real files -- Pictures, say,
# or the same folder as the source -- this would erase them. The destination is a
# disposable cache; it must never be somewhere anyone keeps anything.
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
    Write-Log "REFUSING to run: -LocalPath '$resolvedLocal' is a real user folder. robocopy /MIR would delete files there. Point -LocalPath at a disposable cache folder such as .\images." 'ERROR'
    exit 1
}

try {
    $resolvedSource = [IO.Path]::GetFullPath($SourcePath).TrimEnd('\')
    if ($resolvedSource -eq $resolvedLocal) {
        Write-Log "REFUSING to run: source and destination are the same folder ('$resolvedLocal')." 'ERROR'
        exit 1
    }
} catch { }   # UNC paths that GetFullPath dislikes are fine to skip here

# --- 1. Is the share reachable? If not, leave everything alone. -----------------
if (-not (Test-Path $SourcePath)) {
    Write-Log "Source '$SourcePath' unreachable. Keeping the existing local images." 'WARN'
    exit 0
}

# --- 2. Mirror. ------------------------------------------------------------------
$filter = $Extensions | ForEach-Object { "*$_" }
$roboArgs = @($SourcePath, $LocalPath) + $filter + @('/MIR','/NJH','/NJS','/NP','/NDL','/R:2','/W:5')
$roboOut = & robocopy @roboArgs 2>&1
$rc = $LASTEXITCODE

# robocopy: 0-7 are success (0 = nothing to do, 1 = files copied, 2 = extras removed...).
# 8 and above are real failures.
if ($rc -ge 8) {
    Write-Log "robocopy failed with exit code $rc. Local images left untouched." 'ERROR'
    $roboOut | Where-Object { $_ } | Select-Object -Last 5 | ForEach-Object { Write-Log "  $_" 'ERROR' }
    exit 1
}
Write-Log "robocopy completed (exit $rc)."

# --- 3. Has the image set actually changed? --------------------------------------
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

# --- 4. Write playlist.js --------------------------------------------------------
# A .js file, not .json, so the display can load it with a plain <script src> tag
# and therefore run straight from file:// -- no web server, no port 80, no CORS.
$folderName = Split-Path $LocalPath -Leaf
$entries = $images | ForEach-Object {
    # Escape the filename so spaces, #, % and non-ASCII names work in an <img src>.
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

#Requires -Version 5.1
<#
.SYNOPSIS
    Sorts loose files from one folder into Pictures / Videos / Documents / Music by type.

.DESCRIPTION
    REWRITTEN. The previous version recursed from the USER PROFILE ROOT and moved by
    extension with -Force. Three ways that destroyed things:

      1. It walked AppData and dragged .txt/.png/.pdf files out of application data
         folders, breaking installed software.
      2. It recursed into its own destinations, so files in Pictures were "moved" into
         Pictures, and a re-run would churn the same files again.
      3. Move-Item -Force silently OVERWRITES a same-named file at the destination.
         Two files called scan.pdf from different folders meant one was gone.

    This version defaults to the Desktop only, never recurses into system or
    destination folders, refuses to overwrite (it appends a counter instead), and
    supports -WhatIf so you can see the plan before anything moves.

.EXAMPLE
    .\movefiles.ps1 -WhatIf
.EXAMPLE
    .\movefiles.ps1 -SourceFolder "$env:USERPROFILE\Downloads"
.EXAMPLE
    .\movefiles.ps1 -SourceFolder "$env:USERPROFILE\Downloads" -Recurse
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    # Deliberately NOT the profile root.
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$SourceFolder = [Environment]::GetFolderPath('Desktop'),

    # Off by default. Even on, the exclusions below still apply.
    [switch]$Recurse
)

$home_    = [Environment]::GetFolderPath('UserProfile')
$dest = @{
    Pictures  = [Environment]::GetFolderPath('MyPictures')
    Videos    = (Join-Path $home_ 'Videos')
    Documents = [Environment]::GetFolderPath('MyDocuments')
    Music     = [Environment]::GetFolderPath('MyMusic')
}

$map = @{
    Pictures  = '.jpg','.jpeg','.png','.gif','.bmp','.tiff','.tif','.webp','.svg','.heic'
    Videos    = '.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm'
    Documents = '.doc','.docx','.xls','.xlsx','.ppt','.pptx','.pdf','.txt','.rtf','.odt','.ods'
    Music     = '.mp3','.wav','.flac','.aac','.wma','.ogg'
}

# Never touch these, whatever -Recurse says. AppData is the big one -- applications
# keep .txt, .png and .pdf files in there and moving them breaks the app.
$excluded = @(
    (Join-Path $home_ 'AppData')
    (Join-Path $home_ '.git')
    $env:LOCALAPPDATA
    $env:APPDATA
) + $dest.Values | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }

function Test-Excluded {
    param([string]$Path)
    foreach ($x in $excluded) {
        if ($Path -eq $x -or $Path.StartsWith($x + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-NonClobberingPath {
    param([string]$Folder, [string]$FileName)
    $target = Join-Path $Folder $FileName
    if (-not (Test-Path -LiteralPath $target)) { return $target }
    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext  = [IO.Path]::GetExtension($FileName)
    $i = 1
    do { $target = Join-Path $Folder "$base ($i)$ext"; $i++ } while (Test-Path -LiteralPath $target)
    return $target
}

foreach ($folder in $dest.Values) {
    if ($folder -and -not (Test-Path $folder)) { New-Item -Path $folder -ItemType Directory -Force | Out-Null }
}

$gciArgs = @{ Path = $SourceFolder; File = $true; ErrorAction = 'SilentlyContinue' }
if ($Recurse) { $gciArgs.Recurse = $true }

$moved = 0; $skipped = 0
foreach ($file in Get-ChildItem @gciArgs) {
    if (Test-Excluded $file.DirectoryName) { $skipped++; continue }

    $category = $map.Keys | Where-Object { $map[$_] -contains $file.Extension.ToLower() } | Select-Object -First 1
    if (-not $category) { continue }

    $targetFolder = $dest[$category]
    if ($file.DirectoryName.TrimEnd('\') -eq $targetFolder.TrimEnd('\')) { continue }  # already home

    $targetPath = Get-NonClobberingPath -Folder $targetFolder -FileName $file.Name
    if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $targetPath")) {
        try   { Move-Item -LiteralPath $file.FullName -Destination $targetPath -ErrorAction Stop; $moved++ }
        catch { Write-Warning "Could not move $($file.Name): $($_.Exception.Message)" }
    }
}

Write-Host "Moved $moved file(s). Skipped $skipped in excluded locations." -ForegroundColor Green

#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows maintenance: applies Windows Updates and upgrades all winget apps.

.DESCRIPTION
    - Installs the PSWindowsUpdate module if it is missing.
    - Applies all available Windows Updates.
    - Upgrades every winget-managed application.

    REBOOT IS OPT-IN. By default this script does NOT restart the machine -- it
    installs updates and, if a reboot is required to finish them, tells you so and
    stops. The previous version passed -AutoReboot, which restarted the machine the
    instant updates finished, with no warning, killing whatever anyone had open.
    Pass -Reboot only when you are patching a machine you can afford to restart now.

    Requires an elevated session (enforced by #Requires above) -- Install-Module
    -AllUsers, Install-WindowsUpdate and system-wide winget upgrades all need admin.

.PARAMETER Reboot
    Automatically restart when updates require it. Off by default.

.PARAMETER LogFolder
    Where to write the run transcript. Defaults to Documents\Diagnostics.

.EXAMPLE
    .\runupdates.ps1
.EXAMPLE
    .\runupdates.ps1 -Reboot
#>
[CmdletBinding()]
param(
    [switch]$Reboot,
    [string]$LogFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Diagnostics')
)

function Write-Section {
    param([string]$Title, [ConsoleColor]$Color = 'Cyan')
    Write-Host ''
    Write-Host ('=' * 40) -ForegroundColor $Color
    Write-Host "  $Title" -ForegroundColor $Color
    Write-Host ('=' * 40) -ForegroundColor $Color
    Write-Host ''
}

# Transcript so unattended runs leave a record. Plain ASCII output only, so the log
# stays clean whether it is read in Windows Terminal, old conhost, or a text file.
if (-not (Test-Path $LogFolder)) { New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null }
$log = Join-Path $LogFolder "runupdates_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $log | Out-Null

try {
    Write-Section 'CHECKING MODULES'

    # Per-user execution policy so this script (and PSWindowsUpdate) can run.
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host '  Installing PSWindowsUpdate...' -ForegroundColor Yellow
        # NuGet provider is required for Install-Module on a clean machine.
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
        Install-Module PSWindowsUpdate -Force -Scope AllUsers
        Write-Host '  Installed.' -ForegroundColor Green
    } else {
        Write-Host '  PSWindowsUpdate already installed.' -ForegroundColor Green
    }
    Import-Module PSWindowsUpdate

    Write-Section 'WINDOWS UPDATES'

    if ($Reboot) {
        Write-Host '  -Reboot specified: the machine WILL restart if updates require it.' -ForegroundColor Yellow
        Install-WindowsUpdate -AcceptAll -AutoReboot
    } else {
        # Install but never restart on our own.
        Install-WindowsUpdate -AcceptAll -IgnoreReboot

        # Tell the operator plainly if a restart is still needed to finish.
        $pending = $false
        try { $pending = (Get-WURebootStatus -Silent) } catch { }
        if ($pending) {
            Write-Host ''
            Write-Host '  A REBOOT IS REQUIRED to finish installing updates.' -ForegroundColor Red
            Write-Host '  Restart when convenient, or re-run with -Reboot.' -ForegroundColor Red
        } else {
            Write-Host '  Updates applied. No reboot required.' -ForegroundColor Green
        }
    }

    Write-Section 'WINGET UPGRADES' 'Yellow'

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host '  winget not found - skipping.' -ForegroundColor Red
    }

    Write-Section 'DONE' 'Green'
    Write-Host "  Transcript: $log" -ForegroundColor Green
}
finally {
    Stop-Transcript | Out-Null
}

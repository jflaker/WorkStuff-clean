<# 
    Windows Maintenance Script
    - Installs PSWindowsUpdate if missing
    - Ensures module is imported permanently
    - Runs Windows Update with auto‑reboot
    - Upgrades all Winget applications silently
#>

Clear-Host

# ─────────────────────────────────────────────
# CHECK MODULES
# ─────────────────────────────────────────────
Write-Host "`n┌─────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│     CHECKING MODULES        │" -ForegroundColor Cyan
Write-Host "└─────────────────────────────┘`n" -ForegroundColor Cyan

# Ensure execution policy allows script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Install PSWindowsUpdate if missing
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "  Installing PSWindowsUpdate..." -ForegroundColor Yellow
    Install-Module PSWindowsUpdate -Force -Scope AllUsers
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  PSWindowsUpdate already installed." -ForegroundColor Green
}

# Import module
Import-Module PSWindowsUpdate

# Add module to PowerShell profile if not already present
if (-not (Test-Path $PROFILE) -or -not (Select-String -Path $PROFILE -Pattern "PSWindowsUpdate" -Quiet -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path $PROFILE)) {
        New-Item -Path $PROFILE -Force | Out-Null
    }
    Add-Content $PROFILE "`nImport-Module PSWindowsUpdate"
    Write-Host "  PSWindowsUpdate added to profile (permanent)." -ForegroundColor Green
} else {
    Write-Host "  PSWindowsUpdate already in profile." -ForegroundColor Green
}

# ─────────────────────────────────────────────
# WINDOWS UPDATES
# ─────────────────────────────────────────────
Write-Host "`n┌─────────────────────────────┐" -ForegroundColor Cyan
Write-Host "│      WINDOWS UPDATES        │" -ForegroundColor Cyan
Write-Host "└─────────────────────────────┘`n" -ForegroundColor Cyan

Install-WindowsUpdate -AcceptAll -AutoReboot

# ─────────────────────────────────────────────
# WINGET UPGRADES
# ─────────────────────────────────────────────
Write-Host "`n┌─────────────────────────────┐" -ForegroundColor Yellow
Write-Host "│   UPGRADING APPS (WINGET)   │" -ForegroundColor Yellow
Write-Host "└─────────────────────────────┘`n" -ForegroundColor Yellow

if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "  winget not found - skipping." -ForegroundColor Red
}

# ─────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────
Write-Host "`n┌─────────────────────────────┐" -ForegroundColor Green
Write-Host "│            DONE             │" -ForegroundColor Green
Write-Host "└─────────────────────────────┘`n" -ForegroundColor Green

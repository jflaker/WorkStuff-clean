#Requires -Version 5.1
<#
.SYNOPSIS
    Generates (and optionally applies) a standardized computer name: <DEPT>-<last 6 of MAC>
    e.g. ACCT-CF097F

.DESCRIPTION
    Name = department abbreviation + "-" + the last 6 hex characters of the machine's
    Ethernet MAC address. Those 6 chars are the last 3 octets -- the NIC-unique portion
    of the MAC -- so two machines colliding is astronomically unlikely.

    Departments come from a CSV of "Full Name,ABBR" rows, e.g.:
        Accounting,ACCT
        Human Resources,HR
    A header row (Department,Abbreviation) is optional -- the script detects it.
    You pick from a menu of the full names; the abbreviation is what goes in the name.
    If you enter an abbreviation that is not in the file, it asks before adding it.

    The proposed name is checked against Active Directory. If the Ethernet-based name
    already exists in AD, the script falls back to the Bluetooth MAC, then the Wi-Fi
    MAC, using the first free one.

    By default it only PROPOSES the name and asks whether to apply it. Renaming needs
    admin and a reboot to take effect.

.PARAMETER Dept
    Abbreviation to use (2-4 alphanumeric). If not in the file, you'll be asked whether
    to add it. Omit for an interactive menu.
.PARAMETER DeptFile
    Path to the department CSV. Default: departments.csv beside this script.
.PARAMETER NoPrompt
    Don't ask to rename; just output the proposed name. For imaging/automation.
    (Also suppresses the add-to-file prompt -- an unknown -Dept is used for this run only.)
.PARAMETER Rename
    Apply the name with Rename-Computer without asking. Needs admin.
.PARAMETER Restart
    With -Rename, restart immediately after renaming.

.EXAMPLE
    .\New-ComputerName.ps1
.EXAMPLE
    .\New-ComputerName.ps1 -Dept ACCT
.EXAMPLE
    .\New-ComputerName.ps1 -Dept IT -Rename -Restart
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9]{2,4}$')]
    [string]$Dept,

    [string]$DeptFile = (Join-Path $PSScriptRoot 'departments.csv'),

    [switch]$NoPrompt,
    [switch]$Rename,
    [switch]$Restart
)

# --- read the department CSV into {Department, Abbrev} items ----------------------
function Read-DeptFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Department file not found: $Path`nCreate a CSV of 'Full Name,ABBR' rows (e.g. Accounting,ACCT), or pass -DeptFile."
    }
    $firstLine = Get-Content -Path $Path -TotalCount 1
    $hasHeader = $firstLine -match '(?i)abbrev|department'
    $rows = if ($hasHeader) { Import-Csv -Path $Path } else { Import-Csv -Path $Path -Header 'Department','Abbrev' }

    $items = foreach ($r in $rows) {
        $dept = ($r.Department -as [string]).Trim()
        $ab   = $null
        foreach ($c in 'Abbrev','Abbreviation','Abbr') {
            if (($r.PSObject.Properties.Name -contains $c) -and $r.$c) { $ab = $r.$c; break }
        }
        $ab = ($ab -as [string]).Trim().ToUpper()
        if (-not $ab -or $ab -match '^\s*#') { continue }        # blank or comment
        if ($ab -notmatch '^[A-Z0-9]{2,4}$') {
            Write-Warning "Skipping invalid abbreviation '$ab' in $Path (must be 2-4 letters/digits)."
            continue
        }
        [pscustomobject]@{ Department = $dept; Abbrev = $ab }
    }
    [pscustomobject]@{ Path = $Path; HasHeader = [bool]$hasHeader; Items = @($items) }
}

# --- append a new department to the CSV, with confirmation ------------------------
function Add-Department {
    param([pscustomobject]$DeptData, [string]$Abbrev)

    $Abbrev = $Abbrev.ToUpper()
    while ($Abbrev -notmatch '^[A-Z0-9]{2,4}$') {
        $Abbrev = (Read-Host 'Enter a 2-4 character abbreviation (letters/digits)').ToUpper()
    }
    $dupe = $DeptData.Items | Where-Object { $_.Abbrev -eq $Abbrev } | Select-Object -First 1
    if ($dupe) { Write-Host "  '$Abbrev' already exists ($($dupe.Department)); using it." -ForegroundColor Green; return $Abbrev }

    if ($NoPrompt) { return $Abbrev }   # automation: don't touch the file, use for this run only

    $full = (Read-Host 'Full department name for this abbreviation').Trim()
    $ans  = Read-Host "Add '$full,$Abbrev' to $($DeptData.Path)? (Y/N)"
    if ($ans -match '^[Yy]') {
        # ensure the file ends with a newline so we don't glue onto the last row
        $raw = Get-Content -Path $DeptData.Path -Raw -ErrorAction SilentlyContinue
        if ($raw -and $raw -notmatch "(\r?\n)$") { [IO.File]::AppendAllText($DeptData.Path, [Environment]::NewLine) }
        Add-Content -Path $DeptData.Path -Value ('{0},{1}' -f $full, $Abbrev)
        Write-Host "  Added to $($DeptData.Path)." -ForegroundColor Green
    } else {
        Write-Host "  Not added to file; using '$Abbrev' for this run only." -ForegroundColor Yellow
    }
    return $Abbrev
}

# --- pick a department: -Dept if present, else interactive menu -------------------
function Select-Dept {
    param([pscustomobject]$DeptData, [string]$Requested)
    $items = $DeptData.Items

    if ($Requested) {
        $u   = $Requested.ToUpper()
        $hit = $items | Where-Object { $_.Abbrev -eq $u } | Select-Object -First 1
        if ($hit) { return $hit.Abbrev }
        Write-Host "'$Requested' is not in the department list." -ForegroundColor Yellow
        return (Add-Department -DeptData $DeptData -Abbrev $u)
    }

    if (-not $items) { throw "No departments in $($DeptData.Path). Add at least one 'Full Name,ABBR' row." }

    Write-Host ''
    Write-Host 'Select a department:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $items.Count; $i++) {
        '  {0,2}. {1} ({2})' -f ($i + 1), $items[$i].Department, $items[$i].Abbrev | Write-Host
    }
    Write-Host '   A. Add a new department'
    do {
        $sel = Read-Host "Enter number (1-$($items.Count)) or A"
        if ($sel -match '^[Aa]$') { return (Add-Department -DeptData $DeptData -Abbrev '') }
    } while ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $items.Count)
    return $items[[int]$sel - 1].Abbrev
}

# --- last 6 hex of a given adapter type's MAC ------------------------------------
function Get-AdapterMacSuffix {
    param([ValidateSet('Ethernet','Bluetooth','WiFi')][string]$Type)
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.MacAddress }
    $match = switch ($Type) {
        'Ethernet'  { $adapters | Where-Object { $_.PhysicalMediaType -eq '802.3'               -or $_.InterfaceDescription -match 'Ethernet' } }
        'WiFi'      { $adapters | Where-Object { $_.PhysicalMediaType -match '802\.11|Wireless'  -or $_.InterfaceDescription -match 'Wi-?Fi|Wireless' } }
        'Bluetooth' { $adapters | Where-Object { $_.PhysicalMediaType -match 'Bluetooth'         -or $_.InterfaceDescription -match 'Bluetooth' } }
    }
    $a = $match | Sort-Object ifIndex | Select-Object -First 1
    if (-not $a) { return $null }
    $hex = ($a.MacAddress -replace '[^0-9A-Fa-f]', '')
    if ($hex.Length -lt 6) { return $null }
    $hex.Substring($hex.Length - 6).ToUpper()
}

# --- AD existence check. $null = could not determine (AD unreachable) ------------
function Test-NameInAD {
    param([string]$Name)
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        return [bool](Get-ADComputer -Filter 'Name -eq $Name' -ErrorAction Stop)
    } catch {
        return $null
    }
}

# ================================ main ==========================================
$deptData = Read-DeptFile -Path $DeptFile
$chosen   = Select-Dept -DeptData $deptData -Requested $Dept

$candidates = [ordered]@{
    Ethernet  = Get-AdapterMacSuffix -Type Ethernet
    Bluetooth = Get-AdapterMacSuffix -Type Bluetooth
    WiFi      = Get-AdapterMacSuffix -Type WiFi
}
if (-not ($candidates.Values | Where-Object { $_ })) {
    throw 'No Ethernet, Bluetooth, or Wi-Fi MAC address could be read from this machine.'
}

$name = $null; $usedType = $null; $adUnverified = $false
foreach ($type in 'Ethernet','Bluetooth','WiFi') {
    $suffix = $candidates[$type]
    if (-not $suffix) { continue }
    $try = "$chosen-$suffix"

    $exists = Test-NameInAD -Name $try
    if ($null -eq $exists) {
        Write-Warning 'Active Directory is unreachable -- collision was NOT verified.'
        $name = $try; $usedType = $type; $adUnverified = $true; break
    }
    if (-not $exists) { $name = $try; $usedType = $type; break }
    Write-Host "  Name '$try' already exists in AD. Trying next adapter..." -ForegroundColor Yellow
}

if (-not $name) {
    throw "All available MAC-based names ($chosen-*) already exist in AD. Effectively impossible -- investigate."
}
if ($name.Length -gt 15) {
    throw "Generated name '$name' exceeds the 15-character NetBIOS limit. Shorten the department abbreviation."
}

Write-Host ''
Write-Host "Proposed computer name: $name" -ForegroundColor Green
Write-Host "  Department : $chosen"
Write-Host "  MAC source : $usedType (last 6: $($candidates[$usedType]))"
if ($usedType -ne 'Ethernet') { Write-Host "  Note       : Ethernet name was taken; used $usedType to avoid a collision." -ForegroundColor Yellow }
if ($adUnverified)            { Write-Host "  WARNING    : AD was unreachable; uniqueness not confirmed." -ForegroundColor Red }

$doRename = $Rename
if (-not $Rename -and -not $NoPrompt) {
    $doRename = ((Read-Host "`nRename this computer to '$name' now? (Y/N)") -match '^[Yy]')
}

if ($doRename) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
             ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) {
        Write-Warning 'Renaming requires an elevated session. Re-run as Administrator. Name NOT changed.'
    } else {
        Rename-Computer -NewName $name -Force -ErrorAction Stop
        Write-Host 'Renamed. A restart is required for the new name to take effect.' -ForegroundColor Green
        if ($Restart) { Restart-Computer -Force }
        elseif (-not $NoPrompt -and (Read-Host 'Restart now? (Y/N)') -match '^[Yy]') { Restart-Computer -Force }
    }
}

Write-Output $name

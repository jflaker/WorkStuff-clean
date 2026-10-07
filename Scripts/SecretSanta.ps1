#Requires -Version 5.1
<#
.SYNOPSIS
    Assign Secret Santa pairs from a CSV and optionally email them.

.DESCRIPTION
    Reads participants from a CSV (Name, Email), produces a derangement
    (no one is assigned themselves), and writes the result to a local file.

    Email is OPT-IN. By default the script only shows and/or writes the pairs.
    Pass -SendEmail (and the SMTP parameters) when you are ready to notify people.

    Send-MailMessage is deprecated by Microsoft but still works on many
    on-prem SMTP setups. Prefer Microsoft Graph or Mailozaurr when you can.

.PARAMETER CsvPath
    Path to the participants CSV. Default: santas.csv beside this script.
    Expected columns: Name, Email

.PARAMETER OutPath
    Where to write the assignment list. Default: Documents\SecretSanta\assignments_YYYYMMDD_HHMMSS.txt

.PARAMETER SendEmail
    Actually send email. Requires -MailFrom and -SmtpServer.

.PARAMETER MailFrom
    From address for notifications.

.PARAMETER SmtpServer
    SMTP server hostname.

.PARAMETER SmtpPort
    SMTP port (default 25).

.PARAMETER UseSsl
    Use SSL/TLS for SMTP.

.PARAMETER Credential
    Optional SMTP credential (Get-Credential).

.EXAMPLE
    # Preview only (safe default with -WhatIf)
    .\SecretSanta.ps1 -WhatIf

.EXAMPLE
    # Write pairs to a file, do not email
    .\SecretSanta.ps1

.EXAMPLE
    # Write pairs and email them
    .\SecretSanta.ps1 -SendEmail -MailFrom "santa@example.com" -SmtpServer "smtp.example.com"
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot 'santas.csv'),

    [string]$OutPath,

    [switch]$SendEmail,

    [string]$MailFrom,

    [string]$SmtpServer,

    [int]$SmtpPort = 25,

    [switch]$UseSsl,

    [pscredential]$Credential
)

function Get-SecretSantaPairs {
    param(
        [object[]]$Participants,
        [int]$MaxAttempts = 500
    )

    $n = $Participants.Count
    if ($n -lt 2) {
        throw 'Need at least 2 participants for Secret Santa.'
    }

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $shuffled = $Participants | Sort-Object { Get-Random }
        $valid = $true
        for ($i = 0; $i -lt $n; $i++) {
            if ($Participants[$i].Name -eq $shuffled[$i].Name) {
                $valid = $false
                break
            }
        }
        if ($valid) {
            $pairs = for ($i = 0; $i -lt $n; $i++) {
                [pscustomobject]@{
                    Giver     = $Participants[$i].Name
                    GiverEmail = $Participants[$i].Email
                    Receiver  = $shuffled[$i].Name
                }
            }
            return ,$pairs
        }
    }

    throw "Could not find a valid derangement after $MaxAttempts attempts (unusual for n>=2)."
}

# --- load and validate CSV -------------------------------------------------------
if (-not (Test-Path -LiteralPath $CsvPath)) {
    $example = Join-Path $PSScriptRoot 'santas.example.csv'
    $hint = if (Test-Path $example) {
        "Copy the example and fill it in:`n  Copy-Item '$example' '$CsvPath'"
    } else {
        "Create a CSV with columns Name,Email (one person per row)."
    }
    throw "Participant file not found: $CsvPath`n$hint"
}

$raw = Import-Csv -Path $CsvPath
if (-not $raw -or $raw.Count -eq 0) {
    throw "CSV is empty: $CsvPath"
}

$required = @('Name', 'Email')
$cols = $raw[0].PSObject.Properties.Name
foreach ($c in $required) {
    if ($cols -notcontains $c) {
        throw "CSV is missing required column '$c'. Found: $($cols -join ', ')"
    }
}

$participants = foreach ($row in $raw) {
    $name  = ($row.Name  -as [string]).Trim()
    $email = ($row.Email -as [string]).Trim()
    if (-not $name)  { throw 'A row has an empty Name.' }
    if (-not $email) { throw "No Email for '$name'." }
    if ($email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-Warning "Email for '$name' looks unusual: $email"
    }
    [pscustomobject]@{ Name = $name; Email = $email }
}

$dupNames = $participants | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($dupNames) {
    throw "Duplicate names: $($dupNames.Name -join ', '). Names must be unique."
}

Write-Host "Loaded $($participants.Count) participant(s) from $CsvPath" -ForegroundColor Cyan

# --- pair ------------------------------------------------------------------------
$pairs = Get-SecretSantaPairs -Participants $participants

Write-Host ''
Write-Host 'Assignments:' -ForegroundColor Green
foreach ($p in $pairs) {
    Write-Host ("  {0}  ->  {1}" -f $p.Giver, $p.Receiver)
}

# --- output file -----------------------------------------------------------------
if (-not $OutPath) {
    $folder = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'SecretSanta'
    if (-not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }
    $OutPath = Join-Path $folder ("assignments_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("Secret Santa assignments  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("Source: $CsvPath")
$lines.Add('')
foreach ($p in $pairs) {
    $lines.Add(('{0} -> {1}' -f $p.Giver, $p.Receiver))
}
$lines.Add('')
$lines.Add('Keep this file private. Do not commit it or share the full list.')

if ($PSCmdlet.ShouldProcess($OutPath, 'Write assignment list')) {
    Set-Content -Path $OutPath -Value $lines -Encoding UTF8
    Write-Host "Wrote $OutPath" -ForegroundColor Green
} else {
    Write-Host "[WhatIf] Would write assignments to $OutPath" -ForegroundColor Yellow
}

# --- optional email --------------------------------------------------------------
if (-not $SendEmail) {
    Write-Host ''
    Write-Host 'Email not sent (pass -SendEmail -MailFrom ... -SmtpServer ... to notify).' -ForegroundColor DarkGray
    return
}

if (-not $MailFrom -or -not $SmtpServer) {
    throw '-SendEmail requires both -MailFrom and -SmtpServer.'
}

Write-Warning 'Send-MailMessage is deprecated by Microsoft. Prefer Graph or Mailozaurr when available.'

$sent = 0; $failed = 0
foreach ($p in $pairs) {
    $subject = 'Your Secret Santa assignment'
    $body = @"
Hello $($p.Giver),

You are Secret Santa for: $($p.Receiver)

Happy gifting!
"@
    $mailArgs = @{
        To         = $p.GiverEmail
        From       = $MailFrom
        Subject    = $subject
        Body       = $body
        SmtpServer = $SmtpServer
        Port       = $SmtpPort
    }
    if ($UseSsl)     { $mailArgs.UseSsl = $true }
    if ($Credential) { $mailArgs.Credential = $Credential }

    if ($PSCmdlet.ShouldProcess($p.GiverEmail, "Email assignment (receiver: $($p.Receiver))")) {
        try {
            Send-MailMessage @mailArgs -ErrorAction Stop
            $sent++
            Write-Host "  Sent to $($p.Giver) <$($p.GiverEmail)>" -ForegroundColor Green
        }
        catch {
            $failed++
            Write-Warning "Failed for $($p.Giver) <$($p.GiverEmail)>: $($_.Exception.Message)"
        }
    } else {
        Write-Host "[WhatIf] Would email $($p.Giver) <$($p.GiverEmail)> -> $($p.Receiver)" -ForegroundColor Yellow
    }
}

if ($SendEmail -and -not $WhatIfPreference) {
    Write-Host "Email done. Sent: $sent  Failed: $failed" -ForegroundColor Cyan
}

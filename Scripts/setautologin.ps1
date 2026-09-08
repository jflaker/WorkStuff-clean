#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Views, enables, or disables Windows automatic logon (AutoAdminLogon).

.DESCRIPTION
    Credentials are prompted for at runtime -- never hardcoded in this file.

    SECURITY WARNING
    The AutoAdminLogon mechanism stores the password as PLAINTEXT in the
    registry at HKLM:\...\Winlogon\DefaultPassword. Any local user can read
    it. That is a limitation of the mechanism itself, not of this script.

    If you need autologon on anything that matters, use Sysinternals Autologon
    (https://learn.microsoft.com/sysinternals/downloads/autologon) instead --
    it stores the secret as an LSA secret rather than a readable registry
    string. Use this script only on throwaway kiosk/signage boxes with a
    low-privilege account that has no access to anything else.

.EXAMPLE
    .\setautologin.ps1 -Show
.EXAMPLE
    .\setautologin.ps1 -Enable
.EXAMPLE
    .\setautologin.ps1 -Disable -WhatIf
#>
[CmdletBinding(DefaultParameterSetName = 'Show', SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(ParameterSetName = 'Show')]   [switch]$Show,
    [Parameter(ParameterSetName = 'Enable')] [switch]$Enable,
    [Parameter(ParameterSetName = 'Disable')][switch]$Disable,
    [Parameter(ParameterSetName = 'Enable')] [pscredential]$Credential,
    [Parameter(ParameterSetName = 'Enable')] [string]$Domain = $env:USERDOMAIN
)

$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

function Get-AutoLogonState {
    $p = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Enabled        = ($p.AutoAdminLogon -eq '1')
        DefaultDomain  = $p.DefaultDomainName
        DefaultUser    = $p.DefaultUserName
        PasswordStored = -not [string]::IsNullOrEmpty($p.DefaultPassword)
    }
}

function Disable-AutoLogon {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Disable automatic logon')) {
        foreach ($n in 'AutoAdminLogon','DefaultDomainName','DefaultUserName','DefaultPassword','AutoLogonCount') {
            Remove-ItemProperty -Path $regPath -Name $n -ErrorAction SilentlyContinue
        }
        Write-Host 'Automatic logon disabled; stored password value removed.' -ForegroundColor Green
    }
}

function Enable-AutoLogon {
    param([pscredential]$Cred, [string]$Dom)
    Write-Warning 'The password will be written to the registry in PLAINTEXT and is readable by any local user.'
    Write-Warning 'Use Sysinternals Autologon instead if this machine can reach anything sensitive.'
    if (-not $PSCmdlet.ShouldProcess("$Dom\$($Cred.UserName)", 'Enable automatic logon')) { return }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Cred.Password)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        Set-ItemProperty -Path $regPath -Name 'AutoAdminLogon'    -Value '1'            -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultDomainName' -Value $Dom           -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultUserName'   -Value $Cred.UserName -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultPassword'   -Value $plain         -Type String
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        if (Get-Variable plain -ErrorAction SilentlyContinue) { Remove-Variable plain -Force }
    }
    Write-Host "Automatic logon enabled for $Dom\$($Cred.UserName)." -ForegroundColor Green
}

$state = Get-AutoLogonState
switch ($PSCmdlet.ParameterSetName) {
    'Disable' {
        if (-not $state.Enabled) { Write-Host 'Automatic logon is already disabled.' -ForegroundColor Yellow }
        Disable-AutoLogon
    }
    'Enable' {
        if (-not $Credential) { $Credential = Get-Credential -Message "Account to log on automatically (domain: $Domain)" }
        if (-not $Credential) { Write-Host 'Cancelled.' -ForegroundColor Yellow; return }
        Enable-AutoLogon -Cred $Credential -Dom $Domain
    }
    default {
        Write-Host '=== Automatic Logon Status ===' -ForegroundColor Cyan
        $state | Format-List
        Write-Host 'Use -Enable or -Disable to change it. Add -WhatIf to preview.' -ForegroundColor DarkGray
    }
}

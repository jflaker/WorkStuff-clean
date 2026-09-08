$domain = "DOMAIN"
$username = "USERNAME"
$password = "PASSWORD"  # Make sure to replace "YourPassword" with the actual password
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Function to disable automatic login
function Disable-AutoLogin {
    Remove-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Write-Output "Automatic login disabled."
}

# Function to enable automatic login
function Enable-AutoLogin {
    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $domain
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $username
    Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $password
    Write-Output "Automatic login setup for $domain\$username completed."
}

# Check the current setting of AutoAdminLogon
$currentSetting = Get-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue

if ($currentSetting -and $currentSetting.AutoAdminLogon -eq "1") {
    Write-Output "Automatic login is currently enabled for $domain\$username."
    $response = Read-Host "Do you want to disable automatic login? (Y/N)"
    if ($response -eq "Y") {
        Disable-AutoLogin
    } else {
        Write-Output "No changes made."
    }
} else {
    $currentDomainUser = Get-ItemProperty -Path $regPath -Name "DefaultDomainName", "DefaultUserName" -ErrorAction SilentlyContinue
    if ($currentDomainUser) {
        Write-Output "Automatic login is currently disabled."
        Write-Output "Current user: $($currentDomainUser.DefaultDomainName)\$($currentDomainUser.DefaultUserName)"
    } else {
        Write-Output "Automatic login is currently disabled, and no default user is set."
    }
    $response = Read-Host "Do you want to enable automatic login for $domain\$username? (Y/N)"
    if ($response -eq "Y") {
        Enable-AutoLogin
    } else {
        Write-Output "No changes made."
    }
}

# Reset-ADPassword.ps1

function Get-RandomPassword {
    <#
        Cryptographically random password with at least one character from each class.
        Ambiguous characters (I l 1 O 0) are excluded so it can be read aloud safely.
    #>
    [CmdletBinding()]
    param([int]$Length = 16)

    $sets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ',   # no I, O
        'abcdefghijkmnopqrstuvwxyz',  # no l
        '23456789',                   # no 0, 1
        '!#$%&*+-=?@'
    )
    $all = -join $sets

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        function Get-Char([string]$pool) {
            $bytes = [byte[]]::new(4)
            $rng.GetBytes($bytes)
            $value = [BitConverter]::ToUInt32($bytes, 0)
            $pool[[int]($value % [uint32]$pool.Length)]
        }

        # One from each class first, so complexity rules are always satisfied.
        $chars = foreach ($set in $sets) { Get-Char $set }
        $chars += for ($i = $sets.Count; $i -lt $Length; $i++) { Get-Char $all }

        # Shuffle so the guaranteed characters are not always in the same positions.
        $shuffled = $chars | Sort-Object { $b = [byte[]]::new(4); $rng.GetBytes($b); [BitConverter]::ToUInt32($b, 0) }
        -join $shuffled
    }
    finally { $rng.Dispose() }
}


# Create menu options
$options = @{
    1 = "Reset password and unlock account"
    2 = "Unlock account only"
}

# Display menu options and prompt user to select one
Write-Host "Select an option:"
$options.GetEnumerator() | ForEach-Object {Write-Host "$($_.Key): $($_.Value)"}
$option = Read-Host "Enter the number of the option you want to use."

# Prompt user to select how to input users
$userInput = Read-Host "How do you want to input users? Type '1' to select from a list, or type '2' to type them in."

if ($userInput -eq "1") {
    # Populate a list of users to select from
    $userList = Get-ADUser -Filter * | Select-Object SamAccountName | Sort-Object SamAccountName

    # Display list of users and prompt user to select one
    Write-Host "Here is a list of users:"
    Write-Host ""
    $userList | ForEach-Object {Write-Host $_.SamAccountName}
    Write-Host ""
    $userName = Read-Host "Enter the name of the user you want to reset the password for."
} elseif ($userInput -eq "2") {
    # Prompt user to input username
    $userName = Read-Host "Enter the name of the user you want to reset the password for."
} else {
    Write-Host "Invalid input. Please try again."
    break
}

if ($option -eq "1") {
    # Reset password and unlock account
    # Generate a unique random temp password per reset -- never a fixed, guessable value.
    # Uses System.Security.Cryptography, which works on BOTH Windows PowerShell 5.1 and
    # PowerShell 7+. (System.Web.Security.Membership is .NET Framework only and throws
    # on PowerShell 7.)
    $tempPassword   = Get-RandomPassword -Length 16
    $securePassword = ConvertTo-SecureString $tempPassword -AsPlainText -Force
    Set-ADAccountPassword -Identity $userName -NewPassword $securePassword -Reset -PassThru | Set-ADUser -ChangePasswordAtLogon $true
    Unlock-ADAccount -Identity $userName

    Write-Host ""
    Write-Host "Account for user $userName has been unlocked and the password reset."
    Write-Host "Temporary password (shown once -- deliver out of band, do not email): $tempPassword" -ForegroundColor Yellow
    Write-Host "The user must change it at next logon."
} elseif ($option -eq "2") {
    # Unlock account only
    Unlock-ADAccount -Identity $userName

    Write-Host ""
    Write-Host "Account for user $userName has been unlocked."
} else {
    Write-Host "Invalid input. Please try again."
    break
}

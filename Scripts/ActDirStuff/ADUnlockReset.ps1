# Reset-ADPassword.ps1

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
    $securePassword = ConvertTo-SecureString "***REMOVED-CREDENTIAL***" -AsPlainText -Force
    Set-ADAccountPassword -Identity $userName -NewPassword $securePassword -Reset -PassThru | Set-ADUser -ChangePasswordAtLogon $true
    Unlock-ADAccount -Identity $userName

    Write-Host ""
    Write-Host "Password for user $userName has been reset to '***REMOVED-CREDENTIAL***' and the account has been unlocked."
} elseif ($option -eq "2") {
    # Unlock account only
    Unlock-ADAccount -Identity $userName

    Write-Host ""
    Write-Host "Account for user $userName has been unlocked."
} else {
    Write-Host "Invalid input. Please try again."
    break
}

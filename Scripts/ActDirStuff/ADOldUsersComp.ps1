#!/usr/bin/env pwsh

# Importing the ImportExcel module
Import-Module -Name ImportExcel

# Setting the threshold for inactive users and computers
$threshold = (Get-Date).AddDays(-90)

# Retrieving all user objects from Active Directory
$users = Get-ADUser -Filter *
# Retrieving all computer objects from Active Directory
$computers = Get-ADComputer -Filter *

# Defining arrays to store inactive users and computers
$inactiveUsers = @()
$inactiveComputers = @()

# Looping through each user object
foreach ($user in $users) {
    # Checking the last logon date of the user object
    if ([bool]($user.LastLogonDate -ne $null -and $user.LastLogonDate -lt $threshold)) {
        $inactiveUsers += [PSCustomObject]@{
            ObjectName = $user.Name
            ObjectType = "User"
            LastLogon = $user.LastLogonDate
        }
    }
}

# Looping through each computer object
foreach ($computer in $computers) {
    # Checking the last logon date of the computer object
    if ([bool]($computer.LastLogonDate -ne $null -and $computer.LastLogonDate -lt $threshold)) {
        $inactiveComputers += [PSCustomObject]@{
            ObjectName = $computer.Name
            ObjectType = "Computer"
            LastLogon = $computer.LastLogonDate
        }
    }
}

# Adding the "DeleteYN" column
$inactiveUsers = $inactiveUsers | Select-Object *,@{Name="DeleteYN";Expression={"N"}}
$inactiveComputers = $inactiveComputers | Select-Object *,@{Name="DeleteYN";Expression={"N"}}

# Creating a hashtable with the sheet names and inactive objects data
$data = @{
    "Inactive Users" = $inactiveUsers
    "Inactive Computers" = $inactiveComputers
}

# If there are inactive users or computers, writing them to an Excel workbook and emailing it to admin@example.com
if ($inactiveUsers.Count -gt 0 -or $inactiveComputers.Count -gt 0) {
    # Creating an Excel workbook with the inactive objects
    $excelPath = "C:\InactiveObjects.xlsx"
    $data | Export-Excel -Path $excelPath -AutoSize -WorksheetName $($data.Keys) -BoldTopRow

    # Emailing the Excel workbook to admin@example.com
    $emailBody = "The following users and/or computers have not connected to Active Directory in more than 90 days."
    Send-MailMessage -To "admin@example.com" -Subject "Inactive Objects Report" -Body $emailBody -Attachment $excelPath -SmtpServer "smtp.example.com"
}

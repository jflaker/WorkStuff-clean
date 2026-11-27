# Active Directory

Windows PowerShell 5.1 scripts for a domain-joined PC. They need the Active Directory module (RSAT). `ADLastLogin.ps1` and `ADOldUsersComp.ps1` also need ImportExcel (`Install-Module ImportExcel`).

Read access is enough for the reports. `ADUnlockReset.ps1` needs the right to reset that user's password and unlock the account. `Restart-LongUptimeComputers.ps1` needs permission to query CIM on each computer and to restart it.

Workbooks and the reboot CSV go to `Documents\ADReports` unless you pass `-OutputFolder`. Those files contain real names. Leave them out of git.

| Script | What it does |
|---|---|
| `ADLastLogin.ps1` | Excel file `UserComputer_<timestamp>.xlsx` with sheets USERS and COMPUTERS. Last logon is `LastLogonTimestamp` converted from file time. That attribute replicates about every 9–14 days. Missing values are stored as `Never Logged On`. |
| `ADOldUsersComp.ps1` | Excel file of users and computers with `LastLogonDate` older than `-Days` (default 90). Never-logged-on objects are counted on screen and left out of the workbook. Pass `-MailTo`, `-MailFrom`, and `-SmtpServer` together to attach the workbook to a message (`Send-MailMessage`). |
| `ADShowDisableLocked.ps1` | Prints locked accounts (`Search-ADAccount -LockedOut`) and disabled accounts (`Search-ADAccount -AccountDisabled`). Screen only. |
| `ADUnlockReset.ps1` | Menu. Option 1: random 16-character password, change at next logon, unlock. Option 2: unlock only. The password is printed once. Enter a SamAccountName, or choose from a list of every domain user. |
| `Restart-LongUptimeComputers.ps1` | Finds computers up longer than `-UptimeDays` (default 30) with no interactive `Win32_ComputerSystem.UserName`. Skips anything that does not answer one ping. Each reboot prompts. `-WhatIf` reboots nothing. `-Confirm:$false` reboots without prompts. Weekdays before 18:00 the script exits unless you pass `-IgnoreSchedule`. Weekends run at any hour. Unreachable computers are written to `RebootScheduleLog_<timestamp>.csv`. |

```powershell
.\ADLastLogin.ps1 -OutputFolder D:\Reports
.\ADOldUsersComp.ps1 -Days 180 -MailTo it@example.com -MailFrom reports@example.com -SmtpServer smtp.example.com
.\ADShowDisableLocked.ps1
.\ADUnlockReset.ps1
.\Restart-LongUptimeComputers.ps1 -WhatIf
.\Restart-LongUptimeComputers.ps1 -Confirm:$false -IgnoreSchedule
```
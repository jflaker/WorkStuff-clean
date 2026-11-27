# WorkStuff

Windows helpdesk scripts and two offline web tools for desktop and endpoint support: Active Directory reports, remote event-log triage, patching, kiosk setup, a lobby display, and a Secret Santa draw.

Run the Active Directory scripts on a domain-joined Windows PC. The tables below name the scripts that need an elevated window. Scope is Active Directory, the local Windows endpoint, small file and drive utilities, and the two web tools. Each folder has its own README.

## Layout

| Folder | Contents |
|---|---|
| [ActiveDirectory](ActiveDirectory/) | Last-logon and stale-object workbooks, locked and disabled accounts, password reset or unlock, reboot of machines with long uptime. |
| [Endpoint](Endpoint/) | Event-log triage, uptime, component-store repair, Windows Update and winget, computer naming, kiosk autologon, browser profile removal. |
| [Utilities](Utilities/) | Drive mapping, sort loose files by type, Secret Santa, a menu experiment, and a disabled SendKeys sample. |
| [DisplayBoard](DisplayBoard/) | Lobby slideshow. A scheduled task mirrors a file share and a Chrome kiosk shows the pictures. |
| [SecretSantaWeb](SecretSantaWeb/) | Secret Santa in one HTML file. Nothing is uploaded. |
| [Linux](Linux/) | Offline local SAM password clear with `chntpw`. |

## Requirements

| Need | Used by |
|---|---|
| Windows PowerShell 5.1 | Every `.ps1`. Scripts marked `#Requires -Version 5.1` also load on PowerShell 7 when the modules they need exist on Windows. |
| Active Directory module (RSAT) | Everything in `ActiveDirectory/`. `Endpoint/New-ComputerName.ps1` imports it only to test whether the proposed name is already in the domain. |
| ImportExcel (`Install-Module ImportExcel`) | `ADLastLogin.ps1`, `ADOldUsersComp.ps1`. |
| PSWindowsUpdate | `Invoke-WindowsMaintenance.ps1`. The script installs it for all users when it is missing. |
| winget on PATH | The application-upgrade section of `Invoke-WindowsMaintenance.ps1`. The script skips that section when `winget` is absent. |
| WinRM on the target | `Get-EventLogTriage.ps1` against a remote computer. The local computer is queried in-process. |
| Google Chrome | Display-board kiosk task. |
| Administrator | `Invoke-WindowsMaintenance.ps1`, `Invoke-StartupTroubleshooting.ps1`, `Set-AutoLogon.ps1`, `Install-DisplayBoard.ps1`. Renaming a PC with `New-ComputerName.ps1 -Rename` also needs an elevated session. |
| `chntpw`, root, offline Windows hive | `Linux/clear-offline-windows-password.sh`. |

Account rights follow the operation: domain read for the reports, reset-password and unlock rights for `ADUnlockReset.ps1`, and remote CIM plus restart rights for `Restart-LongUptimeComputers.ps1`.

## Active Directory

Run from `ActiveDirectory/`. Workbooks and the reboot problem list go to `Documents\ADReports` unless you pass `-OutputFolder`. Those files contain real account and computer names. Leave them out of git.

| Script | What it does |
|---|---|
| `ADLastLogin.ps1` | Excel workbook, sheets USERS and COMPUTERS. Last logon comes from `LastLogonTimestamp` (replicated about every 9–14 days, so it can lag). Empty values are written as `Never Logged On`. |
| `ADOldUsersComp.ps1` | Users and computers whose `LastLogonDate` is older than `-Days` (default 90). Objects that have never logged on are counted on screen and omitted from the workbook. Email is sent only when `-MailTo`, `-MailFrom`, and `-SmtpServer` are all set. |
| `ADShowDisableLocked.ps1` | Prints locked accounts and disabled accounts. Screen only. |
| `ADUnlockReset.ps1` | Menu. Option 1 sets a random 16-character password, requires a change at next logon, and unlocks. Option 2 unlocks only. Any other answer is asked again. The temporary password is printed once. You can type a SamAccountName or pick from every user in the domain. |
| `Restart-LongUptimeComputers.ps1` | Domain computers whose uptime is greater than `-UptimeDays` (default 30) and whose `Win32_ComputerSystem.UserName` is empty. ConfirmImpact is High, so each reboot prompts. `-WhatIf` lists them and reboots nothing. `-Confirm:$false` reboots without prompts. Outside weekends and weekdays after 18:00 the script returns immediately unless you pass `-IgnoreSchedule`. Machines that fail ping or CIM are written to a timestamped CSV. |

```powershell
.\ADLastLogin.ps1
.\ADOldUsersComp.ps1 -Days 180 -MailTo it@example.com -MailFrom reports@example.com -SmtpServer smtp.example.com
.\ADShowDisableLocked.ps1
.\ADUnlockReset.ps1
.\Restart-LongUptimeComputers.ps1 -WhatIf
```

## Endpoint

| Script | What it does |
|---|---|
| `Get-EventLogTriage.ps1` | Errors and warnings from the System and Application logs for the last `-Days` (default 30). Add the Security log with `-IncludeSecurity`. Remote work is one `Get-WinEvent` per log, capped by `-MaxEvents` (default 20000). Grouping and the report run on your machine. Output: `Documents\Diagnostics\SystemLogReport_*.txt`. `-Csv` also writes the events. `-Credential` is passed to `Invoke-Command`. |
| `Get-Uptime.ps1` | One Linux-style uptime line: local time, uptime, interactive session count, and a 1/5/15 load line. The load numbers are averages of `\System\Processor Queue Length`, stored in `%LOCALAPPDATA%\uptime_loadhistory.json`. `-LoadAvg` prints the three numbers only. `-Pretty` and `-Since` follow `uptime -p` and `uptime -s`. |
| `Invoke-StartupTroubleshooting.ps1` | Administrator. DISM `/Online /Cleanup-Image /RestoreHealth`, then `sfc /scannow`, physical-disk health, SMART predictive-failure status, problem devices, startup commands, and the last 20 System errors. `-RunChkdsk` schedules `chkdsk C: /f /r` at next boot. `-EnableBootLog` sets the current BCD entry's boot log (`C:\Windows\ntbtlog.txt` after restart). Transcript: `Documents\Diagnostics\Troubleshoot_*.txt`. |
| `Invoke-WindowsMaintenance.ps1` | Administrator. Sets the current-user execution policy to RemoteSigned, installs PSWindowsUpdate when it is missing, installs available Windows updates, then runs `winget upgrade --all` when winget is installed. The computer restarts only when you pass `-Reboot` and updates require it. Transcript: `Documents\Diagnostics\WindowsMaintenance_*.txt`. |
| `New-ComputerName.ps1` | Proposes `<ABBR>-<last 6 hex characters of the MAC>` from `departments.csv` beside the script. Checks Active Directory. If the Ethernet-based name exists, tries Bluetooth, then Wi-Fi. Asks before renaming. `-Rename` applies it without the question (elevated session, reboot required). `-Restart` reboots after a successful rename. `-NoPrompt` prints the name and skips the questions. Names longer than 15 characters are rejected. |
| `Set-AutoLogon.ps1` | Administrator. `-Show` (default), `-Enable`, `-Disable`. Enable prompts for a credential, or takes `-Credential` and `-Domain` (default `$env:USERDOMAIN`). The password is stored in plaintext at `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultPassword`. `-Disable` removes the autologon values, including that password. |
| `Remove-BrowserProfileFolders.ps1` | Deletes, for the current user, Chrome `User Data\Default`, Edge `User Data\Default`, and Firefox `Profiles`, when those paths exist. Does not stop the browsers. |
| `Clear-BrowserUserData.ps1` | Stops `chrome`, `firefox`, and `msedge`, then deletes Chrome `User Data`, Firefox `Profiles`, and Edge `User Data`. Waits on `Pause` at the end. |

```powershell
.\Get-EventLogTriage.ps1 -ComputerName PC-104,PC-105 -Days 7
.\Get-Uptime.ps1
.\Get-Uptime.ps1 -LoadAvg
.\Invoke-StartupTroubleshooting.ps1
.\Invoke-WindowsMaintenance.ps1
.\Invoke-WindowsMaintenance.ps1 -Reboot
.\New-ComputerName.ps1 -Dept IT
.\Set-AutoLogon.ps1 -Show
.\Remove-BrowserProfileFolders.ps1
.\Clear-BrowserUserData.ps1
```

`Endpoint/departments.csv` is a sample: Accounting, Human Resources, Information Technology, Sales, Marketing, Finance, Operations, Executive, with 2–4 character abbreviations. The naming script can append a row after you confirm.

`PC-104` in the example is a sample computer name.

## Utilities

| Script | What it does |
|---|---|
| `Connect-NetworkDrives.ps1` | Reads `drives.csv` beside the script (`DriveLetter`, `NetworkPath`), prompts once with `Get-Credential`, and creates a persistent drive for each letter that is not already present. |
| `Move-FilesByType.ps1` | Moves files from `-SourceFolder` (default Desktop) into Pictures, Videos, Documents, or Music by extension. Skips AppData and those destination folders. A name collision becomes `name (1).ext`. `-Recurse` is off unless you pass it. `-WhatIf` prints the plan and moves nothing. |
| `SecretSanta.ps1` | Derangement from a CSV with columns `Name` and `Email`. Every row needs a non-empty email. Default input is `santas.csv` beside the script. Writes `Documents\SecretSanta\assignments_*.txt`. Mail goes out only with `-SendEmail`, `-MailFrom`, and `-SmtpServer` (`-SmtpPort` default 25, optional `-UseSsl` and `-Credential`). `-WhatIf` skips writing the file and skips sending. |
| `MenuTesting.ps1` | Numbered menu from `%USERPROFILE%\utilityScripts.csv` (`Description`, `Path`, `Filename`, `ActiveYN`). Creates one example row when the file is missing. The chosen path is dot-sourced. This menu is separate from the other scripts in the repo. |
| `sendkeys.ps1` | Disabled. The loop that sent `J` and Enter to the foreground window is inside a comment. The file retains the `user32.dll` P/Invoke sample. Running it does nothing. |

```powershell
.\Connect-NetworkDrives.ps1
.\Move-FilesByType.ps1 -WhatIf
.\Move-FilesByType.ps1 -SourceFolder "$env:USERPROFILE\Downloads" -Recurse
Copy-Item .\santas.example.csv .\santas.csv
.\SecretSanta.ps1 -WhatIf
.\SecretSanta.ps1 -SendEmail -MailFrom santa@example.com -SmtpServer smtp.example.com
```

The committed `Utilities/drives.csv` is a template. `FILESERVER01`, `FILESERVER02`, and `ShareName` are placeholders:

```csv
DriveLetter,NetworkPath
R:,\\FILESERVER01\ShareName
S:,\\FILESERVER02\ShareName
T:,\\FILESERVER02\ShareName\SubFolder
```

Replace them on the machine where you map drives. Keep a CSV of real servers out of git (`*.csv` is ignored except the three sample files listed below).

`SecretSanta.ps1` requires an email on every row. [SecretSantaWeb](SecretSantaWeb/) accepts a blank email and can also record exclusions.

## Display board

Details, including the backslash rules for `config.json`, are in [DisplayBoard/README.md](DisplayBoard/README.md).

`DisplayBoard/config.json` is committed with placeholder `\\FILESERVER01\Slideshow\images`. Change it in `settings.html` or in the JSON file, then on the display PC:

```powershell
.\Install-DisplayBoard.ps1
.\Apply-Config.ps1 -TriggerSync
```

`SlideshowSync.ps1` mirrors the share into `localPath` (default `images`) with `robocopy /MIR`. That folder is a cache. `playlist.js`, `config.js`, `sync.log`, and `images\` are gitignored. If the share is unreachable, the sync leaves the local copies in place.

## Secret Santa in the browser

Open [SecretSantaWeb/index.html](SecretSantaWeb/index.html) by double-clicking it. Participants, the draw, and the reveal stay in that browser tab. Refreshing the page clears them.

## Linux

[Linux/clear-offline-windows-password.sh](Linux/clear-offline-windows-password.sh) runs `chntpw` against an offline SAM hive, then reboots the machine you are booted into.

```bash
./clear-offline-windows-password.sh
./clear-offline-windows-password.sh SomeLocalUser /mnt/windows/Windows/System32/config/SAM
```

With no arguments the account is `Administrator` and the hive path is `/Windows/System32/config/SAM`. The script invokes `chntpw` three times (no piped answer, then menu choice `1`, then `y`) and always runs `sudo reboot`. Use it on a Windows volume you are allowed to administer, from a Linux live session where that path is the offline hive. It changes a local SAM account. Active Directory passwords are untouched.

## Files that stay out of git

`.gitignore` excludes Excel workbooks, logs, extra CSV files, `santas.csv`, and display-board runtime files. These samples are tracked on purpose:

- `Endpoint/departments.csv`
- `Utilities/drives.csv` (placeholder UNC paths)
- `Utilities/santas.example.csv` (Alice, Bob, Carol, Dave at example.com)

Copy `santas.example.csv` to `santas.csv` and fill in real people locally. The AD scripts print a warning after they write a workbook.

## Help

The PowerShell scripts carry comment-based help.

```powershell
Get-Help .\ADLastLogin.ps1 -Full
```
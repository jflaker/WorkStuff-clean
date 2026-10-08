# Scripts

PowerShell 5.1 helpers for a Windows PC. Most of these expect a domain-joined machine and an elevated window.

Active Directory scripts are in [ActDirStuff](ActDirStuff/). They need the AD module (`RSAT`).

Do not commit Excel reports, real Santa lists, or `santas.csv`. Those files hold names and account data. AD scripts write under `Documents\ADReports` by default.

## PC and helpdesk

| Script | Use |
|---|---|
| `CheckLogs.ps1` | Important event-log entries from a remote PC (WinRM). |
| `UPTIME.ps1` | Uptime, and whether a reboot is overdue. |
| `troubleshoot.ps1` | DISM / SFC repair. Administrator. |
| `runupdates.ps1` | Install pending Windows updates. Administrator. |
| `New-ComputerName.ps1` | Suggest a name from `departments.csv` plus the MAC. |
| `setautologin.ps1` | Kiosk auto-logon. Stores the password in the registry. |
| `ConnectDrives.ps1` | Map drives listed in `drives.csv`. |
| `movefiles.ps1` | Move files between folders. |
| `BrowserPurge.ps1`, `ClearHistory.ps1` | Clear browser data on this PC. |
| `sendkeys.ps1` | Send keystrokes to a window. |
| `SecretSanta.ps1` | Draw from a CSV and optionally email. Example: `santas.example.csv`. Browser version: [SecretSantaWeb](../SecretSantaWeb/). |

## Skip these

| Script | Why |
|---|---|
| `Drives.ps1` | Older copy of `ConnectDrives.ps1`. Use that one. |
| `MenuTesting.ps1` | Menu experiment. It is not a launcher for the scripts above. |

## Data files

| File | Used by |
|---|---|
| `departments.csv` | `New-ComputerName.ps1` |
| `drives.csv` | `ConnectDrives.ps1` |
| `santas.example.csv` | Shape of the Secret Santa CSV. Copy it; do not fill in real people in git. |

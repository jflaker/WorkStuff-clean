# WorkStuff

Personal Windows helpdesk scripts and two small offline web tools.
Most `.ps1` files must be run on a domain-joined Windows PC, often as Administrator.

## Start here

| Folder | What it is | How to open it |
|---|---|---|
| [SlideShowExperiment](SlideShowExperiment/) | Lobby display. Drop images in a network folder; the PC syncs and shows them. | Read that folder's README. Set the path in `settings.html` or `config.json`. |
| [SecretSantaWeb](SecretSantaWeb/) | Secret Santa in the browser. No server, nothing is uploaded. | Double-click `index.html`. |
| [Scripts](Scripts/) | PowerShell for AD, logs, updates, drives, and PC setup. | Run from an elevated PowerShell window. |
| [bash](bash/) | One Kali example. Not used with the PowerShell scripts. | See that folder's README. |

## Scripts

| Script | Use |
|---|---|
| `Scripts/CheckLogs.ps1` | Pull important Windows event-log entries from a remote PC. |
| `Scripts/UPTIME.ps1` | How long a PC has been up, and whether it needs a reboot. |
| `Scripts/troubleshoot.ps1` | DISM / SFC style repair steps. |
| `Scripts/runupdates.ps1` | Install pending Windows updates. |
| `Scripts/ActDirStuff/ADUnlockReset.ps1` | Unlock an account or reset a password. |
| `Scripts/ActDirStuff/ADLastLogin.ps1` | Last logon report. |
| `Scripts/ActDirStuff/ADOldUsersComp.ps1` | Stale users and computers. |
| `Scripts/ActDirStuff/ADShowDisableLocked.ps1` | Disabled or locked accounts. |
| `Scripts/ActDirStuff/reboot30days.ps1` | Computers that have not rebooted in 30 days. |
| `Scripts/New-ComputerName.ps1` | Suggest a computer name from department + MAC. |
| `Scripts/setautologin.ps1` | Kiosk auto-logon. |
| `Scripts/ConnectDrives.ps1` | Map drives from `drives.csv`. |
| `Scripts/movefiles.ps1` | Move files between folders. |
| `Scripts/SecretSanta.ps1` | Same draw as the web app, with optional email. Use `santas.example.csv`. |
| `Scripts/BrowserPurge.ps1`, `ClearHistory.ps1` | Clear browser data on a PC. |
| `Scripts/sendkeys.ps1` | Send keystrokes to a window. |
| `Scripts/MenuTesting.ps1` | Old menu experiment. Not the way to launch the others. |
| `bash/KaliWinPwd.sh` | Generic `chntpw` example. Hardcoded `Administrator` and SAM path. |

`Drives.ps1` is a second copy of the drive mapper. Prefer `ConnectDrives.ps1`.

## Do not commit

Excel reports, real user lists, and `santas.csv` are gitignored on purpose. They contain names and account data. Scripts write reports under `Documents\ADReports` by default.

Display-board runtime files (`playlist.js`, `config.js`, `sync.log`, `images\`) are also gitignored.

## Requirements

- Windows PowerShell 5.1
- Active Directory module for anything under `Scripts/ActDirStuff`
- Chrome, for the display-board kiosk task

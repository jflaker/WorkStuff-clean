# Endpoint

Windows PowerShell 5.1 helpers for the PC in front of you, and for remote event logs. Run the ones marked Administrator from an elevated window.

| Script | Administrator | What it does |
|---|---|---|
| `Get-EventLogTriage.ps1` | Remote log read | System and Application errors and warnings for `-Days` (default 30). `-IncludeSecurity` adds the Security log. Remote targets use WinRM (`Invoke-Command`). One failure does not stop the rest. Report: `Documents\Diagnostics\SystemLogReport_*.txt`. `-Csv` writes `SystemLogEvents_*.csv`. |
| `Get-Uptime.ps1` | | Linux-style uptime line, plus a 1/5/15 average of `\System\Processor Queue Length` kept in `%LOCALAPPDATA%\uptime_loadhistory.json`. `-LoadAvg`, `-Pretty`, `-Since`. |
| `Invoke-StartupTroubleshooting.ps1` | Yes | DISM `/RestoreHealth`, then `sfc /scannow`, disk health, SMART failure prediction, problem devices, startup commands, last 20 System errors. `-RunChkdsk` schedules `chkdsk C: /f /r` at next boot. `-EnableBootLog` turns on the BCD boot log. Transcript under `Documents\Diagnostics`. |
| `Invoke-WindowsMaintenance.ps1` | Yes | Installs PSWindowsUpdate if missing, applies Windows updates, then `winget upgrade --all` when winget exists. Also sets the current-user execution policy to RemoteSigned. Reboots only with `-Reboot`. Transcript: `Documents\Diagnostics\WindowsMaintenance_*.txt`. |
| `New-ComputerName.ps1` | To rename | Name shape `<ABBR>-<last 6 hex of MAC>` from `departments.csv` in this folder. AD collision check, then Bluetooth, then Wi-Fi. `-Dept`, `-Rename`, `-Restart`, `-NoPrompt`. |
| `Set-AutoLogon.ps1` | Yes | `-Show`, `-Enable`, `-Disable`. Enable writes AutoAdminLogon and stores the password in plaintext under `HKLM:\...\Winlogon\DefaultPassword`. Any local user can read that value. |
| `Remove-BrowserProfileFolders.ps1` | | Deletes Chrome `User Data\Default`, Edge `User Data\Default`, and Firefox `Profiles` for the current user. Does not stop the browsers. |
| `Clear-BrowserUserData.ps1` | | Stops chrome, firefox, and msedge, deletes Chrome `User Data`, Firefox `Profiles`, and Edge `User Data`, then `Pause`. |

```powershell
.\Get-EventLogTriage.ps1 -ComputerName PC-104 -Days 7 -Csv
.\Get-Uptime.ps1 -Since
.\Invoke-StartupTroubleshooting.ps1
.\Invoke-WindowsMaintenance.ps1
.\New-ComputerName.ps1
.\Set-AutoLogon.ps1 -Enable
```

`departments.csv` columns are a department name and a 2–4 character abbreviation. A header row is optional. Sample departments in the committed file are generic (Accounting, Human Resources, Information Technology, and similar).

`PC-104` above is a sample name.
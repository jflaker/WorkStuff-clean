# Active Directory

These scripts need:

- Windows PowerShell 5.1
- The Active Directory module (RSAT)
- An account that can read the domain. Unlock and password reset also need the right to change that account.

Reports go to `Documents\ADReports` unless a script says otherwise. Do not commit those files. They contain real names and computer names.

| Script | Use |
|---|---|
| `ADUnlockReset.ps1` | Unlock an account, or set a new password. |
| `ADLastLogin.ps1` | Last logon for users. |
| `ADOldUsersComp.ps1` | Users and computers that have not been seen recently. |
| `ADShowDisableLocked.ps1` | Accounts that are disabled or locked. |
| `reboot30days.ps1` | Computers whose last boot is older than 30 days. |

Run them from this folder, or pass the full path, in an elevated PowerShell window on a domain-joined PC.

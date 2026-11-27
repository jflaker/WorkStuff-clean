# Utilities

| Script | What it does |
|---|---|
| `Connect-NetworkDrives.ps1` | Maps drives from `drives.csv` in this folder. Columns: `DriveLetter`, `NetworkPath`. Prompts with `Get-Credential`. Maps a letter only when `Test-Path` says it is missing. The mapping is persistent (`New-PSDrive -Persist`). |
| `Move-FilesByType.ps1` | Sorts files from `-SourceFolder` (default Desktop) into Pictures, Videos, Documents, and Music by extension. Skips AppData and the destination folders. Will not overwrite; it appends ` (n)` to the file name. `-WhatIf` previews. `-Recurse` walks subfolders. |
| `SecretSanta.ps1` | Pairs people from a CSV (`Name`, `Email`). Email may be blank. `-SendEmail` requires an email on every row. Nobody is paired with themselves. Default CSV is `santas.csv` beside the script (not in git). Copy `santas.example.csv`. Assignments are written to `Documents\SecretSanta\`. `-WhatIf` skips the file write. Mail is sent only with `-SendEmail -MailFrom -SmtpServer`. |
| `MenuTesting.ps1` | Menu from `%USERPROFILE%\utilityScripts.csv`. Creates an example file when it is missing. Dot-sources the script you pick. Separate from the other tools in this repository. |
| `sendkeys.ps1` | Disabled. The foreground `J` + Enter loop is commented out, so running the file does nothing. The comment block keeps a `user32.dll` P/Invoke example. |

```powershell
.\Connect-NetworkDrives.ps1
.\Move-FilesByType.ps1 -WhatIf
Copy-Item .\santas.example.csv .\santas.csv
.\SecretSanta.ps1
.\SecretSanta.ps1 -SendEmail -MailFrom santa@example.com -SmtpServer smtp.example.com -UseSsl
```

## drives.csv

The committed file is a template. Replace the placeholder servers before you rely on it:

```csv
DriveLetter,NetworkPath
R:,\\FILESERVER01\ShareName
S:,\\FILESERVER02\ShareName
T:,\\FILESERVER02\ShareName\SubFolder
```

`FILESERVER01` and `FILESERVER02` are examples, as are `ShareName` and `SubFolder`.

The browser version of Secret Santa is [SecretSantaWeb](../SecretSantaWeb/). Both allow a blank email. This script requires an email on every row only when you pass `-SendEmail`. The page can also record exclusion pairs. This script has no exclusion list.
# Display board

Lobby slideshow. Staff drop or delete pictures in a network folder. A scheduled task on the display PC copies them down, and the page picks up the new set without a reload.

## How it works

```text
\\SERVER\Share\images          people add or remove pictures here
        |
        |  task DisplayBoard-Sync, every syncIntervalMinutes
        |  reads config.json, robocopy /MIR into .\images\
        |  rewrites playlist.js only when the set changed
        |  writes config.js (slide time and poll time)
        v
slideshow.html                 Chrome kiosk, opened from file://
        |
        +-- re-reads playlist.js every pollMinutes
        +-- preloads new images and swaps at the next slide
```

No web server. `playlist.js` and `config.js` are normal script files, so the page works from `file://`.

## Set the path and the times

### Settings page

Open [settings.html](settings.html) in Chrome or Edge. Type the folder the normal Windows way:

```text
\\FILESERVER01\Slideshow\images
```

Do not double every backslash yourself. Save or Download writes a correct `config.json`.

### Or edit config.json

In Notepad, each `\` inside the quotes has to be written twice.

| What you mean | What the JSON file contains |
|---|---|
| `\\FILESERVER01\Slideshow\images` | `"\\\\FILESERVER01\\Slideshow\\images"` |

```json
{
  "sourcePath": "\\\\FILESERVER01\\Slideshow\\images",
  "localPath": "images",
  "syncIntervalMinutes": 15,
  "pollMinutes": 5,
  "slideSeconds": 8,
  "extensions": [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"]
}
```

`syncIntervalMinutes` is how often the PC copies the share. `pollMinutes` is how often the open page looks for a new list. `slideSeconds` is how long each picture stays up.

After a change, on the display PC:

```powershell
.\Apply-Config.ps1 -TriggerSync
```

That updates the scheduled task, writes `config.js`, and runs one sync.

## First-time setup

1. Copy this folder to the PC, for example `C:\DisplayBoard`.
2. Set `sourcePath` with `settings.html` or by editing `config.json`.
3. PowerShell **as Administrator** in that folder:

   ```powershell
   .\Install-DisplayBoard.ps1
   ```

4. First copy, then check the log:

   ```powershell
   Start-ScheduledTask -TaskName DisplayBoard-Sync
   Get-Content .\sync.log -Tail 20
   ```

5. Log off and on, or `Start-ScheduledTask -TaskName DisplayBoard-Kiosk`.

Remove both tasks: `.\Install-DisplayBoard.ps1 -Uninstall`.

Use a normal file share, not an admin share (`C$`). `localPath` must stay a disposable cache (the default `images` folder). `robocopy /MIR` deletes anything in that folder that is not on the share.

## What you should see

| Situation | What happens |
|---|---|
| Picture added or removed on the share | Shows up within one sync, then within one poll. The page does not reload. |
| Share unreachable | Sync stops and leaves the local copies alone. The board keeps the last good set. |
| Bad image file | Skipped. The rest keep rotating. |
| Nothing changed | `playlist.js` is not rewritten. |

## Files

| File | Role |
|---|---|
| `config.json` | Network path and timings. This is the file you edit. |
| `settings.html` | Form that writes `config.json` and handles backslashes. |
| `Apply-Config.ps1` | Push `config.json` into `config.js` and the scheduled task. |
| `SlideshowSync.ps1` | Copy the share and rebuild the playlist. |
| `Install-DisplayBoard.ps1` | Create the sync task and the Chrome kiosk task. Run once. |
| `slideshow.html` | The full-screen player. |
| `config.js`, `playlist.js`, `sync.log`, `images\` | Made on the PC. Do not commit them. |

# Display Board

Hands-off digital signage. Staff drop or delete images in a **network UNC folder**; the display PC syncs on a schedule and the slideshow picks up changes automatically.

## How it works

```
\\SERVER\Share\images          ← people add/remove pictures here
        |
        |  DisplayBoard-Sync task (every syncIntervalMinutes)
        |  reads config.json → robocopy /MIR → .\images\
        |  regenerates playlist.js only if the set changed
        |  writes config.js (timings for the browser)
        v
slideshow.html (Chrome kiosk, file://)
        |
        +-- re-reads playlist.js every pollMinutes
        +-- preloads new images, swaps at a slide boundary (no flash)
```

## Configure path and times

### Option A — edit the file

Open `config.json` in any text editor:

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

Then on the display PC:

```powershell
.\Apply-Config.ps1 -TriggerSync
```

That updates the scheduled-task interval, writes `config.js`, and runs one sync.

### Option B — freestanding web settings

Open `settings.html` in Chrome/Edge (double-click is fine):

1. Set the UNC path and intervals  
2. **Save config.json…** (or Download)  
3. Place that file in this folder on the display PC  
4. Run `.\Apply-Config.ps1 -TriggerSync`

## First-time setup on a display PC

1. Copy this folder to the machine, e.g. `C:\DisplayBoard`.
2. Edit `config.json` (or use `settings.html`) so `sourcePath` is your share.
3. PowerShell **as Administrator** in that folder:

   ```powershell
   .\Install-DisplayBoard.ps1
   ```

4. First sync:

   ```powershell
   Start-ScheduledTask -TaskName DisplayBoard-Sync
   Get-Content .\sync.log -Tail 20
   ```

5. Log off/on, or `Start-ScheduledTask -TaskName DisplayBoard-Kiosk`.

Uninstall: `.\Install-DisplayBoard.ps1 -Uninstall`.

## Behaviour

| Situation | What happens |
|---|---|
| Image added/removed on the share | Picked up within `syncIntervalMinutes`, then shown within `pollMinutes`. No reload. |
| Share unreachable | Sync exits without touching local files. Board keeps last good set. |
| Corrupt image | Skipped; rotation continues. |
| Nothing changed | `playlist.js` left alone. |

## Files

| File | Role |
|---|---|
| `config.json` | **You edit this** — UNC path and timings |
| `settings.html` | Optional UI to produce/edit `config.json` |
| `Apply-Config.ps1` | Apply config → `config.js` + scheduled task interval |
| `SlideshowSync.ps1` | robocopy + playlist (reads `config.json`) |
| `Install-DisplayBoard.ps1` | One-time task registration |
| `slideshow.html` | Kiosk player |
| `config.js` / `playlist.js` | Generated — do not commit |

Use a normal file share, **not** an admin share (`C$`).

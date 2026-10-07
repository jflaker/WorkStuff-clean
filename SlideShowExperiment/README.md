# Display Board

Hands-off digital signage. Staff drop or delete images in a **network folder**; the display PC syncs on a schedule and the slideshow picks up changes automatically.

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

### Option A — settings page (easiest)

Open **`settings.html`** in Chrome or Edge. Type the path the normal Windows way:

```text
\\FILESERVER01\Slideshow\images
```

You do **not** need to double every `\`. Save/Download writes a correct `config.json` for you.

### Option B — edit `config.json` by hand

If you edit the file in Notepad, JSON needs each backslash doubled:

| What you mean (Windows) | What to write inside the quotes in JSON |
|-------------------------|----------------------------------------|
| `\\FILESERVER01\Slideshow\images` | `"\\\\FILESERVER01\\Slideshow\\images"` |

Example file:

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

After changing config, on the display PC:

```powershell
.\Apply-Config.ps1 -TriggerSync
```

That updates the scheduled-task interval, writes `config.js`, and runs one sync.

## First-time setup on a display PC

1. Copy this folder to the machine, e.g. `C:\DisplayBoard`.
2. Set `sourcePath` via `settings.html` or by editing `config.json`.
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
| `config.json` | UNC path and timings |
| `settings.html` | Simple editor (handles `\` escaping for you) |
| `Apply-Config.ps1` | Apply config → `config.js` + scheduled task interval |
| `SlideshowSync.ps1` | robocopy + playlist |
| `Install-DisplayBoard.ps1` | One-time task registration |
| `slideshow.html` | Kiosk player |
| `config.js` / `playlist.js` | Generated — do not commit |

Use a normal file share, **not** an admin share (`C$`).

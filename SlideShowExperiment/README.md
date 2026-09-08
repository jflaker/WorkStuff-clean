# Display Board

A hands-off digital signage slideshow. Images live on a network share; the display PC
pulls them down on a schedule and updates itself with no one touching it.

## Why the previous version didn't update

The old `SlideshowPrep.ps1` had to be run **by hand**. The display reloaded itself
faithfully — every 15 minutes via a meta refresh, and again after 10 rotations — but it
re-read an `image_list.json` that nothing ever regenerated. Add or remove a picture on
the share and the board kept showing the old set, while looking like it was working
correctly. The missing piece was a scheduled task, not a code change.

## How it works now

```
\\SERVER\Share\images          (people add/remove pictures here)
        |
        |  DisplayBoard-Sync scheduled task, every 15 min
        |  robocopy /MIR  ->  .\images\
        |  regenerates playlist.js (only if the set actually changed)
        v
slideshow.html                 (Chrome kiosk, opened from file://)
        |
        +-- re-reads playlist.js every 5 min
        +-- preloads new images, swaps them in at a slide boundary
```

No web server. `playlist.js` is loaded with a plain `<script src>` tag, which works
from `file://` — `fetch()` does not, and that was the only reason the old version
needed `python -m http.server` on port 80.

## Setup on a new display PC

1. Copy this folder to the machine, e.g. `C:\DisplayBoard`.
2. Open PowerShell **as Administrator** in that folder:

   ```powershell
   .\Install-DisplayBoard.ps1 -SourcePath \\FILESERVER01\Slideshow\images
   ```

3. Kick off the first sync and check it worked:

   ```powershell
   Start-ScheduledTask -TaskName DisplayBoard-Sync
   Get-Content .\sync.log -Tail 20
   ```

4. Log off and back on, or just `Start-ScheduledTask -TaskName DisplayBoard-Kiosk`.

To change the interval, re-run the installer with `-IntervalMinutes 10`.
To remove everything: `.\Install-DisplayBoard.ps1 -Uninstall`.

## Trying it out before wiring up a share

`-SourcePath` takes any folder, local or UNC. To see it working without touching a
file server, point it at your own pictures:

```powershell
.\SlideshowSync.ps1 -SourcePath "$env:USERPROFILE\Pictures"
start .\slideshow.html
```

Add or delete a picture in that folder, re-run the sync, and the open page picks it up
within `POLL_MINUTES` without reloading.

> **`-LocalPath` is a disposable cache, not a place to keep anything.** robocopy `/MIR`
> deletes whatever is in the destination but not in the source. The script refuses to
> run if `-LocalPath` resolves to Pictures, Documents, Desktop, Videos, Music or your
> profile root, or if it matches the source — but keep the default (`.\images`) and the
> question never comes up.

## Behaviour worth knowing

| Situation | What happens |
|---|---|
| Share unreachable | Sync exits without touching local files. Board keeps showing the last good set. |
| Image added/removed on the share | Picked up within `IntervalMinutes`, then displayed within 5 minutes. No reload, no flash. |
| A corrupt or unreadable image | Skipped, logged to the browser console. The rotation continues. |
| No images at all | Board shows "Waiting for images…" and retries every 15s. |
| Nothing changed since last run | `playlist.js` is left alone, so the board doesn't rebuild for no reason. |

## Tuning

`slideshow.html`, top of the script block:

```js
var SLIDE_SECONDS = 8;    // how long each image is shown
var POLL_MINUTES  = 5;    // how often to check playlist.js
```

## Notes

- Use a normal file share, **not** an admin share (`C$`). Admin shares need local
  admin rights on the target and are a red flag in any audit.
- `playlist.js`, `sync.log` and the `images\` folder are generated at runtime. They are
  gitignored — don't commit them.
- Filenames are URL-escaped when written to the playlist, so spaces, `#`, `%` and
  non-ASCII names work.

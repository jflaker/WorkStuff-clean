# Secret Santa (standalone web)

A single-page Secret Santa drawer that runs entirely in the browser. No server, no accounts, no data leaves the machine.

## Open it

Double-click `index.html`, or from a terminal:

```bash
# optional local server (not required)
python -m http.server 8080
# then visit http://localhost:8080
```

Or open the raw file:

```text
file:///path/to/SecretSantaWeb/index.html
```

## Features

1. **Participants** — add by hand or import a CSV (`Name,Email`)
2. **Exclusions** — optional pairs who must not draw each other (e.g. partners)
3. **Draw** — random derangement (nobody gets themselves; exclusions respected)
4. **Private reveal** — each person selects their own name and only sees who they buy for
5. **Organizer list** — full assignment table, download as `.txt`, or copy

## Privacy

- Everything stays in the current browser tab
- Refreshing the page clears the draw
- Do not share the organizer “Full list” view on a shared screen if people are still revealing privately

## CSV format

Same shape as the PowerShell script’s example:

```csv
Name,Email
Alice,alice@example.com
Bob,bob@example.com
```

Email is optional in the web UI.

## Related

PowerShell version (email / file output): `Scripts/SecretSanta.ps1`

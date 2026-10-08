# Secret Santa

One HTML file. It runs in the browser. There is no server, no account, and nothing is uploaded.

Open it by double-clicking [index.html](index.html).

The PowerShell version, which can also write a file or send mail, is [Scripts/SecretSanta.ps1](../Scripts/SecretSanta.ps1).

## What it does

1. Add people by hand, or import a CSV (`Name,Email`). Email can be blank.
2. Optional exclusions, such as partners who must not draw each other.
3. Draw a random pairing. Nobody gets their own name.
4. **Private reveal.** Each person picks their name and only sees who they buy for.
5. **Full list** is for the organizer: on screen, copied, or saved as a text file.

## Privacy

- Data stays in this browser tab. Refreshing the page clears it.
- Do not leave the Full list on a shared screen while people are still revealing.

## CSV

Same columns as `Scripts/santas.example.csv`:

```csv
Name,Email
Alice,alice@example.com
Bob,bob@example.com
```

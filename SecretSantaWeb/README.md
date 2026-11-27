# Secret Santa

One HTML file. It runs in the browser. There is no server, no account, and nothing is uploaded.

Open it by double-clicking [index.html](index.html).

The PowerShell version, which can also write a file or send mail, is [Utilities/SecretSanta.ps1](../Utilities/SecretSanta.ps1). That script allows a blank Email unless you pass `-SendEmail`, which requires an email on every row. This page always allows a blank email, and it can record exclusion pairs (two people who must not draw each other). The PowerShell script has no exclusion list.

## What it does

1. Add people by hand, or import a CSV (`Name,Email`). Email can be blank.
2. Optional exclusions, such as partners who must not draw each other.
3. Draw a random pairing. Nobody gets their own name.
4. **Private reveal.** Each person picks their name and only sees who they buy for.
5. **Full list** is for the organizer: on screen, copied, or saved as a text file.

## Privacy

- Data stays in this browser tab. Refreshing the page clears it.
- Close the full list before handing the machine to someone who is about to reveal their name.

## CSV

Same columns as `Utilities/santas.example.csv`:

```csv
Name,Email
Alice,alice@example.com
Bob,bob@example.com
```
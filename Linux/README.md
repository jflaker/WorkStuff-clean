# Linux

One script. It clears a local Windows account password in an offline SAM hive with `chntpw`, then reboots the machine it is running on.

| Script | What it does |
|---|---|
| `clear-offline-windows-password.sh` | Runs `chntpw` three times against the hive (no piped answer, then menu choice `1`, then confirmation `y`), then `sudo reboot`. |

## Requirements

- Linux live session with `chntpw` installed
- Permission to `sudo`
- The Windows volume mounted so the SAM path is a file on disk
- Authority to administer that Windows install

## Usage

```bash
./clear-offline-windows-password.sh
./clear-offline-windows-password.sh SomeLocalUser /mnt/windows/Windows/System32/config/SAM
```

With no arguments the account is `Administrator` and the hive is `/Windows/System32/config/SAM` (a Kali live layout with the Windows disk at `/Windows`).

`chntpw` edits that local SAM file. Active Directory passwords are unchanged. `sudo reboot` reboots the live Linux session, which is the system you booted.
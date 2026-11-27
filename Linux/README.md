# Linux

One script. It blanks a local Windows account password in an offline SAM hive with `chntpw`. It does not reboot unless you pass `--reboot`.

| Script | What it does |
|---|---|
| `clear-offline-windows-password.sh` | Runs `chntpw` once. Sends `1` (clear the password), `q` (leave the user menu), then `y` (write the hive). Reboots only with `--reboot`. |

## Safety

- This blanks a **local** account password stored in the SAM file you name. The next sign-in for that account uses an empty password until someone sets a new one. Active Directory passwords are not changed. A Microsoft account password is not in this file either.
- Run it only on a Windows disk you are allowed to administer, from a Linux live session, with Windows shut down so it is not using the hive.
- A wrong path edits the wrong file. The default `/Windows/System32/config/SAM` matches a Kali layout with the Windows volume mounted at `/Windows`. Other live systems often use `/mnt/windows/Windows/System32/config/SAM`.
- `--reboot` reboots the computer you are booted into (this Linux session). It does not reboot a remote Windows PC. Without the flag the script leaves the machine running so you can unmount the volume and check the result.
- `chntpw` option `1` returns to its menu, and the write prompt defaults to **no**. The answers `1`, `q`, and `y` have to reach one process. Three separate `chntpw` runs cannot do that: the `1` and the `y` never meet, and the hive is not written.

## Requirements

- Linux live session with `chntpw` installed
- Permission to `sudo`
- The Windows volume mounted so the SAM path is a file on disk
- Authority to administer that Windows install

## Usage

```bash
./clear-offline-windows-password.sh
./clear-offline-windows-password.sh SomeLocalUser /mnt/windows/Windows/System32/config/SAM
./clear-offline-windows-password.sh --reboot
./clear-offline-windows-password.sh --reboot SomeLocalUser /mnt/windows/Windows/System32/config/SAM
```

With no username or hive path, the account is `Administrator` and the hive is `/Windows/System32/config/SAM`.

`chntpw` 1.00 exits 2 when it writes the hive and 0 when it writes nothing (unknown account, or the write was declined). This script treats any status other than 2 as a failure and does not reboot.

#!/bin/bash
# Blank one local Windows account password in an offline SAM hive.
#
# Usage:
#   ./clear-offline-windows-password.sh [--reboot] [username] [sam_path]
#
# Defaults are the values this script used when they were hardcoded:
#   username  Administrator
#   sam_path  /Windows/System32/config/SAM
#
# Run it from a Linux live session where the Windows volume is mounted so
# sam_path is an offline hive (on Kali, often /Windows/System32/config/SAM).
# chntpw edits that file. It does not reset an Active Directory password.
# The local account is left with an empty password.
#
# chntpw -u USER HIVE opens that user's edit menu and stays there after
# option 1 ("Clear (blank) user password"). q leaves the menu. The next
# prompt, "Write hive files? (y/n) [n]", saves only when the answer is y.
# One process has to see all three answers:
#
#   printf '1\nq\ny\n' | chntpw -u USER HIVE
#
# Three separate chntpw processes cannot do that job. The process that
# receives only "1" then hits end-of-file on the write prompt and keeps
# the default answer n, so the hive is not saved. A later process that
# receives only "y" reads "y" as a menu choice, not as the write answer.
#
# chntpw 1.00 returns 2 when writeHive() succeeds and 0 when it writes
# nothing (unknown user, or the write was declined).
#
# Reboot is opt-in. --reboot reboots the machine this script is running on
# (the live Linux session) after a successful write. It does not target a
# remote Windows PC. Without --reboot the script leaves the machine up.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: clear-offline-windows-password.sh [--reboot] [username] [sam_path]

Blank one local Windows account password in an offline SAM hive.

Defaults:
  username  Administrator
  sam_path  /Windows/System32/config/SAM

--reboot  After chntpw writes the hive, reboot the machine this script is
          running on (the live Linux session). Omit it to stay booted.

This edits a local SAM file. It does not change an Active Directory password.
The account is left with an empty password. Run it only against a Windows
disk you are allowed to administer, and only while Windows is not using
that hive.
EOF
}

reboot_after=0
positionals=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reboot)
      reboot_after=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      positionals+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if [[ ${#positionals[@]} -gt 2 ]]; then
  echo "Too many arguments." >&2
  usage >&2
  exit 2
fi

user_to_clear="${positionals[0]:-Administrator}"
sam_path="${positionals[1]:-/Windows/System32/config/SAM}"

if [[ ! -f "$sam_path" ]]; then
  echo "SAM hive not found: $sam_path" >&2
  echo "Mount the Windows volume and pass that hive's path. Not rebooting." >&2
  exit 1
fi

if ! command -v chntpw >/dev/null 2>&1; then
  echo "chntpw is not installed." >&2
  exit 1
fi

# 1 = clear password, q = leave the user menu, y = write the hive.
# Run that pipe inside the root shell. Piping the answers into `sudo chntpw`
# lets a password prompt, or sudo's use_pty, swallow them before chntpw
# sees them. chntpw returns 2 on a successful write, so capture the status
# instead of letting set -e abort before the check below.
status=0
sudo bash -c 'printf "1\nq\ny\n" | chntpw -u "$1" "$2"' \
  bash "$user_to_clear" "$sam_path" || status=$?

if [[ "$status" -ne 2 ]]; then
  echo "chntpw did not write the hive (exit ${status}). Password was not cleared. Not rebooting." >&2
  exit 1
fi

echo "Password cleared for ${user_to_clear} in ${sam_path}."
echo "That local account now has an empty password. Set a new one after Windows boots."

if [[ "$reboot_after" -eq 1 ]]; then
  echo "Rebooting this live session."
  sudo reboot
else
  echo "Not rebooting. Pass --reboot to reboot this live session after the hive is written."
fi

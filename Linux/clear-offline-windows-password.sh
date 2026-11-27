#!/bin/bash
# Clear one local Windows account password in an offline SAM hive, using chntpw.
#
# Usage:
#   ./clear-offline-windows-password.sh [username] [sam_path]
#
# Defaults are the values this script used when they were hardcoded:
#   username  Administrator
#   sam_path  /Windows/System32/config/SAM
#
# Run it from a Linux live session where the Windows volume is mounted so
# sam_path is an offline hive (Kali, with the Windows disk at /Windows).
# chntpw edits that file. It does not reset an Active Directory password.
#
# With no arguments the sequence is unchanged: chntpw runs three times
# (once with no piped answer, once with menu choice 1, once with y), then
# `sudo reboot` reboots the machine you are booted into.

user_to_clear="${1:-Administrator}"
sam_path="${2:-/Windows/System32/config/SAM}"

# Clear the password for a specific user
sudo chntpw -u "$user_to_clear" "$sam_path"

# Press 1 to clear the password
echo "1" | sudo chntpw -u "$user_to_clear" "$sam_path"

# Confirm the changes
echo "y" | sudo chntpw -u "$user_to_clear" "$sam_path"

# Reboots the live environment this script is running in.
sudo reboot

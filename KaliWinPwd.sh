#!/bin/bash

# Specify the SAM file path (adjust if needed)
sam_path="/Windows/System32/config/SAM"

# Clear the password for a specific user
user_to_clear="Administrator"

# Clear the password
sudo chntpw -u "$user_to_clear" "$sam_path"

# Press 1 to clear the password
echo "1" | sudo chntpw -u "$user_to_clear" "$sam_path"

# Confirm the changes
echo "y" | sudo chntpw -u "$user_to_clear" "$sam_path"

# Reboot the Windows system (optional)
sudo reboot

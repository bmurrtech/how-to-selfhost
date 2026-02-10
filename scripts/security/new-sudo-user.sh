#!/bin/bash

# Ensure the script is being run with sudo privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo privileges."
    exit 1
fi

# Set secure directory for script storage and logs
SECURE_DIR="/root/scripts"
LOG_FILE="/var/log/new_user_script.log"
SCRIPT_NAME=$(basename "$0")

# Create secure directory if it doesn't exist
if [[ ! -d $SECURE_DIR ]]; then
    echo "Creating secure directory for scripts at $SECURE_DIR..."
    mkdir -p $SECURE_DIR
    chmod 700 $SECURE_DIR
    chown root:root $SECURE_DIR
fi

# Function to log actions (excludes sensitive data like passwords)
function log_action {
    local message="$1"
    echo "$(date): $message" >> $LOG_FILE
}

# Function to prompt for user input with verification
function prompt_input {
    local var_name="$1"
    local prompt_text="$2"
    local user_input
    while true; do
        read -p "$prompt_text: " user_input
        echo
        echo "Is \"$user_input\" correct for $var_name? (y/n)"
        read -n 1 correct
        echo
        if [[ $correct == "y" || $correct == "Y" ]]; then
            eval "$var_name='$user_input'"
            break
        else
            echo "Please re-enter $var_name."
        fi
    done
}

# Prompt for the new username
prompt_input NEW_USER "Enter the username for the new user"

# Prompt for a secure password
while true; do
    echo "Enter the password for the new user: (input hidden)"
    read -s USER_PASSWORD
    echo

    # Check if password is empty
    if [[ -z "$USER_PASSWORD" ]]; then
        echo "Password cannot be empty. Please enter a valid password."
        continue
    fi

    echo "Confirm the password for $NEW_USER: (input hidden)"
    read -s CONFIRM_PASSWORD
    echo

    # Check if passwords match
    if [ "$USER_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
        echo "Passwords do not match. Please try again."
    else
        break
    fi
done

# Create the user with a secure password
echo "Creating a new user: $NEW_USER..."
useradd -m -s /bin/bash $NEW_USER
if [[ $? -eq 0 ]]; then
    log_action "User $NEW_USER created successfully."
else
    echo "Failed to create user $NEW_USER. Check logs for details."
    exit 1
fi

# Set the user's password (password not logged)
echo "$NEW_USER:$USER_PASSWORD" | chpasswd
if [[ $? -eq 0 ]]; then
    log_action "Password set for user $NEW_USER (password not logged)."
else
    echo "Failed to set password for user $NEW_USER. Check logs for details."
    exit 1
fi

# Add the user to the sudo group
echo "Adding $NEW_USER to the sudo group..."
usermod -aG sudo $NEW_USER
if [[ $? -eq 0 ]]; then
    log_action "User $NEW_USER added to sudo group."
else
    echo "Failed to add $NEW_USER to the sudo group. Check logs for details."
    exit 1
fi

# Disable password expiration
chage -I -1 -m 0 -M 99999 -E -1 $NEW_USER
log_action "Password expiration disabled for $NEW_USER."

# Copy the current user's SSH key to the new user
echo "Copying SSH keys to $NEW_USER..."
mkdir -p /home/$NEW_USER/.ssh
if [[ -f ~/.ssh/authorized_keys ]]; then
    cp ~/.ssh/authorized_keys /home/$NEW_USER/.ssh/authorized_keys
    chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
    chmod 700 /home/$NEW_USER/.ssh
    chmod 600 /home/$NEW_USER/.ssh/authorized_keys
    log_action "SSH keys copied to $NEW_USER."
else
    echo "No SSH authorized_keys found for the current user. Skipping SSH key setup."
    log_action "No SSH keys found for the current user. Skipped SSH key setup for $NEW_USER."
fi

# Update SSH configuration to allow the new user
echo "Updating SSH configuration to allow $NEW_USER..."
sed -i "/^#*AllowUsers /d" /etc/ssh/sshd_config
echo "AllowUsers $(whoami) $NEW_USER" >> /etc/ssh/sshd_config
systemctl restart sshd
if [[ $? -eq 0 ]]; then
    log_action "SSH configuration updated to allow $NEW_USER. SSHD restarted."
else
    echo "Failed to update SSH configuration or restart SSHD. Check logs for details."
    exit 1
fi

# Clear the script history to avoid leaking sensitive information
echo "Clearing command history..."
history -c
history -w
log_action "Command history cleared to prevent sensitive data leaks."

# Move the script to the secure directory to prevent abuse
if [[ ! -f "$SECURE_DIR/$SCRIPT_NAME" ]]; then
    echo "Relocating the script to $SECURE_DIR for secure storage..."
    mv "$0" "$SECURE_DIR/$SCRIPT_NAME"
    chmod 700 "$SECURE_DIR/$SCRIPT_NAME"
    chown root:root "$SECURE_DIR/$SCRIPT_NAME"
    log_action "Script $SCRIPT_NAME moved to $SECURE_DIR and secured."
else
    echo "Script is already located in $SECURE_DIR."
    log_action "Script already secured in $SECURE_DIR."
fi

echo "User $NEW_USER created and configured successfully. Actions logged to $LOG_FILE."

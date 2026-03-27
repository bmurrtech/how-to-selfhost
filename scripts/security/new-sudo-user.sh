#!/usr/bin/env bash
# Idempotent: re-run skips useradd/password when the user exists, preserves non-empty
# authorized_keys, and de-dupes pasted public key lines. Never reads or writes
# /root/.ssh (provider break-glass keys stay untouched).

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
    mkdir -p "$SECURE_DIR"
    chmod 700 "$SECURE_DIR"
    chown root:root "$SECURE_DIR"
fi

# Function to log actions (excludes sensitive data like passwords)
function log_action {
    local message="$1"
    echo "$(date): $message" >> "$LOG_FILE"
}

# Function to prompt for user input with verification
function prompt_input {
    local var_name="$1"
    local prompt_text="$2"
    local user_input
    while true; do
        read -rp "$prompt_text: " user_input
        echo
        echo "Is \"$user_input\" correct for $var_name? (y/n)"
        read -rn 1 correct
        echo
        if [[ $correct == "y" || $correct == "Y" ]]; then
            printf -v "$var_name" '%s' "$user_input"
            break
        else
            echo "Please re-enter $var_name."
        fi
    done
}

# Prompt for the new username
prompt_input NEW_USER "Enter the username for the new user"

USER_ALREADY_EXISTS=0
if id "$NEW_USER" &>/dev/null; then
    USER_ALREADY_EXISTS=1
    echo "User $NEW_USER already exists; skipping account creation and password change (idempotent rerun)."
    log_action "Idempotent rerun: user $NEW_USER already exists."
fi

if [[ "$USER_ALREADY_EXISTS" -eq 0 ]]; then
    # Prompt for a secure password
    while true; do
        echo "Enter the password for the new user: (input hidden)"
        read -rs USER_PASSWORD
        echo

        # Check if password is empty
        if [[ -z "$USER_PASSWORD" ]]; then
            echo "Password cannot be empty. Please enter a valid password."
            continue
        fi

        echo "Confirm the password for $NEW_USER: (input hidden)"
        read -rs CONFIRM_PASSWORD
        echo

        # Check if passwords match
        if [[ "$USER_PASSWORD" != "$CONFIRM_PASSWORD" ]]; then
            echo "Passwords do not match. Please try again."
        else
            break
        fi
    done

    unset CONFIRM_PASSWORD

    # Create the user with a secure password
    echo "Creating a new user: $NEW_USER..."
    if useradd -m -s /bin/bash "$NEW_USER"; then
        log_action "User $NEW_USER created successfully."
    else
        echo "Failed to create user $NEW_USER. Check logs for details."
        exit 1
    fi

    # Set the user's password (password not logged)
    if echo "$NEW_USER:$USER_PASSWORD" | chpasswd; then
        log_action "Password set for $NEW_USER (password not logged)."
    else
        echo "Failed to set password for $NEW_USER. Check logs for details."
        exit 1
    fi

    unset USER_PASSWORD
fi

# Add the user to the sudo group
echo "Adding $NEW_USER to the sudo group..."
if usermod -aG sudo "$NEW_USER"; then
    log_action "User $NEW_USER added to sudo group."
else
    echo "Failed to add $NEW_USER to the sudo group. Check logs for details."
    exit 1
fi

# Disable password expiration
chage -I -1 -m 0 -M 99999 -E -1 "$NEW_USER"
log_action "Password expiration disabled for $NEW_USER."

# authorized_keys: only from operator-pasted PUBLIC lines; never from /root/.ssh.
echo "Setting up SSH authorized_keys for $NEW_USER..."
echo "Log in as $NEW_USER with the private key matching what you paste (e.g. ssh -i ~/.ssh/your_key $NEW_USER@this-host). /root/.ssh is not modified."
mkdir -p "/home/$NEW_USER/.ssh"
AUTH_KEYS="/home/$NEW_USER/.ssh/authorized_keys"

if [[ -f "$AUTH_KEYS" && -s "$AUTH_KEYS" && "$USER_ALREADY_EXISTS" -eq 1 ]]; then
    echo "Keeping existing $AUTH_KEYS (idempotent rerun). You may add more keys below."
    log_action "Preserved existing authorized_keys for $NEW_USER."
elif [[ ! -f "$AUTH_KEYS" ]]; then
    : >"$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
    log_action "Created empty authorized_keys for $NEW_USER."
else
    chmod 600 "$AUTH_KEYS"
    chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
fi

echo "Paste PUBLIC key line(s) for $NEW_USER only (e.g. from Bitwarden). One key per line; press ENTER on an empty line when done:"
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line// }" ]] && break
    if grep -qFx "$line" "$AUTH_KEYS" 2>/dev/null; then
        echo "(Skipped: line already in authorized_keys.)"
        log_action "Skipped duplicate pasted public key line for $NEW_USER."
    else
        printf '%s\n' "$line" >>"$AUTH_KEYS"
        log_action "Appended pasted public key line for $NEW_USER."
    fi
done

if [[ ! -s "$AUTH_KEYS" ]]; then
    echo "Warning: authorized_keys is still empty. Add a key before switching to key-only SSH (e.g. vps-sec-harden.sh), or use password login until then."
    log_action "authorized_keys empty after paste step for $NEW_USER."
fi

chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
chmod 700 "/home/$NEW_USER/.ssh"
chmod 600 "$AUTH_KEYS"

read -rp "Restrict sshd with AllowUsers for an existing admin + $NEW_USER? (y/N): " RESTRICT_USERS
if [[ "${RESTRICT_USERS,,}" == "y" ]]; then
    if [[ -n "${SUDO_USER:-}" ]]; then
        ADMIN_USER="$SUDO_USER"
        echo "Using invoking sudo user as admin for AllowUsers: $ADMIN_USER"
    else
        read -rp "Enter the existing SSH/sudo username to allow alongside $NEW_USER (e.g. ubuntu): " ADMIN_USER
        ADMIN_USER="${ADMIN_USER// }"
    fi
    if [[ -z "$ADMIN_USER" ]]; then
        echo "No admin username supplied; skipping AllowUsers changes."
        log_action "AllowUsers requested but no admin user; skipped."
    else
        LINE="AllowUsers $ADMIN_USER $NEW_USER"
        sed -i '/^AllowUsers[[:space:]]/d' /etc/ssh/sshd_config
        echo "$LINE" >>/etc/ssh/sshd_config
        log_action "sshd_config AllowUsers set to $ADMIN_USER $NEW_USER (idempotent replace)."
    fi
else
    echo "Not changing AllowUsers (matches vps-sec-harden.sh default: no enforced user list)."
    log_action "AllowUsers not modified (operator chose no restriction)."
fi

echo "Restarting SSH service..."
if systemctl restart ssh || systemctl restart sshd; then
    log_action "SSH service restarted."
else
    echo "Failed to restart SSH. Check logs for details."
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
echo "Next: from your workstation, verify login (new terminal): ssh -i /path/to/private_key $NEW_USER@<this-host>"

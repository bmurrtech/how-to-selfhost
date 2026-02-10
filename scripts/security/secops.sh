# Determine the current user
USER_NAME=$(whoami)

# If the user is root, ask for the username
if [ "$USER_NAME" == "root" ]; then
    echo "You are running the script as root."
    echo "Please enter your username (e.g., george@<vmname>):"
    read USER_NAME
fi

# Check if the user is in the sudo group
if id -nG "$USER_NAME" | grep -qw "sudo"; then
    echo "$USER_NAME is in the sudo group."
else
    echo "Error: $USER_NAME is not in the sudo group."
    echo "Please add $USER_NAME to the sudo group using the following command:"
    echo "sudo usermod -aG sudo $USER_NAME"
    echo "Then re-run this script."
    exit 1
fi

# Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Disable IPv6
echo "Disabling IPv6..."
if ! grep -q "disable_ipv6" /etc/sysctl.conf; then
    sudo bash -c "cat << EOF >> /etc/sysctl.conf

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF"
    sudo sysctl -p
fi

# Harden SSH configuration
echo "Hardening SSH configuration..."
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sudo sed -i "/^#*AllowUsers /d" /etc/ssh/sshd_config
echo "AllowUsers $USER_NAME" | sudo tee -a /etc/ssh/sshd_config

# Restart SSH service
echo "Restarting SSH service..."
sudo systemctl restart sshd

# Secure shared memory
echo "Securing shared memory..."
if ! grep -q 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' /etc/fstab; then
    sudo bash -c "echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' >> /etc/fstab"
fi

# Install unattended-upgrades
echo "Installing unattended-upgrades for automatic security updates..."
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Summary of changes
echo "Security hardening configurations applied successfully!"

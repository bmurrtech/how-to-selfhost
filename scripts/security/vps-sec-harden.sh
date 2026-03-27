#!/usr/bin/env bash
# vps-sec-harden.sh — VPS SSH and system baseline hardening (formerly secops.sh in this repo).
# Idempotent: safe to re-run; skips duplicate sysctl/fstab/sshd template lines and
# avoids duplicate UFW rules where detectable. Unattended-upgrades reconfigure runs once.

# Determine the current user
USER_NAME=$(whoami)

# If the user is root, ask for the username
if [[ "$USER_NAME" == "root" ]]; then
    echo "You are running the script as root."
    echo "Please enter your username (e.g., george@<vmname>):"
    read -r USER_NAME
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

echo ""
echo "SSH public-key checklist (before this script disables password auth):"
echo "  - Copy your PUBLIC key only (e.g. id_ed25519.pub), never the private key."
echo "  - Keep this SSH session open while you change keys on the server."
echo "  - Append the key: nano ~/.ssh/authorized_keys (new line at bottom), or:"
echo "      echo 'ssh-ed25519 AAAA... your-label' >> ~/.ssh/authorized_keys"
echo "  - Then: chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
echo "  - Open a NEW terminal and test: ssh -i /path/to/private_key user@server"
echo "  - Continue here only after that login succeeds."
echo ""

# Harden SSH configuration
echo "Hardening SSH configuration..."
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
if ! grep -qF '# Optional: restrict later once stable' /etc/ssh/sshd_config; then
    sudo tee -a /etc/ssh/sshd_config >/dev/null <<'EOF'

# Optional: restrict later once stable
# AllowUsers youruser
EOF
fi

echo "Disabling RPC (port 111) if rpcbind is present..."
if systemctl list-unit-files rpcbind.service 2>/dev/null | grep -q '^rpcbind\.service'; then
    sudo systemctl stop rpcbind
    sudo systemctl disable rpcbind
    echo "rpcbind stopped and disabled. Verify nothing listens on 111: ss -tulnp | grep ':111 ' || true"
else
    echo "rpcbind.service not installed; skipping."
fi

echo "Configuring firewall (UFW)..."
sudo apt install ufw -y

sudo ufw default deny incoming
sudo ufw default allow outgoing

ufw_numbered() {
    sudo ufw status numbered 2>/dev/null || true
}

ufw_has_ssh_anywhere() {
    ufw_numbered | grep -qE '[[:space:]]22/tcp[[:space:]].*ALLOW[[:space:]]+IN[[:space:]]+Anywhere'
}

ufw_has_ssh_from() {
    local ip="$1"
    ufw_numbered | grep -F '22/tcp' | grep -F 'ALLOW IN' | grep -qF "$ip"
}

ufw_allow_tcp_once() {
    local port="$1"
    if ufw_numbered | grep -qE "[[:space:]]${port}/tcp[[:space:]].*ALLOW[[:space:]]+IN[[:space:]]+Anywhere"; then
        echo "UFW: ${port}/tcp (Anywhere) already allowed; skipping."
    else
        sudo ufw allow "${port}/tcp"
    fi
}

read -rp "Do you have a static IP for SSH access? (y/N): " STATIC_IP
if [[ "${STATIC_IP,,}" == "y" ]]; then
    read -rp "Enter your IPv4 address for SSH (must match your real source IP): " USER_IP
    USER_IP="${USER_IP// }"
    if [[ -z "$USER_IP" ]]; then
        echo "No IP entered; allowing SSH from any address (same as dynamic IP path)."
        if ufw_has_ssh_anywhere; then
            echo "UFW: SSH (22) from Anywhere already present; skipping."
        else
            sudo ufw allow 22/tcp
        fi
        echo "SSH allowed from any IP (rely on key-based auth)."
    else
        if ufw_has_ssh_from "$USER_IP"; then
            echo "UFW: SSH (22) from $USER_IP already allowed; skipping."
        else
            sudo ufw allow from "$USER_IP" to any port 22 proto tcp
        fi
        echo "SSH restricted to source $USER_IP for new connections (or already was)."
        echo "If that IP is wrong, you may be unable to SSH from other addresses; use your provider console to fix UFW or sshd."
    fi
else
    if ufw_has_ssh_anywhere; then
        echo "UFW: SSH (22) from Anywhere already allowed; skipping."
    else
        sudo ufw allow 22/tcp
    fi
    echo "SSH allowed from any IP (key-based auth enforced by sshd)."
fi

ufw_allow_tcp_once 80
ufw_allow_tcp_once 443

sudo ufw --force enable
echo "UFW status:"
sudo ufw status verbose

# Restart SSH service (unit name differs: Debian/Ubuntu use ssh, RHEL-like often sshd)
echo "Restarting SSH service..."
sudo systemctl restart ssh || sudo systemctl restart sshd

# Secure shared memory
echo "Securing shared memory..."
if ! grep -q 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' /etc/fstab; then
    sudo bash -c "echo 'tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0' >> /etc/fstab"
fi

# Install unattended-upgrades
echo "Installing unattended-upgrades for automatic security updates..."
sudo apt install unattended-upgrades -y
if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    echo "unattended-upgrades already configured (20auto-upgrades present); skipping dpkg-reconfigure."
else
    sudo dpkg-reconfigure --priority=low unattended-upgrades
fi

# Summary of changes
echo "Security hardening configurations applied successfully!"

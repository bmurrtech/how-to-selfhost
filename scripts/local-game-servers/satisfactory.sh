#!/bin/bash
# satisfactory.sh
# This script sets up a Satisfactory dedicated server environment (SteamCMD + systemd + UFW).
# Tuned for Proxmox + Ubuntu VM, LAN-first. One-and-done: game server + baseline security hardening.
# Requires root (sudo). Access: Proxmox console or SSH from LAN (password auth allowed on LAN).
#
# Bundled: UFW (LAN-only or VPS trusted IP), minimal SSH hardening (PermitRootLogin no), Fail2ban (RFC1918 whitelist), unattended-upgrades.
#
set -euo pipefail

INSTALL_DIR="/home/steam/sfserver"
LAN_CIDR_DEFAULT="192.168.1.0/24"

#############################################
# 0. Preliminary Prompts and CPU Note
#############################################

echo "================================================================"
echo "Satisfactory Dedicated Server — Proxmox + Ubuntu VM"
echo "================================================================"
echo ""
echo "NOTE: For optimal performance in Proxmox, set the VM CPU type from 'kvm64' to 'host' in the Proxmox web UI."
echo ""

# Prompt for experimental branch
echo "Do you want to use the experimental version of the Satisfactory server? (This may provide missing files)"
read -p "Enter y for yes or n for no [n]: " use_experimental_choice
if [[ "$use_experimental_choice" =~ ^[Yy]$ ]]; then
    USE_EXPERIMENTAL=true
    BETA_FLAG="-beta experimental"
    echo "Experimental branch selected."
else
    USE_EXPERIMENTAL=false
    BETA_FLAG=""
    echo "Stable branch selected."
fi
echo ""

#############################################
# 1. Check for Root Privileges
#############################################

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo or as the root user."
  echo "Usage: sudo ./$0"
  exit 1
fi

echo "---------------------------------------------"
echo "Starting Satisfactory server setup..."
echo "---------------------------------------------"

#############################################
# 2. Repository and Package Setup
#############################################

echo "Adding the 'multiverse' repository..."
add-apt-repository multiverse -y

echo "Installing software-properties-common..."
apt install software-properties-common -y

echo "Adding i386 architecture support..."
dpkg --add-architecture i386

echo "Updating package lists and upgrading installed packages..."
apt update && apt -y upgrade

echo "Installing lib32gcc-s1..."
apt install lib32gcc-s1 -y

#############################################
# 3. Firewall Configuration
#############################################

echo ""
echo "Select your firewall scenario:"
echo "1) Selfhosted LAN Party (allow incoming from local network only — game port 7777; optional SSH from LAN)"
echo "2) VPS-Hosted Server with Trusted IP Access (SSH and game port from your trusted public IP + whitelist file)"
read -p "Enter 1 or 2: " firewall_choice

echo ""
echo "UFW will be reset and reconfigured. Existing UFW rules will be removed."
read -p "Continue with UFW reset? [Y/n]: " ufw_confirm
if [[ "${ufw_confirm:-y}" =~ ^[Nn] ]]; then
  echo "Skipping firewall configuration."
else
  echo "Resetting UFW and setting default policies..."
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  if [ "$firewall_choice" == "1" ]; then
    read -p "LAN CIDR to allow (e.g. 192.168.1.0/24) [$LAN_CIDR_DEFAULT]: " LAN_CIDR
    LAN_CIDR="${LAN_CIDR:-$LAN_CIDR_DEFAULT}"
    echo "Configuring UFW for Selfhosted LAN Party..."
    ufw allow from "$LAN_CIDR" to any port 7777 proto tcp
    ufw allow from "$LAN_CIDR" to any port 7777 proto udp
    read -p "Allow SSH (22/tcp) from LAN for management? [Y/n]: " allow_ssh
    if [[ ! "${allow_ssh:-y}" =~ ^[Nn] ]]; then
      ufw allow from "$LAN_CIDR" to any port 22 proto tcp
      echo "SSH (22) allowed from $LAN_CIDR."
    fi
    echo "UFW rules set: Game port 7777 (and optionally SSH) from $LAN_CIDR only."
  elif [ "$firewall_choice" == "2" ]; then
    echo "Configuring UFW for VPS-Hosted Server with Trusted IP Access..."
    read -p "Enter your trusted SSH IP (the public IP you use to access this server via SSH): " trusted_ssh_ip
    ufw allow from "$trusted_ssh_ip" to any port 22 proto tcp
    ufw allow from "$trusted_ssh_ip" to any port 7777 proto tcp
    ufw allow from "$trusted_ssh_ip" to any port 7777 proto udp

    WHITELIST_FILE="/etc/satisfactory/trusted_players_whitelist.txt"
    if [ ! -f "$WHITELIST_FILE" ]; then
        mkdir -p /etc/satisfactory
        cat > "$WHITELIST_FILE" <<'WEOF'
# Trusted Players Whitelist for Satisfactory Dedicated Server
# Add one IP address per line below for access to port 7777.
# After editing, run: sudo ufw reload
WEOF
        echo "Whitelist file created at $WHITELIST_FILE."
    fi
    while IFS= read -r ip; do
        [[ -z "$ip" || "$ip" == \#* ]] && continue
        ufw allow from "$ip" to any port 7777 proto tcp
        ufw allow from "$ip" to any port 7777 proto udp
    done < "$WHITELIST_FILE"
    echo "UFW rules set: SSH and game port 7777 from trusted IPs."
  else
    echo "Invalid option. No UFW rules added; UFW not enabled to avoid locking you out."
  fi

  if [ "$firewall_choice" == "1" ] || [ "$firewall_choice" == "2" ]; then
    yes | ufw enable
    echo "Current UFW status:"
    ufw status verbose
  fi
fi
echo ""

#############################################
# 4. Steam User Setup
#############################################

echo "Checking if the 'steam' user exists..."
if id "steam" &>/dev/null; then
  echo "User 'steam' already exists. Skipping creation."
else
  echo "Creating user 'steam' with home directory and bash shell..."
  useradd -m -s /bin/bash steam
fi

echo "Adding 'steam' to the sudo group..."
usermod -aG sudo steam

read -p "Set password for steam user? [Y/n] (n = skip; manage via sudo/Proxmox console): " set_pw
if [[ "${set_pw:-y}" =~ ^[Yy] ]]; then
  echo "Setting password for steam user (you'll be prompted)..."
  passwd steam
else
  echo "Skipping password. Steam user can be used via: sudo -u steam <command>"
  passwd -d steam 2>/dev/null || true
fi

#############################################
# 5. Install SteamCMD
#############################################

echo "Installing SteamCMD..."
apt-get install -y steamcmd

#############################################
# 6. Create Server Directory and Set Ownership
#############################################

echo "Creating installation directory $INSTALL_DIR and setting ownership..."
sudo -u steam mkdir -p "$INSTALL_DIR"
chown -R steam:steam "$INSTALL_DIR"

#############################################
# 7. Prepare SteamCMD Environment
#############################################

echo "Ensuring the /home/steam/.steam directories exist..."
sudo -u steam mkdir -p /home/steam/.steam/sdk64 /home/steam/.steam/root

echo "Creating a symbolic link for steamcmd in /home/steam/..."
sudo -u steam ln -sf /usr/games/steamcmd /home/steam/steamcmd

#############################################
# 8. Update Satisfactory Server Files Using SteamCMD
#############################################

echo "Updating Satisfactory Dedicated Server files using SteamCMD..."
sudo -u steam /home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update 1690800 $BETA_FLAG validate +quit

# Verify that the key project file exists (warning may be benign)
if [ ! -f "$INSTALL_DIR/FactoryGame/FactoryGame.uproject" ]; then
  echo "WARNING: FactoryGame.uproject not found in $INSTALL_DIR/FactoryGame."
  echo "This message is common with some dedicated server builds."
else
  echo "Satisfactory server files installed successfully."
fi

#############################################
# 9. Create the Systemd Service File
#############################################

SERVICE_FILE="/etc/systemd/system/satisfactory.service"
echo "Creating systemd service file at ${SERVICE_FILE}..."

cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
# ExecStartPre updates the server files on each start.
ExecStartPre=/home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update 1690800 $BETA_FLAG validate +quit
ExecStart=/bin/sh "$INSTALL_DIR/FactoryServer.sh"
User=steam
Group=steam
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err
Restart=on-failure
WorkingDirectory=$INSTALL_DIR
TimeoutSec=240

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon to recognize the new service..."
systemctl daemon-reload

echo "Enabling the Satisfactory server service to start on boot..."
systemctl enable satisfactory

echo "Starting the Satisfactory server service..."
systemctl start satisfactory

echo "------------------------------------------------------"
echo "Satisfactory server service status:"
systemctl status satisfactory.service --no-pager
echo "------------------------------------------------------"

#############################################
# 10. Minimal SSH Hardening (Proxmox-safe)
#############################################
echo ""
echo "Applying minimal SSH hardening (PermitRootLogin no; password auth kept for LAN)..."
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
  grep -q '^PermitRootLogin ' /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
  echo "SSH: root login disabled. Use a normal user + sudo; access via Proxmox console if needed."
else
  echo "sshd_config not found; skipping SSH hardening."
fi

#############################################
# 11. Fail2ban (RFC1918 + localhost whitelist)
#############################################
echo ""
echo "Installing and configuring Fail2ban (LAN/IPv4 private ranges whitelisted)..."
apt-get install -y fail2ban
BANACTION="nftables-multiport"
command -v nft >/dev/null 2>&1 || BANACTION="iptables-multiport"
mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.local <<F2BEOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
backend = systemd
banaction = $BANACTION
bantime = 1h
findtime = 10m
maxretry = 6
F2BEOF
cat > /etc/fail2ban/jail.d/sshd.local <<'F2BSSH'
[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 6
F2BSSH
systemctl enable --now fail2ban
sleep 1
fail2ban-client status 2>/dev/null || true
echo "If you are ever banned, use Proxmox console and run: fail2ban-client unban --all"

#############################################
# 12. Unattended-upgrades
#############################################
echo ""
echo "Enabling unattended-upgrades for security updates..."
apt-get install -y unattended-upgrades
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo "Unattended-upgrades enabled (periodic security updates)."

echo ""
echo "================================================================"
echo "Setup complete!"
echo "  Game server: satisfactory.service (running as steam)"
echo "  Logs: tail -f /var/log/satisfactory.log"
echo "  If locked out: use Proxmox VM console to log in."
echo "================================================================"

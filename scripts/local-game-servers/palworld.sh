#!/bin/bash
# palworld.sh — Interactive Palworld dedicated server setup (SteamCMD + systemd + UFW)
# Tuned for Proxmox + Ubuntu VM, LAN-first. One-and-done: game server + baseline security hardening.
# Requires root (sudo). Access: Proxmox console or SSH from LAN (password auth allowed on LAN).
#
# Bundled: UFW (LAN-only, optional LAN SSH), minimal SSH hardening (PermitRootLogin no), Fail2ban (RFC1918 whitelist), unattended-upgrades.
# Ports: UDP 8211, 27015, 27031-27036; TCP 27015, 27036 (and optionally 8211 TCP)

set -euo pipefail

PAL_APP_ID=2394010
INSTALL_DIR_DEFAULT="/home/steam/palserver"
LAN_CIDR_DEFAULT="192.168.1.0/24"
STEAMCMD_PATH="/usr/games/steamcmd"

#############################################
# 0. Preliminary Notes for Proxmox Users
#############################################

echo "================================================================"
echo "Palworld Dedicated Server Setup for Proxmox + Ubuntu VMs"
echo "================================================================"
echo ""
echo "IMPORTANT NOTES FOR PROXMOX USERS:"
echo "• This script assumes you're running Ubuntu in a Proxmox VM"
echo "• For optimal performance, change your VM's CPU type from 'kvm64' to 'host' in Proxmox web interface"
echo "• Allocate at least 4 CPU cores and 8GB RAM to your VM for smooth gameplay"
echo "• The script will automatically create a 'steam' user if it doesn't exist"
echo "• Server files will be installed to /home/steam/palserver by default"
echo ""
echo "Ports that will be opened (LAN-only by default):"
echo "• UDP: 8211 (game), 27015 (Steam), 27031-27036 (Steam)"
echo "• TCP: 27015, 27036 (Steam) - TCP 8211 optional"
echo ""

#############################################
# 1. Root Privilege Check
#############################################

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges for system configuration."
  echo "Please run with: sudo ./$0"
  echo ""
  echo "The script will:"
  echo "• Install system packages (steamcmd, libraries)"
  echo "• Configure firewall rules (UFW)"
  echo "• Create systemd services"
  echo "• Set up the steam user automatically"
  exit 1
fi

echo "---------------------------------------------"
echo "Starting Palworld dedicated server setup..."
echo "---------------------------------------------"

#############################################
# 2. Steam User Setup (Automatic)
#############################################

echo "Checking for 'steam' user (required for game server)..."

if id "steam" &>/dev/null; then
  echo "✓ User 'steam' already exists - proceeding with existing user"
else
  echo "✗ User 'steam' not found - creating automatically..."
  echo "  Creating steam user with home directory..."
  useradd -m -s /bin/bash steam

  read -p "Set password for steam user? [Y/n] (n = skip; manage via sudo/Proxmox console): " set_pw
  if [[ "${set_pw:-y}" =~ ^[Yy] ]]; then
    echo "  Setting password for steam user (you'll be prompted)..."
    passwd steam
  else
    echo "  Skipping password. Steam user can be used via: sudo -u steam <command>"
    passwd -d steam 2>/dev/null || true
  fi

  echo "  Adding steam user to sudo group for system management..."
  usermod -aG sudo steam

  echo "✓ Steam user created and configured successfully"
fi

echo "Using steam user: $(id steam -u) ($(id steam -g))"

#############################################
# 3. Installation Directory Setup
#############################################

echo ""
echo "Configuring installation directory..."
echo "Default location: $INSTALL_DIR_DEFAULT (recommended for steam user)"
echo "This is where Palworld server files will be downloaded and stored."

read -p "Install directory [$INSTALL_DIR_DEFAULT]: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}"

echo "Creating installation directory: $INSTALL_DIR"
sudo -u steam mkdir -p "$INSTALL_DIR"
chown -R steam:steam "$INSTALL_DIR"
echo "✓ Directory created and ownership set to steam:steam"

#############################################
# 4. System Package Installation
#############################################

echo ""
echo "Installing required system packages..."
echo "This may take a few minutes depending on your internet connection."

echo "• Adding multiverse repository for additional packages..."
add-apt-repository multiverse -y 2>/dev/null || echo "  (multiverse repository already configured)"

echo "• Installing software-properties-common..."
apt install -y software-properties-common

echo "• Adding i386 architecture support (required for SteamCMD)..."
dpkg --add-architecture i386 2>/dev/null || echo "  (i386 architecture already added)"

echo "• Updating package lists..."
apt update -y

echo "• Installing SteamCMD and required 32-bit libraries..."
apt install -y steamcmd lib32gcc-s1

echo "✓ System packages installed successfully"

#############################################
# 5. SteamCMD Environment Setup
#############################################

echo ""
echo "Setting up SteamCMD environment for steam user..."

echo "• Creating Steam configuration directories..."
sudo -u steam mkdir -p /home/steam/.steam/sdk64 /home/steam/.steam/root

echo "• Creating SteamCMD symlink for easy access..."
sudo -u steam ln -sf "$STEAMCMD_PATH" /home/steam/steamcmd

echo "✓ SteamCMD environment configured"

#############################################
# 6. Download Palworld Server Files
#############################################

echo ""
echo "Downloading Palworld dedicated server files..."
echo "This will download ~3-4GB of game files. Please be patient."
echo "Steam AppID: $PAL_APP_ID"

echo "Running SteamCMD to install/update Palworld server..."
if sudo -u steam /home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update $PAL_APP_ID validate +quit; then
  echo "✓ SteamCMD completed successfully"
else
  echo "✗ SteamCMD failed. This could be due to:"
  echo "  • Network connectivity issues"
  echo "  • Steam servers being busy"
  echo "  • Disk space (need ~5GB free)"
  echo "  Please check the output above and try again."
  exit 1
fi

# Verify installation
if [ -f "$INSTALL_DIR/PalServer.sh" ]; then
  echo "✓ Palworld server files installed successfully"
  echo "  Server executable found: $INSTALL_DIR/PalServer.sh"
else
  echo "✗ WARNING: PalServer.sh not found in $INSTALL_DIR"
  echo "  This might indicate an incomplete download."
  echo "  Check available disk space and try running the script again."
  exit 1
fi

#############################################
# 7. Generate Configuration Files (Optional)
#############################################

echo ""
echo "Checking for Palworld configuration files..."

CONFIG_DIR="$INSTALL_DIR/Pal/Saved/Config/LinuxServer"
if [ -d "$CONFIG_DIR" ]; then
  echo "✓ Configuration directory already exists: $CONFIG_DIR"
else
  echo "✗ Configuration directory not found"
  echo ""
  echo "To generate default configuration files, we need to run the server briefly."
  echo "This will create the config directory structure and default settings."
  echo ""
  read -p "Run server briefly to generate configs? (recommended) [Y/n]: " do_first_run

  if [[ "${do_first_run:-y}" =~ ^[Yy] ]]; then
    echo ""
    echo "Starting Palworld server briefly to generate configuration files..."
    echo "The server will start and you'll see initialization messages."
    echo "Press Ctrl+C when you see 'Server listening' or after ~60 seconds."
    echo "This is normal and expected - we're just generating the config files."
    echo ""

    # Run server briefly and capture the PID so we can show it's running
    (cd "$INSTALL_DIR" && sudo -u steam ./PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS) &
    SERVER_PID=$!

    echo "Server started with PID: $SERVER_PID"
    echo "Waiting 45 seconds for initialization (or press Ctrl+C to stop earlier)..."

    # Wait for either user interrupt or timeout
    trap "echo 'Stopping server...'; kill $SERVER_PID 2>/dev/null || true; wait $SERVER_PID 2>/dev/null || true" INT
    sleep 45
    trap - INT

    # Clean up the server process
    if kill -0 $SERVER_PID 2>/dev/null; then
      echo "Stopping server process..."
      kill $SERVER_PID 2>/dev/null || true
      wait $SERVER_PID 2>/dev/null || true
    fi

    echo "✓ Server stopped. Checking if config directory was created..."

    if [ -d "$CONFIG_DIR" ]; then
      echo "✓ Configuration directory created successfully: $CONFIG_DIR"
    else
      echo "⚠ Configuration directory still not found. You may need to run the server manually later."
    fi
  else
    echo "Skipping config generation. You can run the server manually later to create configs."
  fi
fi

#############################################
# 8. Server Configuration (PalWorldSettings.ini)
#############################################

echo ""
echo "Configuring Palworld server settings..."

if [ ! -d "$CONFIG_DIR" ]; then
  echo "⚠ Configuration directory not found. Skipping server settings configuration."
  echo "  Run the server first to generate config files, then re-run this script."
elif [ ! -f "$INSTALL_DIR/DefaultPalWorldSettings.ini" ]; then
  echo "⚠ Default settings template not found. Skipping configuration."
  echo "  This might be fixed in a future Palworld update."
else
  echo "✓ Found configuration directory and default settings template"

  # Copy default config if it doesn't exist
  if [ ! -f "$CONFIG_DIR/PalWorldSettings.ini" ]; then
    echo "• Copying default configuration file..."
    cp "$INSTALL_DIR/DefaultPalWorldSettings.ini" "$CONFIG_DIR/PalWorldSettings.ini"
    chown steam:steam "$CONFIG_DIR/PalWorldSettings.ini"
    echo "✓ Default configuration created"
  else
    echo "✓ Configuration file already exists"
  fi

  echo ""
  echo "Server configuration options:"
  echo "You can customize your server name, password, admin password, and player limits."
  echo "These settings control how your server appears in the game browser."

  read -p "Configure server settings now? [y/N]: " edit_name
  if [[ "${edit_name:-n}" =~ ^[Yy] ]]; then
    echo ""
    echo "Enter your server configuration:"
    read -p "Server name (how it appears in server list): " SERVER_NAME
    read -p "Server password (leave empty for public server): " SERVER_PW
    read -p "Admin password (required for server administration): " ADMIN_PW
    read -p "Maximum players [8]: " MAX_PLAYERS
    MAX_PLAYERS="${MAX_PLAYERS:-8}"

    echo ""
    echo "Updating configuration file..."
    echo "(Note: Passwords and sensitive info are not logged)"

    # Apply configuration changes with error handling
    CONFIG_FILE="$CONFIG_DIR/PalWorldSettings.ini"

    if [ -n "$SERVER_NAME" ]; then
      if sed -i "s/ServerName=\"[^\"]*\"/ServerName=\"$SERVER_NAME\"/" "$CONFIG_FILE" 2>/dev/null; then
        echo "✓ Server name updated"
      else
        echo "⚠ Could not update server name automatically"
      fi
    fi

    if [ -n "$SERVER_PW" ]; then
      if sed -i "s/ServerPassword=\"[^\"]*\"/ServerPassword=\"$SERVER_PW\"/" "$CONFIG_FILE" 2>/dev/null; then
        echo "✓ Server password updated"
      else
        echo "⚠ Could not update server password automatically"
      fi
    fi

    if [ -n "$ADMIN_PW" ]; then
      if sed -i "s/AdminPassword=\"[^\"]*\"/AdminPassword=\"$ADMIN_PW\"/" "$CONFIG_FILE" 2>/dev/null; then
        echo "✓ Admin password updated"
      else
        echo "⚠ Could not update admin password automatically"
      fi
    fi

    if sed -i "s/ServerPlayerMaxNum=[0-9]*/ServerPlayerMaxNum=$MAX_PLAYERS/" "$CONFIG_FILE" 2>/dev/null; then
      echo "✓ Max players set to $MAX_PLAYERS"
    else
      echo "⚠ Could not update max players automatically"
    fi

    echo ""
    echo "Configuration complete!"
    echo "If any settings weren't updated automatically, you can edit manually:"
    echo "  sudo nano $CONFIG_FILE"
    echo "(Remember to restart the server after manual changes)"
  else
    echo "Skipping server configuration. You can edit settings later in:"
    echo "  $CONFIG_DIR/PalWorldSettings.ini"
  fi
fi

#############################################
# 9. Systemd Service Configuration
#############################################

echo ""
echo "Creating systemd service for automatic server management..."

SERVICE_FILE="/etc/systemd/system/palworld.service"
echo "• Writing service file: $SERVICE_FILE"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Palworld Dedicated Server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Type=simple
User=steam
Group=steam
WorkingDirectory=$INSTALL_DIR
Environment="LD_LIBRARY_PATH=./Linux"

ExecStartPre=$STEAMCMD_PATH +login anonymous +force_install_dir "$INSTALL_DIR" +app_update $PAL_APP_ID validate +quit
ExecStart=$INSTALL_DIR/PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS

StandardOutput=append:/var/log/palworld.log
StandardError=append:/var/log/palworld.err
Restart=on-failure
TimeoutSec=240

[Install]
WantedBy=multi-user.target
EOF

# Handle different library directory names across Palworld versions
if [ -d "$INSTALL_DIR/linux64" ] && [ ! -d "$INSTALL_DIR/Linux" ]; then
  echo "• Adjusting library path for newer Palworld version..."
  sed -i 's|./Linux|./linux64|' "$SERVICE_FILE"
fi

echo "• Reloading systemd daemon..."
systemctl daemon-reload

echo "• Enabling palworld service to start automatically on boot..."
systemctl enable palworld.service
echo "  (Service will start automatically on boot; no manual start needed after reboot.)"

echo "• Starting palworld service..."
systemctl start palworld.service

echo "✓ Systemd service created, enabled, and started"
echo ""
echo "Service status:"
systemctl status palworld.service --no-pager || true
echo ""
echo "Service management commands:"
echo "  Start server:   sudo systemctl start palworld"
echo "  Stop server:    sudo systemctl stop palworld"
echo "  Check status:   sudo systemctl status palworld"
echo "  View logs:      sudo tail -f /var/log/palworld.log"

#############################################
# 10. Firewall Configuration (UFW)
#############################################

echo ""
echo "Configuring firewall for secure Palworld access..."

echo "Firewall options:"
echo "• LAN-only: Allow game traffic only from your local network (recommended for home servers)"
echo "• This prevents unauthorized access from the internet"
echo ""

read -p "Configure UFW firewall for Palworld? (recommended) [Y/n]: " do_ufw
if [[ "${do_ufw:-y}" =~ ^[Yy] ]]; then
  echo ""
  echo "UFW will be reset; existing rules will be removed."
  read -p "Continue with UFW reset? [Y/n]: " ufw_confirm
  if [[ "${ufw_confirm:-y}" =~ ^[Nn] ]]; then
    echo "Skipping UFW configuration."
  else
    echo "LAN Configuration:"
    echo "Enter your local network range (e.g., 192.168.1.0/24 for a typical home network)."
    read -p "LAN CIDR to allow [$LAN_CIDR_DEFAULT]: " LAN_CIDR
    LAN_CIDR="${LAN_CIDR:-$LAN_CIDR_DEFAULT}"

    echo "Resetting UFW and setting default policies..."
    ufw --force reset 2>/dev/null || true
    ufw default deny incoming
    ufw default allow outgoing

    echo "Opening Palworld game ports from $LAN_CIDR..."
    ufw allow from "$LAN_CIDR" to any port 8211 proto udp
    ufw allow from "$LAN_CIDR" to any port 8211 proto tcp
    ufw allow from "$LAN_CIDR" to any port 27015 proto udp
    ufw allow from "$LAN_CIDR" to any port 27015 proto tcp
    ufw allow from "$LAN_CIDR" to any port 27031:27036 proto udp
    ufw allow from "$LAN_CIDR" to any port 27036 proto tcp

    read -p "Allow SSH (22/tcp) from LAN for management? [Y/n]: " allow_ssh
    if [[ ! "${allow_ssh:-y}" =~ ^[Nn] ]]; then
      ufw allow from "$LAN_CIDR" to any port 22 proto tcp
      echo "SSH (22) allowed from $LAN_CIDR."
    fi

    echo "y" | ufw enable
    echo "UFW: game ports (and optionally SSH) from $LAN_CIDR only."
    ufw status | grep -E "(Status|8211|27015|2703[1-6]|22)" || true
  fi
else
  echo "Skipping firewall configuration."
  echo "WARNING: Configure your own firewall or router to avoid exposing the server."
fi

#############################################
# 11. Minimal SSH Hardening (Proxmox-safe)
#############################################
echo ""
echo "Applying minimal SSH hardening (PermitRootLogin no; password auth kept for LAN)..."
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
  grep -q '^PermitRootLogin ' /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
  echo "SSH: root login disabled. Use Proxmox console if you are locked out."
else
  echo "sshd_config not found; skipping SSH hardening."
fi

#############################################
# 12. Fail2ban (RFC1918 + localhost whitelist)
#############################################
echo ""
echo "Installing and configuring Fail2ban (LAN/private ranges whitelisted)..."
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
echo "If banned by mistake: use Proxmox console and run: fail2ban-client unban --all"

#############################################
# 13. Unattended-upgrades
#############################################
echo ""
echo "Enabling unattended-upgrades for security updates..."
apt-get install -y unattended-upgrades
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo "Unattended-upgrades enabled."

#############################################
# 14. Setup Complete - Next Steps
#############################################

echo ""
echo "================================================================"
echo "🎉 Palworld Dedicated Server Setup Complete!"
echo "================================================================"
echo ""
echo "Server Details:"
echo "• Install directory: $INSTALL_DIR"
echo "• Service name:      palworld.service"
echo "• Log files:         /var/log/palworld.log"
echo "• Error logs:        /var/log/palworld.err"
echo ""
echo "Management Commands:"
echo "• Start server:      sudo systemctl start palworld"
echo "• Stop server:       sudo systemctl stop palworld"
echo "• Check status:      sudo systemctl status palworld"
echo "• View live logs:    sudo tail -f /var/log/palworld.log"
echo "• Restart server:    sudo systemctl restart palworld"
echo ""
echo "Next Steps:"
echo "1. Server is starting; wait 2-5 minutes for full readiness (check logs for 'Server listening')"
echo "2. Check status: sudo systemctl status palworld"
echo "3. Monitor the logs for any issues: sudo tail -f /var/log/palworld.log"
echo "4. In Palworld, go to 'Join Multiplayer Game' → 'Join via IP'"
echo "5. Enter your Ubuntu VM's IP address (find with: ip addr show)"
echo ""
echo "Proxmox-specific Tips:"
echo "• Your VM's IP will be something like 192.168.1.xxx"
echo "• Make sure your VM's network is set to 'Bridged' mode in Proxmox"
echo "• Check Proxmox VM console if you can't connect"
echo ""
echo "Troubleshooting:"
echo "• If server won't start, check logs: sudo journalctl -u palworld -f"
echo "• Verify firewall: sudo ufw status"
echo "• If locked out: use Proxmox VM console to log in."
echo ""
echo "For remote access outside your LAN:"
echo "• Consider WireGuard, Tailscale, or playit.gg (see main README)"
echo "• Never expose game ports directly to the internet without VPN"
echo ""
echo "Configuration:"
echo "• Edit server settings: sudo nano $CONFIG_DIR/PalWorldSettings.ini"
echo "• After config changes: sudo systemctl restart palworld"
echo ""
echo "Enjoy your Palworld dedicated server! 🚀"
echo "================================================================"

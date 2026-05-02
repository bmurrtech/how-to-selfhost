#!/bin/bash
# satisfactory.sh
# Sets up a Satisfactory dedicated server (SteamCMD + systemd + UFW).
# Idempotent: safe to re-run. Use **Quick mode** when the service already exists to switch
# stable ↔ experimental without re-running the full firewall/apt/security wizard.
# Optional env: SATISFACTORY_SAVE_ARCHIVE_DIR, SATISFACTORY_SKIP_SAVE_BACKUP (same as update-sf.sh).
# Requires root (sudo). Access: Proxmox console or SSH from LAN.
#
# Bundled (full mode): UFW, minimal SSH hardening, Fail2ban, unattended-upgrades.
#
set -euo pipefail

INSTALL_DIR="/home/steam/sfserver"
LAN_CIDR_DEFAULT="192.168.1.0/24"
STEAM_USER="steam"
STEAM_HOME="/home/${STEAM_USER}"
SERVICE_FILE="/etc/systemd/system/satisfactory.service"
APP_ID="1690800"
SAVE_SG="${STEAM_HOME}/.config/Epic/FactoryGame/Saved/SaveGames"
BACKUP_ARCHIVE_DIR="${SATISFACTORY_SAVE_ARCHIVE_DIR:-${STEAM_HOME}/satisfactory-save-archives}"

#############################################
# 0. Root check (before prompts)
#############################################
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo or as the root user."
  echo "Usage: sudo ./$0"
  exit 1
fi

EXISTING=0
[[ -f "$SERVICE_FILE" ]] && EXISTING=1

#############################################
# Helpers: saves backup, version print
#############################################
backup_satisfactory_saves_or_skip() {
  [[ "${SATISFACTORY_SKIP_SAVE_BACKUP:-0}" == "1" ]] && { echo "Skipping SaveGames backup (SATISFACTORY_SKIP_SAVE_BACKUP=1)."; return 0; }
  mkdir -p "$BACKUP_ARCHIVE_DIR"
  chown "${STEAM_USER}:${STEAM_USER}" "$BACKUP_ARCHIVE_DIR" 2>/dev/null || true
  if [[ ! -d "$SAVE_SG" ]]; then
    echo "No SaveGames directory yet (${SAVE_SG}); nothing to archive."
    LAST_SAVE_BACKUP_PATH=""
    return 0
  fi
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local dest="${BACKUP_ARCHIVE_DIR}/SaveGames-${stamp}.bak"
  echo "Archiving SaveGames (copy + compressed archive) to ${BACKUP_ARCHIVE_DIR} ..."
  cp -a "$SAVE_SG" "$dest"
  chown -R "${STEAM_USER}:${STEAM_USER}" "$dest"
  tar -czf "${BACKUP_ARCHIVE_DIR}/SaveGames-${stamp}.tar.gz" -C "$(dirname "$SAVE_SG")" "$(basename "$SAVE_SG")"
  chown "${STEAM_USER}:${STEAM_USER}" "${BACKUP_ARCHIVE_DIR}/SaveGames-${stamp}.tar.gz"
  LAST_SAVE_BACKUP_PATH="$dest"
  export LAST_SAVE_BACKUP_PATH
  echo "Backup copy: ${dest}"
  echo "Backup tarball: ${BACKUP_ARCHIVE_DIR}/SaveGames-${stamp}.tar.gz"
}

restore_saves_if_needed_after_update() {
  [[ -z "${LAST_SAVE_BACKUP_PATH:-}" ]] && return 0
  local bak_sav=0
  [[ -d "${LAST_SAVE_BACKUP_PATH}/server" ]] && bak_sav=$(find "${LAST_SAVE_BACKUP_PATH}/server" -maxdepth 1 -name '*.sav' 2>/dev/null | wc -l)
  [[ "$bak_sav" -eq 0 ]] && return 0
  mkdir -p "$SAVE_SG"
  local n_after=0
  [[ -d "${SAVE_SG}/server" ]] && n_after=$(find "${SAVE_SG}/server" -maxdepth 1 -name '*.sav' 2>/dev/null | wc -l)
  if [[ "$n_after" -eq 0 ]]; then
    echo "WARN: no .sav files under ${SAVE_SG}/server after update; restoring from ${LAST_SAVE_BACKUP_PATH}"
    cp -a "${LAST_SAVE_BACKUP_PATH}/." "$SAVE_SG/"
    chown -R "${STEAM_USER}:${STEAM_USER}" "$SAVE_SG"
    echo "SaveGames restored from backup."
  fi
}

read_build_version_field() {
  local f="$1" key="$2"
  local line
  [[ -f "$f" ]] || { echo ""; return 0; }
  line="$(grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]+" "$f" 2>/dev/null | head -1 || true)"
  [[ -z "$line" ]] && { echo ""; return 0; }
  grep -oE '[0-9]+$' <<<"$line"
}

read_manifest_buildid() {
  local mf="${INSTALL_DIR}/steamapps/appmanifest_${APP_ID}.acf"
  local line
  [[ -f "$mf" ]] || { echo ""; return 0; }
  line="$(grep -m1 '"buildid"' "$mf" 2>/dev/null || true)"
  [[ -z "$line" ]] && { echo ""; return 0; }
  sed -E 's/.*"buildid"[[:space:]]+"([^"]*)".*/\1/' <<<"$line" | tr -d '\r'
}

print_installed_server_version() {
  local bid bv maj min pat cl
  bid="$(read_manifest_buildid || true)"
  bv="$(find "$INSTALL_DIR" -name 'Build.version' -print -quit 2>/dev/null || true)"
  maj=""; min=""; pat=""; cl=""
  if [[ -n "$bv" ]]; then
    maj="$(read_build_version_field "$bv" MajorVersion)"
    min="$(read_build_version_field "$bv" MinorVersion)"
    pat="$(read_build_version_field "$bv" PatchVersion)"
    cl="$(read_build_version_field "$bv" Changelist)"
  fi
  echo "----------------------------------------------------------------"
  echo "Installed Satisfactory dedicated server (summary)"
  if [[ -n "$maj" || -n "$cl" ]]; then
    echo "  Engine-ish: ${maj:-?}.${min:-?}.${pat:-?}  Changelist: ${cl:-?}"
  else
    echo "  Engine Build.version: (not found under ${INSTALL_DIR})"
  fi
  echo "  Steam depot buildid: ${bid:-unknown}  (compare to Steam client → Properties → betas / build)"
  echo "----------------------------------------------------------------"
}

stop_satisfactory_if_running() {
  if [[ -f "$SERVICE_FILE" ]] && systemctl is-active --quiet satisfactory 2>/dev/null; then
    echo "Stopping satisfactory before SteamCMD file update..."
    systemctl stop satisfactory
  fi
}

write_satisfactory_unit() {
  cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
ExecStartPre=/home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update ${APP_ID} $BETA_FLAG validate +quit
ExecStart=/bin/sh "$INSTALL_DIR/FactoryServer.sh"
User=${STEAM_USER}
Group=${STEAM_USER}
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err
Restart=on-failure
WorkingDirectory=$INSTALL_DIR
TimeoutSec=240

[Install]
WantedBy=multi-user.target
EOF
}

reload_and_restart_service() {
  systemctl daemon-reload
  systemctl enable satisfactory
  systemctl restart satisfactory || systemctl start satisfactory
}

run_steamcmd_install_update() {
  echo "Updating Satisfactory Dedicated Server files using SteamCMD..."
  sudo -u "${STEAM_USER}" /home/steam/steamcmd +force_install_dir "$INSTALL_DIR" +login anonymous +app_update "${APP_ID}" $BETA_FLAG validate +quit
  if [ ! -f "$INSTALL_DIR/FactoryGame/FactoryGame.uproject" ]; then
    echo "WARNING: FactoryGame.uproject not found in $INSTALL_DIR/FactoryGame (often OK on dedicated builds)."
  else
    echo "Satisfactory server files installed successfully."
  fi
  restore_saves_if_needed_after_update
  print_installed_server_version
}

ensure_steam_user_and_cmd() {
  echo "Checking if the '${STEAM_USER}' user exists..."
  if id "${STEAM_USER}" &>/dev/null; then
    echo "User '${STEAM_USER}' already exists."
  else
    echo "Creating user '${STEAM_USER}' with home directory and bash shell..."
    useradd -m -s /bin/bash "${STEAM_USER}"
  fi
  echo "Adding '${STEAM_USER}' to the sudo group..."
  usermod -aG sudo "${STEAM_USER}"
  read -p "Set password for ${STEAM_USER} user? [Y/n] (n = skip; manage via sudo/Proxmox console): " set_pw
  if [[ "${set_pw:-y}" =~ ^[Yy] ]]; then
    echo "Setting password for ${STEAM_USER} user (you'll be prompted)..."
    passwd "${STEAM_USER}"
  else
    echo "Skipping password. Use: sudo -u ${STEAM_USER} <command>"
    passwd -d "${STEAM_USER}" 2>/dev/null || true
  fi

  echo "Installing SteamCMD (if not already)..."
  apt-get install -y steamcmd

  echo "Creating installation directory $INSTALL_DIR and setting ownership..."
  sudo -u "${STEAM_USER}" mkdir -p "$INSTALL_DIR"
  chown -R "${STEAM_USER}:${STEAM_USER}" "$INSTALL_DIR"

  echo "Ensuring ${STEAM_HOME}/.steam directories exist..."
  sudo -u "${STEAM_USER}" mkdir -p "${STEAM_HOME}/.steam/sdk64" "${STEAM_HOME}/.steam/root"
  echo "Symlink steamcmd into ${STEAM_HOME}..."
  sudo -u "${STEAM_USER}" ln -sf /usr/games/steamcmd "${STEAM_HOME}/steamcmd"
}

#############################################
# 1. Banner & run mode
#############################################
echo "================================================================"
echo "Satisfactory Dedicated Server — Proxmox + Ubuntu VM"
echo "================================================================"
echo ""
echo "NOTE: For optimal performance in Proxmox, set the VM CPU type from 'kvm64' to 'host' in the Proxmox web UI."
echo ""

RUNMODE=2
if [[ "$EXISTING" -eq 1 ]]; then
  echo "Existing ${SERVICE_FILE} detected — you can refresh Steam branch/files only or run the full wizard."
  echo "  1) Quick — stable/experimental switch + SteamCMD + systemd (keeps firewall & security as-is)"
  echo "  2) Full — apt upgrade, firewall wizard, Steam install, systemd, SSH/Fail2ban/unattended-upgrades"
  read -p "Enter 1 or 2 [1]: " RUNMODE_CHOICE
  RUNMODE="${RUNMODE_CHOICE:-1}"
  if [[ "$RUNMODE" != "1" && "$RUNMODE" != "2" ]]; then
    echo "Invalid choice; defaulting to Quick (1)."
    RUNMODE=1
  fi
fi

#############################################
# 2. Experimental branch (always; drives systemd + SteamCMD)
#############################################
echo "Do you want the **experimental** Satisfactory server branch on Steam?"
echo "  n = public (stable) — matches default Steam client branch"
echo "  y = experimental — matches Steam client on 'experimental' beta"
read -p "Enter y for experimental or n for stable [n]: " use_experimental_choice
if [[ "$use_experimental_choice" =~ ^[Yy]$ ]]; then
  BETA_FLAG="-beta experimental"
  echo "Experimental branch selected."
else
  BETA_FLAG=""
  echo "Stable (public) branch selected."
fi
echo ""

echo "---------------------------------------------"
echo "Starting Satisfactory server setup (mode ${RUNMODE})..."
echo "---------------------------------------------"

#############################################
# 3. Quick path
#############################################
if [[ "$RUNMODE" == "1" ]]; then
  echo "[Quick] Ensuring multiverse + i386 + lib32gcc-s1 + steamcmd..."
  add-apt-repository multiverse -y 2>/dev/null || true
  dpkg --add-architecture i386 2>/dev/null || true
  apt-get update -qq
  apt-get install -y software-properties-common lib32gcc-s1 steamcmd

  ensure_steam_user_and_cmd
  stop_satisfactory_if_running
  backup_satisfactory_saves_or_skip
  run_steamcmd_install_update

  echo "Writing systemd unit to ${SERVICE_FILE}..."
  write_satisfactory_unit
  reload_and_restart_service

  echo "------------------------------------------------------"
  systemctl status satisfactory.service --no-pager || true
  echo "------------------------------------------------------"
  echo "Quick reconfigure complete (firewall / Fail2ban untouched)."
  exit 0
fi

#############################################
# 4. Full setup (first install or explicit mode 2)
#############################################

echo "Adding the 'multiverse' repository..."
add-apt-repository multiverse -y

echo "Installing software-properties-common..."
apt install software-properties-common -y

echo "Adding i386 architecture support..."
dpkg --add-architecture i386

echo "Updating package lists..."
apt update
if [[ "$EXISTING" -eq 1 ]]; then
  read -p "Run full 'apt upgrade' (can take a long time)? [y/N]: " do_upg
  if [[ "${do_upg:-}" =~ ^[Yy]$ ]]; then
    apt -y upgrade
  else
    echo "Skipping apt upgrade."
  fi
else
  echo "Upgrading installed packages (first-time full setup)..."
  apt -y upgrade
fi

echo "Installing lib32gcc-s1..."
apt install lib32gcc-s1 -y

#############################################
# 5. Firewall
#############################################
SKIP_FIREWALL=0
if [[ "$EXISTING" -eq 1 ]]; then
  read -p "Reconfigure UFW from scratch (WARNING: resets all UFW rules)? [y/N]: " ufw_re
  if [[ ! "${ufw_re:-}" =~ ^[Yy]$ ]]; then
    SKIP_FIREWALL=1
    echo "Leaving existing UFW configuration unchanged."
  fi
fi

if [[ "$SKIP_FIREWALL" -eq 0 ]]; then
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
fi
echo ""

ensure_steam_user_and_cmd
stop_satisfactory_if_running
backup_satisfactory_saves_or_skip
run_steamcmd_install_update

echo "Creating systemd service file at ${SERVICE_FILE}..."
write_satisfactory_unit

echo "Reloading systemd daemon..."
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
# 6. Minimal SSH Hardening
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
# 7. Fail2ban
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
# 8. Unattended-upgrades
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
echo "  Game server: satisfactory.service (running as ${STEAM_USER})"
echo "  Logs: tail -f /var/log/satisfactory.log"
echo "  Save backups: ${BACKUP_ARCHIVE_DIR}"
echo "  If locked out: use Proxmox VM console to log in."
echo "================================================================"

# How-to SteamCMD Game Servers

SteamCMD is Valve's command-line tool for installing and updating dedicated game servers. This guide teaches the core principles of SteamCMD and points you to **ready-made installer scripts** for the fastest path to a working server.

---

## Scope of This Guide

**Primary scope: local LAN hosting.** This guide and the referenced scripts are designed for game servers running on your **home network** — e.g. a Proxmox VM, a machine on your LAN, or similar. Access is via LAN only; no ports are exposed to the public internet.

**VPS / cloud servers:** Out of scope or **use at your own risk**. Cloud VPS hosting introduces additional risks:
- **Bots and scanners** routinely probe new IPs; exposed game ports and SSH (22) attract automated attacks
- **Port 22** (SSH) is a high-value target; once discovered, attackers may attempt brute force, credential stuffing, or exploit unpatched software
- Misconfiguration can lead to compromise, lateral movement, and data loss

Secure methods for self-hosted cloud game servers *are* possible — notably **WireGuard**, **playit.gg**, or **Tailscale** for gated access to trusted players only, without exposing ports publicly. This guide does not cover that configuration in depth.

---

## Security Advisory: Public Access to Home Networks

> **We do not recommend opening ports on your home firewall to give the public direct access to a game server on the same VLAN as your home network.**

**Why?** A misconfiguration, unpatched vulnerability, or unforeseen exploit could allow lateral movement. An attacker could gain access to your home computers, NAS, files, and entire network — with data exfiltration, ransomware, or dark-web sale of your data as possible outcomes. **Only attempt public-facing game hosting from home at your own digital peril.**

| Approach | Recommendation |
|----------|----------------|
| **Public game server** | Prefer a **cloud VPS** — limits blast radius, isolates risk from your home network, and provides better data-loss prevention. |
| **Advanced users (VLAN isolation)** | If you insist on hosting at home, see [how-to pfSense](how-to_pfsense.md) to create a **dedicated VLAN for game servers**, reducing lateral movement. Nothing is 100% secure; you assume the risk. |
| **Remote friends only** | Use **WireGuard**, **Tailscale**, or **playit.gg** so only trusted users connect — no public port exposure. |

---

## Table of Contents

- [Scope of This Guide](#scope-of-this-guide)
- [Preferred: Ready-Made Installer Scripts](#preferred-ready-made-installer-scripts)
- [Server Hardening Best Practices](#server-hardening-best-practices)
- [SteamCMD Principles](#steamcmd-principles)
- [Manual Setup: Satisfactory](#manual-setup-satisfactory)
- [Manual Setup: ARK Survival Evolved](#manual-setup-ark-survival-evolved)

---

## Preferred: Ready-Made Installer Scripts

**Before** diving into manual SteamCMD setup, check if a pre-built script exists for your game. These scripts automate SteamCMD, systemd, UFW, and security hardening — same steps, zero manual repetition.

### Local Game Servers (home LAN / Proxmox VM)

| Game | Scripts | README |
|------|---------|--------|
| **Satisfactory** | `satisfactory.sh` | [satisfactory/README.md](../scripts/local-game-servers/satisfactory/README.md) |
| **Palworld** | `palworld.sh`, `config-palworld.sh`, `import-palworld-save.sh`, `export-palworld-save.sh` | [palworld/README.md](../scripts/local-game-servers/palworld/README.md) |

**Download example (Satisfactory):**
```bash
cd ~
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/satisfactory/satisfactory.sh -O satisfactory.sh
chmod +x satisfactory.sh
sudo ./satisfactory.sh
```

Each game folder has wget URLs and run instructions in its README. See the [local-game-servers overview](../scripts/local-game-servers/README.md) for prerequisites, firewall model, and troubleshooting.

### VPS Game Servers

| Target | Status |
|--------|--------|
| **VPS-oriented scripts** | **Roadmap (TBD)** — same SteamCMD logic, tuned for cloud VPS with optional public-facing ports. |

If your game isn't covered yet, use the manual sections below or adapt an existing script for your needs.

---

## Server Hardening Best Practices

The [local-game-servers scripts](../scripts/local-game-servers/README.md) (e.g. `palworld.sh`, `satisfactory.sh`) apply these practices by default. For manual setups, consider implementing them.

### 1. Run as non-root (steam user)

Always run game servers under a dedicated `steam` user — never as root. Limits damage if the server process or a game exploit is compromised.

```bash
sudo useradd -m -s /bin/bash steam
sudo passwd steam
```

### 2. UFW: LAN-only firewall

Allow game and Steam ports **only from your LAN** (e.g. `192.168.1.0/24`). Do **not** open these ports to `any` or `0.0.0.0/0` unless you understand the risks (see [Security Advisory](#security-advisory-public-access-to-home-networks)).

```bash
# Example: Palworld — LAN CIDR only
sudo ufw allow from 192.168.1.0/24 to any port 8211 proto udp
sudo ufw allow from 192.168.1.0/24 to any port 27015 proto udp
# Optionally SSH from LAN only
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
sudo ufw default deny incoming
sudo ufw enable
```

### 3. SSH hardening

Disable root login; use Proxmox console or another out-of-band method if you lock yourself out.

```bash
# In /etc/ssh/sshd_config
PermitRootLogin no
```

### 4. Fail2ban with RFC1918 whitelist

Protect SSH from brute force while whitelisting private IPs (so LAN access is not banned).

```bash
# /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
bantime = 1h
findtime = 10m
maxretry = 6
```

### 5. Unattended-upgrades

Enable automatic security updates.

```bash
sudo apt install unattended-upgrades
echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
```

### Summary

| Practice | Purpose |
|----------|---------|
| Non-root steam user | Limits privilege escalation |
| UFW LAN-only | No public exposure of game/SSH ports |
| SSH hardening | Reduces attack surface |
| Fail2ban + whitelist | Blocks brute force; preserves LAN access |
| Unattended-upgrades | Keeps packages patched |

### Optional: security scripts

If you prefer to set up security yourself and **do not** use the [game server deploy scripts](../scripts/local-game-servers/README.md) (which include hardening by default), you can use the [scripts/security](../scripts/security/README.md) scripts optionally.
---

## SteamCMD Principles

SteamCMD installs game server files from Steam's content delivery network. You typically:

1. **Install SteamCMD** — via `apt` on Debian/Ubuntu
2. **Create a steam user** — run servers as non-root
3. **Use core commands:**
   - `force_install_dir <path>` — where to put the server files
   - `login anonymous` — no Steam account required for most dedicated servers
   - `app_update <appid> validate` — download/update the server
   - `quit` — exit SteamCMD

### Reference: Steam developer docs

- [SteamCMD wiki](https://developer.valvesoftware.com/wiki/SteamCMD)

### Typical one-liner pattern

```bash
steamcmd +force_install_dir /home/steam/myserver +login anonymous +app_update <APPID> validate +quit
```

Replace `<APPID>` with the game's Steam app ID (e.g. Satisfactory: 1690800, ARK: 376030, Palworld: 2394010).

### Common SteamCMD App IDs

Below are popular multiplayer games and their SteamCMD app IDs. This list is not exhaustive—check [SteamDB](https://steamdb.info/apps/) or official documentation for more.

| Game                              | App ID   |
|------------------------------------|----------|
| Satisfactory                      | 1690800  |
| ARK: Survival Evolved              | 376030   |
| Palworld                          | 2394010  |
| Valheim                           | 896660   |
| Rust                              | 258550   |
| Counter-Strike: Global Offensive   | 740      |
| Team Fortress 2                   | 232250   |
| 7 Days to Die                     | 294420   |
| Terraria                          | 105600   |
| Project Zomboid                   | 380870   |
| Conan Exiles                      | 443030   |
| DayZ                              | 223350   |
| Unturned                          | 1110390  |
| Don't Starve Together             | 343050   |
| Mordhau                           | 629800   |
| Left 4 Dead 2                     | 222860   |
| Garry's Mod                       | 4020     |
| Barotrauma                        | 1026340  |
| No More Room in Hell               | 317670   |
| Insurgency: Sandstorm              | 581330   |
| Space Engineers                   | 298740   |
| Killing Floor 2                   | 232130   |
| Avorion                            | 565060   |
| Eco                               | 739590   |
| SCP: Secret Laboratory            | 996560   |
| Starbound                         | 211820   |

**Tip:** For more or to verify, see [Steam Game Server Lists](https://developer.valvesoftware.com/wiki/Dedicated_Servers_List), [SteamDB AppID search](https://steamdb.info/apps/), or the game's docs.

---

## Manual Setup: Satisfactory

Use this section when you prefer a manual install or the Satisfactory script doesn't fit your setup.

### Prerequisites

- Ubuntu server VM (e.g. [cloud-init 20.04 on Proxmox](how-to_ultimate_proxmox.md))
- **12–16 GB RAM** for the VM
- Root or sudo access

### Steps

1. **Install dependencies**
   ```bash
   sudo add-apt-repository multiverse
   sudo apt install software-properties-common
   sudo dpkg --add-architecture i386
   sudo apt update && apt -y upgrade
   sudo apt install lib32gcc1
   ```

2. **Firewall**
   ```bash
   # For LAN-only (recommended): restrict to your LAN CIDR, e.g. 192.168.1.0/24
   sudo ufw allow from 192.168.1.0/24 to any port 15777
   sudo ufw allow from 192.168.1.0/24 to any port 22
   sudo ufw default deny incoming
   sudo ufw enable
   sudo ufw status
   ```
   > Avoid opening these ports to `any` on a home network. See [Server Hardening Best Practices](#server-hardening-best-practices).

3. **Create steam user**
   ```bash
   sudo useradd -m -s /bin/bash steam
   sudo passwd steam
   sudo usermod -aG sudo steam
   su - steam
   ```

4. **Install SteamCMD**
   ```bash
   sudo apt-get install steamcmd
   ```

5. **Install server**
   ```bash
   steamcmd +force_install_dir /home/steam/sfserver/ +login anonymous +app_update 1690800 validate +quit
   ```
   > For experimental branch: `+app_update 1690800 -beta experimental +quit`

6. **Start server**
   ```bash
   cd /home/steam/sfserver
   ./FactoryServer.sh
   ```
   Or use [systemd](#automatically-start-satisfactory-server) for auto-start on boot.

### Automatically Start Satisfactory Server

Create a systemd service. See the [Satisfactory Wiki service template](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service). Example:

```ini
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
ExecStartPre=/home/steam/steamcmd +force_install_dir "/home/steam/sfserver" +login anonymous +app_update 1690800 validate +quit
ExecStart=/home/steam/sfserver/FactoryServer.sh
User=steam
Group=steam
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err
Restart=on-failure
WorkingDirectory=/home/steam/sfserver
TimeoutSec=240

[Install]
WantedBy=multi-user.target
```

Save as `/etc/systemd/system/satisfactory.service`, then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable satisfactory
sudo systemctl start satisfactory
```

### Joining the server

In-game: **Server Manager** → enter the server's local IP and port **15777** → configure and create a session.

---

## Manual Setup: ARK Survival Evolved

Use this section when you prefer a manual ARK install.

### Prerequisites

- Ubuntu server VM (e.g. [cloud-init 20.04 on Proxmox](how-to_ultimate_proxmox.md))
- **12–16 GB RAM**
- Root or sudo access

### Steps

1. **System limits (optional but recommended)**
   ```bash
   echo "fs.file-max=100000" >> /etc/sysctl.conf
   sysctl -p /etc/sysctl.conf
   echo "*soft nofile 100000" >> /etc/security/limits.conf
   echo "*hard nofile 100000" >> /etc/security/limits.conf
   ulimit -n 100000
   ```

2. **Dependencies and steam user** — same as [Satisfactory](#manual-setup-satisfactory) (multiverse, lib32gcc1, steam user, steamcmd)

3. **Firewall**
   ```bash
   # For LAN-only (recommended): restrict to your LAN CIDR, e.g. 192.168.1.0/24
   sudo ufw allow from 192.168.1.0/24 to any port 22
   sudo ufw allow from 192.168.1.0/24 to any port 7777
   sudo ufw allow from 192.168.1.0/24 to any port 7778
   sudo ufw allow from 192.168.1.0/24 to any port 27015
   sudo ufw default deny incoming
   sudo ufw enable
   ```
   Port-forward **7777**, **7778**, and **27015** (TCP and UDP) on your router only if you need off-LAN access — and prefer VPN/tunnel (WireGuard, Tailscale, playit.gg) over direct exposure. See [Security Advisory](#security-advisory-public-access-to-home-networks).

4. **Install ARK server**
   ```bash
   steamcmd +login anonymous +force_install_dir /home/steam/arkserver +app_update 376030 +quit
   ```

5. **Systemd service** — create `/etc/systemd/system/ark.service`:

   ```ini
   [Unit]
   Description=ARK Survival Evolved
   Wants=network-online.target
   After=syslog.target network.target nss-lookup.target network-online.target

   [Service]
   Type=simple
   Restart=on-failure
   RestartSec=5
   User=steam
   Group=steam
   ExecStartPre=/home/steam/steamcmd +force_install_dir /home/steam/arkserver +login anonymous +app_update 376030 +quit
   ExecStart=/home/steam/arkserver/ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen?SessionName=ArkServer -server -log -NoBattlEye
   WorkingDirectory=/home/steam/arkserver/ShooterGame/Binaries/Linux
   LimitNOFILE=100000

   [Install]
   WantedBy=multi-user.target
   ```

   > `-NoBattlEye` enables Epic Games clients to connect.

6. **Enable and start**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable ark
   sudo systemctl start ark
   ```

### Joining the ARK server

| Client | Method |
|--------|--------|
| **Epic Games** | In-game: `TAB` → Console → `open [SERVER_IP]:7777` |
| **Steam** | Steam client → View > Servers > Favorites → Add `[SERVER_IP]:27015` → Join from game |

---

## References

- [SteamCMD wiki](https://developer.valvesoftware.com/wiki/SteamCMD)
- [LinuxGSM configuration (systemd concepts)](https://docs.linuxgsm.com/configuration/running-on-boot)
- [Satisfactory dedicated servers (Fandom)](https://satisfactory.fandom.com/wiki/Dedicated_servers)
- [ARK dedicated server setup (Fandom)](https://ark.fandom.com/wiki/Dedicated_server_setup)

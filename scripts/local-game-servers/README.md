# Local game servers

Scripts to set up SteamCMD-based dedicated game servers (Satisfactory, Palworld, etc.) on Linux, with optional UFW rules for **local home network** (e.g. Proxmox VM, LAN-only) or VPS-style access.

## Why this repo exists

- **VPS-agnostic** — Same scripts work on bare metal, Proxmox VM, or cloud VPS.
- **Local-first** — Favors self-hosting at home (LAN-only firewall) with optional cloud.
- **Security-minded** — Hardens SSH, avoids open ports; favors tools like Tailscale where applicable.
- **Wizard-style** — Interactive prompts; no need to edit scripts for common cases.
- **Modular** — One folder per game; game-specific scripts and install instructions live in each game’s folder.
- **Central recipe** — Single place for dedicated game server automation (SteamCMD + systemd + UFW).

Other repos often focus on: per-game SteamCMD snippets (no hardening), Docker images (no SSH/UFW automation), or UI panels (dashboards, not CLI automation). This repo aims at **recipe-driven CLI setup with secure defaults**, without requiring a full panel.

## Why use these scripts

- **Repeatable installs**: SteamCMD + systemd + UFW in one run; same steps on any Debian/Ubuntu host.
- **Safe defaults**: LAN-only firewall option so you don’t expose ports to the internet; optional steam user creation.

> **AI Security Review:** For added peace of mind, you can review any script in this folder using an AI assistant together with [AGENTS.md](../../AGENTS.md), which provides a security-focused prompt and methodology for critical script analysis before running them.

## Access model (Proxmox + LAN)

These scripts assume a **LAN-first** setup and do **not** require opening any ports to the public internet.

- **VM networking**: Ubuntu in a Proxmox VM with a bridged NIC and DHCP (or static IP on the same LAN). See the [Proxmox guide](../../guides/how-to_ultimate_proxmox.md) for cloud-init templates and VM creation.
- **Admin access**: SSH from the LAN is supported with **password authentication enabled** (LAN-trusted model). If firewall or SSH changes ever lock you out, use the **Proxmox web UI → VM → Console** to log in and fix (no public ports needed).
- **Security hardening**: Each script applies baseline hardening (UFW LAN-only, Fail2ban with RFC1918 whitelist, unattended-upgrades). Root SSH login is disabled; password auth remains on so you can manage the VM from the LAN without keys.

## How to use (overview)

Each game has its own folder with scripts and a **game-specific README** that includes:

- How to download the scripts (e.g. `wget` URLs)
- Install and setup steps
- Game-specific options (save import/export, server config, etc.)

| Game         | Folder         | README |
|-------------|----------------|--------|
| Satisfactory | `satisfactory/` | [satisfactory/README.md](satisfactory/README.md) |
| Palworld     | `palworld/`     | [palworld/README.md](palworld/README.md) |

From the VM (SSH or Proxmox console), use the **How to download** section inside the README for the game you want (Satisfactory or Palworld). Each README lists the exact `wget` commands and run instructions for that game’s scripts.

See the [Proxmox guide](../../guides/how-to_ultimate_proxmox.md) in the repo for creating a cloud-init VM and using the console.

## Prerequisites

- **Steam user**: Scripts create a `steam` user if missing (Satisfactory and Palworld both ensure it exists).
- **Root/sudo**: Run with `sudo` (or as root) for package install, UFW, systemd, and security hardening.
- **Access**: Use Proxmox console or SSH from the LAN. Port 22 is not opened to the internet; scripts can optionally allow SSH (22/tcp) from your LAN CIDR only.

## Firewall model

- **LAN-only (default for home)**: UFW allows game + Steam ports (and optionally SSH) only from a LAN CIDR (e.g. `192.168.1.0/24`). No ports are opened to the public internet; use Proxmox console or LAN SSH for management.
- **Off-LAN access**: For remote play or management outside your network, use a VPN or tunnel (e.g. WireGuard, Tailscale, or playit.gg)—see the [Remote Connection Options](#remote-connection-options) table below. Do not expose game or SSH ports directly to the internet.
- **VPS**: Roadmap.

## Scripts (by game)

| Game         | Scripts / description |
|-------------|------------------------|
| Satisfactory | `satisfactory.sh` — Full setup: multiverse, steam user, SteamCMD, UFW (LAN or VPS), systemd, SSH hardening, Fail2ban, unattended-upgrades. See [satisfactory/README.md](satisfactory/README.md). |
| Palworld     | `palworld.sh`, `import-palworld-save.sh`, `export-palworld-save.sh`, `config-palworld.sh` — Install/update server, import/export saves, configure server settings. See [palworld/README.md](palworld/README.md). |

## Local troubleshooting (SteamCMD game servers)

Use these commands on the server (SSH or Proxmox console) to diagnose connection timeouts, failures to connect, or inactive services.

### Start / restart / status

| Game        | Service name   | Commands |
|-------------|----------------|----------|
| Palworld    | `palworld`     | `sudo systemctl start palworld` \| `stop` \| `restart` \| `status palworld` |
| Satisfactory| `satisfactory` | `sudo systemctl start satisfactory` \| `stop` \| `restart` \| `status satisfactory` |

```bash
# Start server (if inactive after setup)
sudo systemctl start palworld

# Restart after config changes
sudo systemctl restart palworld

# Check if running
sudo systemctl status palworld
```

Services are enabled to start automatically on boot (`systemctl enable`). No manual start needed after reboot.

### View logs

```bash
# Palworld: stdout / stderr
sudo tail -f /var/log/palworld.log
sudo tail -f /var/log/palworld.err

# Satisfactory: stdout / stderr
sudo tail -f /var/log/satisfactory.log
sudo tail -f /var/log/satisfactory.err

# Systemd journal (startup, crashes, restarts)
sudo journalctl -u palworld -f
```

### Verify ports and firewall

```bash
# Check if process is listening on game ports
ss -ulnp | grep -E '8211|27015'    # Palworld
ss -ulnp | grep -E '7777|15000'    # Satisfactory

# Firewall status
sudo ufw status verbose | grep -E 'Status|8211|27015|7777|15000'

# Test from client (PowerShell): TCP connectivity
# Test-NetConnection -ComputerName 192.168.1.234 -Port 8211
```

### Connection timeout checklist

| Check | Action |
|-------|--------|
| Service inactive | `sudo systemctl start <service>` |
| Server still loading | Game servers can take 2–5+ min; wait for "Server listening" in logs |
| Firewall | Ensure client IP is in LAN CIDR (e.g. `192.168.1.0/24`) |
| Client firewall / AV | Temporarily disable or add exception for game |
| Version mismatch | Update game client and server to match |
| Wrong port | Palworld: `IP:8211`. Satisfactory: `IP:7777` (or configured port) |

## Alternative Management Platforms

For users looking to host outside their network or seeking more comprehensive management UIs beyond basic SteamCMD automation, several platforms provide enhanced server management with web interfaces, security features, and remote access capabilities.

### Server Management Platforms

| Platform | Hosting Style Focus | Security/HTTPS Onboarding | Licensing for Self-Hosters | Key Strengths |
|----------|-------------------|-------------------------|---------------------------|---------------|
| **AMP** | Self-host + professional hosts | Guided nginx + Let's Encrypt; internal HTTPS options | One-time lifetime license available | Best-in-class for "done-for-you" security, multi-game support, web UI with templates, lifecycle controls, permissions, and centralized access |
| **Multicraft** | Traditional game hosts | Depends on host's own web setup | Often hoster-driven, less "buy once" | Established panel for game hosting providers |
| **Pterodactyl** | Dev/ops & Docker-savvy users | Docker + reverse proxy you design/configure | Open-source, but you own all integration work | Modern, Docker-based with strong community support |
| **TCAdmin** | Enterprise / commercial hosts | Strong features; more complex to configure | Commercial, tuned for large hosting providers | Deep enterprise-style control and management |
| **Pelican** | Modern fork for hosts | Similar model to Pterodactyl, host-managed | Free/community, with hoster focus | Lightweight, community-driven alternative |

**Why choose AMP over SteamCMD?**
- AMP wraps SteamCMD workloads in a managed environment with web UI, templates, and lifecycle controls
- Provides consistent workflows for multiple games instead of one-off scripts
- Includes built-in security features like HTTPS setup, firewall guidance, and non-root operation
- Lifetime licensing appeals to long-term hobbyists and small communities

### Remote Connection Options

For hosting outside your local network, these tools enable secure remote access without exposing ports directly to the internet.

| Tool | Type | Cost | Key Features | Best For |
|------|------|------|--------------|----------|
| **WireGuard** | Self-hosted VPN | Free | Point-to-point encrypted tunnels, custom routing, high performance | Technical users wanting full control over network topology |
| **playit.gg** | Gaming tunnel service | Free tier available? | Automatic port forwarding, game-optimized routing, zero-config setup | Gamers wanting simple remote access without network configuration |
| **Tailscale** | Mesh VPN | Free up to 3 users | Zero-config mesh networking, NAT traversal, integrated with existing infrastructure | Teams and families needing secure remote access with minimal setup |

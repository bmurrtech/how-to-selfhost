# Local game servers

Scripts to set up SteamCMD-based dedicated game servers (Satisfactory, Palworld, etc.) on Linux, with optional UFW rules for **local home network** (e.g. Proxmox VM, LAN-only) or VPS-style access.

## Why this repo exists

- **VPS-agnostic** — Same scripts work on bare metal, Proxmox VM, or cloud VPS.
- **Local-first** — Favors self-hosting at home (LAN-only firewall) with optional cloud.
- **Security-minded** — Hardens SSH, avoids open ports; favors tools like Tailscale where applicable.
- **Wizard-style** — Interactive prompts; no need to edit scripts for common cases.
- **Modular** — One folder per concern; game-specific scripts (Palworld, Satisfactory) as separate files.
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

## High-level overview (what each script does)

| Script | Main actions (no secrets logged) |
|--------|----------------------------------|
| **satisfactory.sh** | Root: adds multiverse, i386, lib32gcc-s1; prompts LAN vs VPS firewall; configures UFW (LAN 192.168.1.0/24 or trusted IP + whitelist), optional LAN SSH (22/tcp); creates/adds steam user; installs steamcmd, SteamCMD app 1690800 (optional experimental); writes satisfactory.service; **bundled**: minimal SSH hardening (PermitRootLogin no), Fail2ban (RFC1918 whitelist), unattended-upgrades. |
| **palworld.sh** | Root: steam user creation if missing; prompts install dir; apt install steamcmd + lib32gcc-s1; SteamCMD app 2394010; optional first run for config dirs; optional PalWorldSettings.ini; writes palworld.service; UFW from LAN CIDR (default 192.168.1.0/24) for game ports 8211, 27015, 27031–27036, optional LAN SSH (22/tcp); **bundled**: minimal SSH hardening, Fail2ban (RFC1918 whitelist), unattended-upgrades. |

## Prerequisites

- **Steam user**: Scripts create a `steam` user if missing (Satisfactory and Palworld both ensure it exists).
- **Root/sudo**: Run with `sudo` (or as root) for package install, UFW, systemd, and security hardening.
- **Access**: Use Proxmox console or SSH from the LAN. Port 22 is not opened to the internet; scripts can optionally allow SSH (22/tcp) from your LAN CIDR only.

## How to download (wget)

From the VM (SSH or Proxmox console):

```bash
# Satisfactory
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/satisfactory.sh -O satisfactory.sh
chmod +x satisfactory.sh
sudo ./satisfactory.sh

# Palworld
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld.sh -O palworld.sh
# Or use the short URL: https://tinyurl.com/47yr6kta
# wget https://tinyurl.com/47yr6kta -O palworld.sh
chmod +x palworld.sh
sudo ./palworld.sh
```

See the [Proxmox guide](../../guides/how-to_ultimate_proxmox.md) in the repo for creating a cloud-init VM and using the console.

## Firewall model

- **LAN-only (default for home)**: UFW allows game + Steam ports (and optionally SSH) only from a LAN CIDR (e.g. `192.168.1.0/24`). No ports are opened to the public internet; use Proxmox console or LAN SSH for management.
- **Off-LAN access**: For remote play or management outside your network, use a VPN or tunnel (e.g. WireGuard, Tailscale, or playit.gg)—see the [Remote Connection Options](#remote-connection-options) table below. Do not expose game or SSH ports directly to the internet.
- **VPS**: Roadmap.

## Scripts

| Script            | Game        | Description |
|------------------|-------------|-------------|
| `satisfactory.sh` | Satisfactory | Full setup: multiverse, steam user, SteamCMD, UFW (LAN or VPS), systemd, SSH hardening, Fail2ban, unattended-upgrades. |
| `palworld.sh`     | Palworld     | Install/update Palworld dedicated server, config, systemd, UFW for LAN, SSH hardening, Fail2ban, unattended-upgrades. |

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
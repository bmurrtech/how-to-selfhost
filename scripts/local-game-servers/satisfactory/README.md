# Satisfactory dedicated server

Scripts to install and run a Satisfactory dedicated game server on Linux (SteamCMD + systemd + UFW).

## How to download and run

From the game server (SSH or Proxmox console):

```bash
cd ~
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/satisfactory/satisfactory.sh -O satisfactory.sh
chmod +x satisfactory.sh
sudo ./satisfactory.sh
```

The script prompts for LAN vs VPS firewall, installs SteamCMD and the Satisfactory server app (1690800), creates the `satisfactory` systemd service, and applies baseline hardening (UFW, Fail2ban, unattended-upgrades). See the [main README](../README.md) for prerequisites and troubleshooting.

## Scripts

| Script | Description |
|--------|-------------|
| `satisfactory.sh` | Full setup: multiverse, i386, lib32gcc1, steam user, SteamCMD, UFW (LAN or VPS), systemd, SSH hardening, Fail2ban, unattended-upgrades. |

## Service

- **Service name:** `satisfactory`
- **Commands:** `sudo systemctl start satisfactory` \| `stop` \| `restart` \| `status satisfactory`
- **Logs:** `sudo tail -f /var/log/satisfactory.log` and `sudo tail -f /var/log/satisfactory.err`

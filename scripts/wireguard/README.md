# WireGuard scripts

Scripts and cloud-config for deploying a WireGuard VPN server (e.g. on a Proxmox VM or VPS).

## Why use these

- **Private mesh**: Give devices a stable VPN IP (e.g. 10.7.0.x) so you can reach homelab or VPS without opening public ports.
- **One-time setup**: Standalone script or cloud-init; then add clients with a single command (cloud-init path) or manual `wg` config.

## High-level overview (what each file does)

| File | Main actions |
|------|--------------|
| **wg-selhost.sh** | Runs as root: apt update; installs wireguard, wireguard-tools, qrencode, curl; generates server key pair; writes `/etc/wireguard/wg0.conf` (10.7.0.1/24, iptables MASQUERADE); enables and starts `wg-quick@wg0`. Does not install client-add helper. |
| **wg-cloud-init.yaml** | Cloud-init: installs packages; writes `/opt/wg-selfhost.sh` (inline script that installs WG, creates wg0.conf, then defines `wg-add`, `wg-show`, `wg-qr` in `/usr/local/sbin` and client configs in `~/.wireguard/`); runcmd executes the inline script. |

## Files

| File | Description |
|------|-------------|
| `wg-selhost.sh` | Standalone script: install WireGuard, generate server keys, create `wg0.conf`, enable `wg-quick@wg0`. Run as root. After run, add clients with `sudo wg-add <name>` (if that helper was installed by the cloud-init version). |
| `wg-cloud-init.yaml` | Cloud-init user-data that installs WireGuard and inlines a full self-host script; creates `wg-add`, `wg-show`, `wg-qr` helpers and client configs under `~/.wireguard/`. |

## Usage

- **Standalone (VM already running)**: Copy `wg-selhost.sh` onto the server (e.g. via wget from this repo), `chmod +x`, run with `sudo`. The script in this folder does not install the `wg-add` helper; that is in the cloud-init inline script. For add-client workflow on a manual install, use `wg` and edit `/etc/wireguard/wg0.conf` as needed.
- **Proxmox cloud-init**: Use `wg-cloud-init.yaml` as the user-data for a cloud-init VM so that WireGuard is installed and the helpers are available after first boot.

## Download (wget)

```bash
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/wireguard/wg-selhost.sh -O wg-selhost.sh
chmod +x wg-selhost.sh
sudo ./wg-selhost.sh
```

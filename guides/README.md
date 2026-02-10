# Guides

How-to guides for homelab, self-hosting, and game servers. All links in the repo point here (e.g. from [README](../README.md)).

For **scripted game server installs** (Satisfactory, Palworld) with SteamCMD, UFW, and systemd, see [scripts/local-game-servers](../scripts/local-game-servers/README.md).

## Glossary and status

| Status | Title | Short description |
|--------|--------|-------------------|
| WIP | [ULTIMATE Proxmox Hypervisor](how-to_ultimate_proxmox.md) | ZFS, cloud-init, Cloudflare remote access, Portainer, Plex, K3s, Ansible |
| WIP | [Remotely Access Your Servers via Cloudflare](how-to_cloudflare.md) | Tunnels, SASE/Zero-trust, MFA, Authelia |
| WIP | [PfSense NG-FW Configuration with VLANS](how-to_pfsense.md) | VLANs, firewall, HAProxy |
| WIP | [ULITMATE Self-Hosted Gamer Server](how-to_game_servers.md) | Pterodactyl, Satisfactory, ARK, Minecraft/FTB/Crafty; CLI scripts in [scripts/local-game-servers](../scripts/local-game-servers/) |
| WIP | [Self-hosted, Security-hardened Ghost Blog Site](how-to_ghost_blog.md) | Security-hardened Ghost via Docker/Portainer, DNS, firewall |
| WIP | [All Things AI](how-to_AI.md) | Ollama, Conda, PyTorch, CUDA, dev environment |
| WIP | [How-to Create a Flux Node on Proxmox](how-to_flux_proxmox_node.md) | Flux node setup (short; links to pfSense) |
| WIP | [How-to Setup Kemp Load-balancer](how-to_kemp_loadmaster.md) | Enterprise load balancer on Proxmox (OVF/SCP) |
| WIP | [How-to Make a 24-7 Youtube Livestream](how-to_24-7_livestream.md) | RSS/RTSP, TICKR, Ant Media Server, OBS (WIP, untested) |
| WIP | [Focalboard](how-to_focalboard.md) | Focalboard + Certbot, Docker Compose |
| WIP | [Certbot](how-to_certbot.md) | Let's Encrypt, webroot vs standalone, Docker |
| WIP | [Neoxa Mining VM](how-to_neoxa_node.md) | Neoxa wallet, mining node setup |
| WIP | [Jupyter Lab](how-to-jupyter-lab.md) | JupyterLab setup (references cloud-init) |
| WIP | [S3 / MinIO Object Storage](how-to_s3-minio.md) | Self-hosted S3-compatible storage, rclone, game save backups |
| Incomplete | [Email Server](how-to-email-server.md) | Mailcow/VPS email (draft; reverse DNS / static IP requirements) |
| Incomplete | [Google Cloud VM](how-to-google-cloud-vm.md) | GCP free tier VM (partial; more guides planned) |
| Other | [My Homelab Projects](my_homelab_projects.md) | Checklist / reference of homelab goals and links |

**Status key**

- **WIP** — In progress; has substantive content but not declared complete.
- **Incomplete** — Skeleton, placeholder, or explicitly unfinished.
- **Other** — Reference or meta (e.g. checklist), not a step-by-step how-to.

## Cross-references

Guides link to each other with relative paths (e.g. `how-to_ultimate_proxmox.md#portainer`). From the repo root, use `guides/<filename>`.

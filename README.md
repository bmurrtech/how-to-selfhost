# Self-Hosting How-to & Beyond

### Giving you digital freedom, privacy, and control; empowering you to learn, self-host, and play freely.

## Top Guides

|  | Status | Guide | About |
|---|--------|--------|----------|
| 🏠 | WIP | [ULTIMATE Proxmox Hypervisor](guides/how-to_ultimate_proxmox.md) | ZFS, cloud-init, Portainer, Plex, K3s, Ansible |
| 🎮 | WIP | [ULTIMATE Self-Hosted Game Servers Hub](guides/how-to_game_servers.md) | [SteamCMD](guides/how-to_steamCMD.md), [Pterodactyl](guides/how-to_pterodactyl.md), [Minecraft/Crafty](guides/how-to_minecraft_multi_server.md); [scripts](scripts/local-game-servers/README.md) |
| 📝 | WIP | [Ghost Blog (security-hardened)](guides/how-to_ghost_blog.md) | Docker/Portainer, DNS, firewall |
| 🔒 | WIP | [Remotely Access via Cloudflare](guides/how-to_cloudflare.md) | Tunnels, SASE/Zero-trust, MFA, Authelia |
| 🔥 | WIP | [PfSense NG-FW + VLANs](guides/how-to_pfsense.md) | VLANs, firewall, HAProxy |
| 📦 | Incomplete | [S3 / MinIO Object Storage](guides/how-to_s3-minio.md) | Self-hosted S3, rclone, game save backups |
| ⛏️ | WIP | [Flux Node on Proxmox](guides/how-to_flux_proxmox_node.md) | Flux node (links to pfSense) |
| 🪙 | WIP | [Neoxa Mining VM](guides/how-to_neoxa_node.md) | Neoxa wallet, mining node |
| ☁️ | WIP | [Google Cloud VM](guides/how-to-google-cloud-vm.md) | GCP free tier (partial) |

**Status key**: **WIP** = in progress, substantive; **Incomplete** = skeleton or unfinished; **Other** = reference/meta.

![self-hosted-infra](https://i.imgur.com/shQaQeR.png)

Full glossary and cross-references: **[guides/README.md](guides/README.md)**.

## Scripts (by folder)

|  | Folder | What’s inside | README |
|---|--------|----------------|--------|
| 🎮 | [local-game-servers](scripts/local-game-servers/README.md) | SteamCMD, UFW, systemd, save import/export | [README](scripts/local-game-servers/README.md) |
| 🛡️ | [security](scripts/security/README.md) | Fail2ban, new sudo user, SSH hardening (secops) | [README](scripts/security/README.md) |
| 🎯 | [wireguard](scripts/wireguard/README.md) | WireGuard VPN — standalone script + cloud-init | [README](scripts/wireguard/README.md) |
| 🔑 | [github](scripts/github/README.md) | Git/GitHub auth — WSL2 + `gh` OAuth in Windows browser | [README](scripts/github/README.md) |

Index and wget examples: **[scripts/README.md](scripts/README.md)**.

### Scripts: trust-but-verify mindset

Nowadays, zero-trust mindset might be better, but to promote public trust:

- Read each script before running it (especially when using `curl | bash` or `wget`).
- Prefer downloading the raw file, reviewing it locally, then executing with appropriate privileges.
- Optionally use **AGENTS.md** in this repo as a system prompt for an AI assistant to perform an unbiased, security-focused review of scripts and produce a short report (see [AGENTS.md](AGENTS.md)).

## Self-Hosting = Digital Freedom, For All

- **Open knowledge is a human right** — We have the moral responsibility to resist digital tyranny. "We hold these truths to be self-evident, that all men are created equal, that they are endowed by their Creator with certain unalienable Rights, that among these are Life, Liberty and the pursuit of Happiness." When "any Form of Government [Big Tech] becomes destructive of these ends, it is the Right of the People to alter or to abolish it, and to institute new Government..." (Declaration of Independence).
- **A stand against digital tyranny** — Big tech erodes privacy, treats you as the product. Open source restores agency.
- **Privacy-by-design** — Host your own services securely and simply, using your hardware or any VPS, no vendor lock-in.
- **Practical tools for real people** — Wizard-style, modular guides/scripted installs make secure self-hosting and game servers accessible to all.
- **Security-built-in, not an afterthought** — Defaults harden SSH, block open ports, and recommend free enterprise solutions (like WireGuard, local-first setup, and role-based access).
- **Help your fellow human** — By using, contributing to, or sharing these tools, you enable digital freedom for yourself and others.

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)  
This repository is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE).

### License Permissions & Restrictions
*Keeping open-source open.*
| Use Case                              | Permitted | Notes/Conditions                                                        |
|----------------------------------------|-----------|-------------------------------------------------------------------------|
| Private/internal use                   | ✔️        | No restrictions                                                         |
| Modify for own private use             | ✔️        |                                                                        |
| Share/distribute (unmodified)          | ✔️        | Must include AGPL license and source                                    |
| Distribute with modifications          | ✔️        | Must release source code under AGPL-3.0                                 |
| Provide as SaaS/network service        | ✔️        | Network users must get complete source                                  |
| Keep modifications private             | ✔️        | Disclosure required only if distributed or served over network          |
| Closed/proprietary forks               | ❌        | All distributed/network use requires full source disclosure             |
| Restricting access to source code      | ❌        | Source must be public for users                                         |
| Sub-licensing under restrictive terms  | ❌        | Must retain AGPL-3.0 copyleft                                           |
| Hosted service without source sharing  | ❌        | Must provide source to all network users                                |

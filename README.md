# Self-Hosting How-to & Beyond

### Giving you digital freedom, privacy, and control; empowering you to learn, self-host, and play freely.

## Top Guides

|  | Guide | About |
|---|--------|----------|
| 🏠 | [ULTIMATE Proxmox Hypervisor](guides/how-to_ultimate_proxmox.md) | ZFS, cloud-init, Portainer, Plex, K3s, Ansible |
| 🎮 | [ULTIMATE Self-Hosted Game Servers Hub](guides/how-to_game_servers.md) | [SteamCMD](guides/how-to_steamCMD.md), [Pterodactyl](guides/how-to_pterodactyl.md), [Minecraft/Crafty](guides/how-to_minecraft_multi_server.md); [scripts](scripts/local-game-servers/README.md) |
| 📝 | [Ghost Blog (security-hardened)](guides/how-to_ghost_blog.md) | Docker/Portainer, DNS, firewall |
| 🔒 | [Remotely Access via Cloudflare](guides/how-to_cloudflare.md) | Tunnels, SASE/Zero-trust, MFA, Authelia |
| 🔥 | [PfSense NG-FW + VLANs](guides/how-to_pfsense.md) | VLANs, firewall, HAProxy |
| ⛏️ | [Flux Node on Proxmox](guides/how-to_flux_proxmox_node.md) | Flux node (links to pfSense) |
| 🪙 | [Neoxa Mining VM](guides/how-to_neoxa_node.md) | Neoxa wallet, mining node |
| ☁️ | [Google Cloud VM](guides/how-to-google-cloud-vm.md) | GCP free tier (partial) |

![self-hosted-infra](https://i.imgur.com/shQaQeR.png)

Full glossary of guides: **[guides/README.md](guides/README.md)**.

## Scripts

Runnable shell scripts for the boring host work: bring up a local LLM, stand a game server, harden SSH, spin WireGuard, fix GitHub auth on WSL. Each folder has a README with wget examples, what the script does, and what to watch for before you run it.

### Local AI quick start (DGX Spark)

Public installer (release candidate channel — **no stable yet**):

```bash
# Prefer: fetch first, review, then run
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark?channel=rc" -o mycmd-install.sh
less mycmd-install.sh
bash mycmd-install.sh

# Or one-liner (trust-but-verify):
curl -fsSL "https://get.mycmd.site/qwen3-8-flash-next/spark?channel=rc" | sh
```

What it does: resolve catalog `rc` → download GitHub Release `v0.0.1-rc1` → SHA-256 verify → extract → `mise install` → `just check`.

Then on the host:

```bash
cd ~/mycmd/qwen3-8-flash-next/spark   # default install root; see installer output
cp .env.example .env && chmod 600 .env   # set VLLM_API_KEY / HF_TOKEN
just setup
just deploy
just status
```

Architecture: [CONTEXT.md](CONTEXT.md) · Worker: [bootstrap/](bootstrap/) · Catalog: [catalog/](catalog/) · Recipe ops: [scripts/local-ai/README.md](scripts/local-ai/README.md)

|  | Folder | What’s inside |
|---|--------|----------------|
| 🧠 | [local-ai](scripts/local-ai/README.md) | Qwen3.8 NVFP4 / vLLM on DGX Spark (mise + just); install via `get.mycmd.site` above |
| 🎮 | [local-game-servers](scripts/local-game-servers/README.md) | SteamCMD game servers (Satisfactory, Palworld), UFW, systemd, save import/export |
| 🛡️ | [security](scripts/security/README.md) | Fail2ban, new sudo user, SSH hardening (`vps-sec-harden.sh`) |
| 🎯 | [wireguard](scripts/wireguard/README.md) | WireGuard VPN — standalone script + cloud-init |
| 🔑 | [github](scripts/github/README.md) | Git/GitHub auth — WSL2 + `gh` OAuth in Windows browser |

Index and wget examples: **[scripts/README.md](scripts/README.md)**.

### Scripts: trust-but-verify mindset

Nowadays, zero-trust mindset might be better, but to promote public trust:

- Read each script before running it (especially when using `curl | bash` or `wget`).
- Prefer downloading the raw file, reviewing it locally, then executing with appropriate privileges.

## Self-Hosting = Digital Freedom, For All

- **Open knowledge is a human right** — We have the moral responsibility to resist digital tyranny. "We hold these truths to be self-evident, that all men are created equal, that they are endowed by their Creator with certain unalienable Rights, that among these are Life, Liberty and the pursuit of Happiness." When "any Form of Government [Big Tech] becomes destructive of these ends, it is the Right of the People to alter or to abolish it, and to institute new Government..." (Declaration of Independence).
- **A stand against digital tyranny** — Big tech erodes privacy, treats you as the product. Open source restores agency.
- **Privacy-by-design** — Host your own services securely and simply, using your hardware or any VPS, no vendor lock-in.
- **Practical tools for real people** — Wizard-style, modular guides/scripted installs make secure self-hosting and game servers accessible to all.
- **Security-built-in, not an afterthought** — Defaults harden SSH, block open ports, and recommend free enterprise solutions (like WireGuard, local-first setup, and role-based access).
- **Help your fellow human** — By using, contributing to, or sharing these tools, you enable digital freedom for yourself and others.

## Support open source

If Alchemux saves you time, consider:

- ⭐ **Starring the repo** — [![Star on GitHub](https://img.shields.io/badge/Star-on_GitHub-blue?logo=github)](https://github.com/bmurrtech/alchemux)
- 🐛 **[Open a GitHub Issue](https://github.com/bmurrtech/alchemux/issues/new/choose)** — bugs, ideas, and feedback
- 📣 **Sharing** with others who download or archive media from the terminal
- ☕ **[Buy Me a Coffee](https://www.buymeacoffee.com/bmurrtech)** or **[Ko-fi](https://ko-fi.com/bmurrtech)**

<p align="center">
  <a href="https://www.buymeacoffee.com/bmurrtech" target="_blank" rel="noopener">
    <img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Support%20the%20project-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black" alt="Buy Me a Coffee">
  </a>
  <a href="https://ko-fi.com/bmurrtech" target="_blank" rel="noopener">
    <img src="https://img.shields.io/badge/Ko--fi-Support%20the%20project-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Ko-fi">
  </a>
</p>

## License

This repository is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE). Permissions, restrictions, commercial licensing, and disclaimer: **[docs/LICENSE.md](docs/LICENSE.md)**.

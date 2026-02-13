# Game Server Options: Self-Hosted & Beyond

This guide helps you choose how to run game servers — **self-hosted, free, and open-source first** — with pointers to paid and managed alternatives when they fit your needs.

---

## Why Self-Host Game Servers?

- **Digital freedom** — Own your infrastructure; no vendor lock-in or surprise price hikes.
- **Privacy** — Your game data stays on your hardware or VPS.
- **Cost control** — Pay for hardware or a VPS once; avoid per-slot or per-month hosting fees.
- **Learn by doing** — Gain real DevOps and networking skills.

This repo's [values](../README.md#self-hosting--digital-freedom-for-all) emphasize open knowledge, privacy-by-design, and practical tools for real people. The guides and scripts here lean toward **self-hosted, free, and open-source** solutions.

---

## Quick Path: Which Guide Fits?

| Goal | Guide | Best For |
|------|-------|----------|
| **Steam games** (Satisfactory, Palworld, ARK) | [How-to SteamCMD](how-to_steamCMD.md) | CLI scripts, manual SteamCMD, systemd |
| **Minecraft** (modded, multi-server, Crafty) | [How-to Minecraft Multi-Server](how-to_minecraft_multi_server.md) | Crafty web UI, FTB, vanilla Forge |
| **Multi-game panel** (one UI, many games) | [How-to Pterodactyl](how-to_pterodactyl.md) | Dedicated VPS/VM; add/remove servers via web UI |

### Scripts First

For **Satisfactory** and **Palworld**, use the ready-made scripts in [scripts/local-game-servers](../scripts/local-game-servers/README.md). They handle SteamCMD, UFW, systemd, and security in one run. See [how-to SteamCMD](how-to_steamCMD.md#preferred-ready-made-installer-scripts) for wget commands and workflow.

---

## Self-Hosted Options (This Repo)

| Option | Type | Cost | Guide |
|--------|------|------|-------|
| **SteamCMD + systemd** | CLI scripts | Free | [how-to_steamCMD.md](how-to_steamCMD.md) |
| **Crafty** | Minecraft web UI | Free | [how-to_minecraft_multi_server.md](how-to_minecraft_multi_server.md) |
| **Pterodactyl** | Multi-game web panel | Open-source | [how-to_pterodactyl.md](how-to_pterodactyl.md) |

---

## Alternative Management Platforms

For users who want more than basic SteamCMD automation — web UIs, templates, and managed workflows — these platforms offer enhanced server management with security features and remote access capabilities.

### Server Management Panels

| Platform | Hosting Focus | Security/HTTPS | Licensing for Self-Hosters | Key Strengths |
|----------|---------------|----------------|---------------------------|---------------|
| **AMP** | Self-host + professional hosts | Guided nginx + Let's Encrypt; internal HTTPS options | One-time lifetime license available | Best-in-class "done-for-you" security, multi-game support, web UI with templates, lifecycle controls, permissions, centralized access |
| **Multicraft** | Traditional game hosts | Depends on host's web setup | Often hoster-driven, less "buy once" | Established panel for game hosting providers |
| **Pterodactyl** | Dev/ops & Docker-savvy users | Docker + reverse proxy you design/configure | Open-source; you own all integration work | Modern, Docker-based with strong community support |
| **TCAdmin** | Enterprise / commercial hosts | Strong features; more complex to configure | Commercial, tuned for large hosting providers | Deep enterprise-style control and management |
| **Pelican** | Modern fork for hosts | Similar model to Pterodactyl, host-managed | Free/community, with hoster focus | Lightweight, community-driven alternative |

**Why choose AMP over SteamCMD?**
- AMP wraps SteamCMD workloads in a managed environment with web UI, templates, and lifecycle controls
- Provides consistent workflows for multiple games instead of one-off scripts
- Includes built-in security features like HTTPS setup, firewall guidance, and non-root operation
- Lifetime licensing appeals to long-term hobbyists and small communities

### Remote Connection Options

For hosting outside your local network, these tools enable secure remote access **without exposing ports directly to the internet**:

| Tool | Type | Cost | Key Features | Best For |
|------|------|------|--------------|----------|
| **WireGuard** | Self-hosted VPN | Free | Point-to-point encrypted tunnels, custom routing, high performance | Technical users wanting full control over network topology |
| **playit.gg** | Gaming tunnel service | Free tier available | Automatic port forwarding, game-optimized routing, zero-config setup | Gamers wanting simple remote access without network configuration |
| **Tailscale** | Mesh VPN | Free up to 3 users | Zero-config mesh networking, NAT traversal, integrated with existing infrastructure | Teams and families needing secure remote access with minimal setup |

See the [WireGuard guide](../scripts/wireguard/README.md) in this repo for self-hosted VPN setup.

---

## Summary

| Path | Action |
|------|--------|
| **Steam games, fastest** | → [scripts/local-game-servers](../scripts/local-game-servers/README.md) + [how-to SteamCMD](how-to_steamCMD.md) |
| **Minecraft, multi-server** | → [how-to Minecraft Multi-Server](how-to_minecraft_multi_server.md) |
| **Multi-game panel** | → [how-to Pterodactyl](how-to_pterodactyl.md) |
| **Paid/managed UI** | → AMP, Multicraft, or a managed host |
| **Remote play** | → WireGuard, Tailscale, or playit.gg |

# Scripts

Scripts and configs used by the how-to guides. Organized by purpose.

## Index

| Folder | Purpose |
|--------|---------|
| [security/](security/) | Fail2ban, new sudo user, SSH/system hardening (secops). For home LAN or VPS; see README for lockout safety. |
| [local-game-servers/](local-game-servers/) | SteamCMD-based game servers: Satisfactory, Palworld. UFW + systemd, tuned for local home or VPS. |
| [wireguard/](wireguard/) | WireGuard VPN server: standalone script and cloud-init user-data. |
| [github/](github/) | Git/GitHub auth: WSL2 + `gh` browser setup so OAuth opens in Windows default browser. |

## Downloading scripts (wget)

Use the **raw** URL for the default branch (e.g. `main`):

```text
https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/<folder>/<script>
```

Example (from a Linux host or Proxmox console):

```bash
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/f2b-install.sh -O f2b-install.sh
chmod +x f2b-install.sh
sudo ./f2b-install.sh
```

Each subfolder has a **README.md** with: **why to use** the scripts, a **high-level overview** of what each script does (to support zero-trust review), wget examples, and safety notes. See also the root [README](../README.md) for zero-trust mindset and validation tips (e.g. shellcheck, [AGENTS.md](../AGENTS.md) for AI-assisted script review).

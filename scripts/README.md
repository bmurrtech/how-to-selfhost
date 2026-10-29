# Scripts

Scripts and configs used by the how-to guides. Organized by purpose.

## Index

| Folder | Purpose |
|--------|---------|
| [security/](security/) | VPS/LAN baseline (`security/vps-baseline`): mise + just wrappers around Fail2ban, new sudo user, SSH harden. Prefer `get.mycmd.site`; archived wget under `security/archive/`. |
| [local-game-servers/](local-game-servers/) | SteamCMD-based game servers: Satisfactory, Palworld. UFW + systemd, tuned for local home or VPS. |
| [wireguard/](wireguard/) | WireGuard VPN server: standalone script and cloud-init user-data. |
| [github/](github/) | Git/GitHub auth: WSL2 + `gh` browser setup so OAuth opens in Windows default browser. |
| [local-ai/](local-ai/) | Qwen3.8 NVFP4 / vLLM on DGX Spark + RTX PRO 6000 (mise + just). Prefer `get.mycmd.site`; see folder README. |
| [packaging/](packaging/) | Build recipe release tarballs + sha256 for `get.mycmd.site` (`package-recipe.sh`). |
| [patching/](patching/) | Update-only workstation maintenance (`Update-DevTools.ps1` / `update-devtools.sh`). Inventory first; never install missing apps. |


## Downloading scripts (wget)

Use the **raw** URL for the default branch (e.g. `main`):

```text
https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/<folder>/<script>
```

Example (from a Linux host or Proxmox console):

```bash
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/security/archive/f2b-install.sh -O f2b-install.sh
chmod +x f2b-install.sh
sudo ./f2b-install.sh
```

Each subfolder has a **README.md** with: **why to use** the scripts, a **high-level overview** of what each script does (to support zero-trust review), wget examples, and safety notes. See also the root [README](../README.md) for zero-trust mindset and validation tips (e.g. shellcheck); [AGENTS.md](../AGENTS.md) for the repo operating manual.

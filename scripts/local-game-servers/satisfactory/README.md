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

After a **game client update**, the dedicated server often needs a matching **Steam app update** (same app ID, validated files). Use `update-sf.sh` for a controlled, repeatable update instead of relying on `ExecStartPre` alone or manual SteamCMD from the wrong directory.

## Updating the server (`update-sf.sh`)

The updater is **idempotent**: safe to run repeatedly; it always resolves **`SATISFACTORY_INSTALL_DIR`** (default `/home/steam/sfserver`) to an absolute path, checks for **`FactoryServer.sh`** before and after SteamCMD, uses a **per-install flock lock** (`.update-sf.lock` in the server root) so two updates cannot run at once, and as **root** stops `satisfactory` before updating and starts it again afterward **only if this run stopped it** and the update succeeded. Logs go to stderr and, when run as root with a writable `/var/log`, to **`/var/log/satisfactory-update.log`**.

### Download (placeholder raw URL)

Until the script is available at your preferred raw Git URL, copy `update-sf.sh` onto the server (e.g. `scp`) or paste the file from this repository. When you have the final raw link, use it like the installer below.

```bash
# PLACEHOLDER — replace with your real raw URL, e.g.:
# wget 'https://raw.githubusercontent.com/OWNER/REPO/refs/heads/main/scripts/local-game-servers/satisfactory/update-sf.sh' -O update-sf.sh
chmod +x update-sf.sh
```

### Run (recommended)

From the server, as **root** (so systemd can stop/start the unit cleanly):

```bash
sudo ./update-sf.sh
```

Plan only (no lock, SteamCMD, or systemd changes):

```bash
sudo ./update-sf.sh --dry-run
```

Non-default install root (same as env `SATISFACTORY_INSTALL_DIR`):

```bash
sudo ./update-sf.sh --install-dir /home/steam/sfserver
```

Optional environment variables:

| Variable | Purpose |
|----------|---------|
| `SATISFACTORY_INSTALL_DIR` | Server root (default `/home/steam/sfserver`). |
| `SATISFACTORY_STEAMCMD` | Path to `steamcmd` if not under `/home/steam/steamcmd` or `/usr/games/steamcmd`. |
| `SATISFACTORY_BETA` | Set to `experimental` to pass `-beta experimental` (otherwise inferred from `satisfactory.service` when possible). |
| `SATISFACTORY_SKIP_SERVICE` | `1` = only run SteamCMD; do not stop/start systemd (you must ensure the server is stopped). |
| `SATISFACTORY_NO_RESTART` | `1` = after a successful update, do not start the unit even if this script stopped it. |
| `SATISFACTORY_NETWORK_CHECK` | `1` = fail if Steam’s API is unreachable before updating (needs `curl`). |
| `SATISFACTORY_HEALTH_CHECK` | `1` = after restart, wait briefly and check for something listening on port 7777 (`ss`). |
| `SATISFACTORY_UPDATE_LOG` | Append structured log lines to this file (overrides default `/var/log/...` when set). |

Example with network gate and post-restart port check:

```bash
sudo env SATISFACTORY_NETWORK_CHECK=1 SATISFACTORY_HEALTH_CHECK=1 ./update-sf.sh
```

**Automation:** point a **systemd timer** or **cron** at `sudo /path/to/update-sf.sh` on a schedule you accept (updates pull from Steam and restart the game process when the script stopped the service). Prefer a quiet maintenance window; keep `SATISFACTORY_NETWORK_CHECK=1` if you want a hard fail when offline.

## Scripts

| Script | Description |
|--------|-------------|
| `satisfactory.sh` | Full setup: multiverse, i386, lib32gcc1, steam user, SteamCMD, UFW (LAN or VPS), systemd, SSH hardening, Fail2ban, unattended-upgrades. |
| `update-sf.sh` | Idempotent server update: validates install dir + `FactoryServer.sh`, flock lock, SteamCMD `app_update` + `validate`, optional systemd stop/start and health hints. |

## Service

- **Service name:** `satisfactory`
- **Commands:** `sudo systemctl start satisfactory` \| `stop` \| `restart` \| `status satisfactory`
- **Logs:** `sudo tail -f /var/log/satisfactory.log` and `sudo tail -f /var/log/satisfactory.err`
- **Update log:** `sudo tail -f /var/log/satisfactory-update.log` (when the updater runs as root and `/var/log` is writable)

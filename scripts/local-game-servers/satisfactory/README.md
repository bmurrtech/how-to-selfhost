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

The updater is **idempotent**: safe to run repeatedly; it always resolves **`SATISFACTORY_INSTALL_DIR`** (default `/home/steam/sfserver`) to an absolute path, checks for **`FactoryServer.sh`** before and after SteamCMD, uses a **per-install flock lock** (`.update-sf.lock` in the server root) so two updates cannot run at once, and as **root** stops `satisfactory` when it is already running (so files are not changed under a live process), then after a **successful** SteamCMD run runs **`systemctl restart satisfactory`** so the server always loads the binaries that match disk. Logs include **Steam `buildid`** from `steamapps/appmanifest_1690800.acf` before and after the update (for version debugging). Logs go to stderr and, when run as root with a writable `/var/log`, to **`/var/log/satisfactory-update.log`**. Use **`sudo`**; without root the script can update files but cannot restart the unit, which often leaves an old process and triggers in-game “incompatible version.”

### Download

```bash
wget 'https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/satisfactory/update-sf.sh' -O update-sf.sh
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
| `SATISFACTORY_NO_RESTART` | `1` = after a successful update, do not run `systemctl restart` (default is restart when root). |
| `SATISFACTORY_NETWORK_CHECK` | `1` = fail if Steam’s API is unreachable before updating (needs `curl`). |
| `SATISFACTORY_HEALTH_CHECK` | `1` = after restart, wait briefly and check for something listening on port 7777 (`ss`). |
| `SATISFACTORY_UPDATE_LOG` | Append structured log lines to this file (overrides default `/var/log/...` when set). |

Example with network gate and post-restart port check:

```bash
sudo env SATISFACTORY_NETWORK_CHECK=1 SATISFACTORY_HEALTH_CHECK=1 ./update-sf.sh
```

**Automation:** point a **systemd timer** or **cron** at `sudo /path/to/update-sf.sh` on a schedule you accept (updates pull from Steam and the script restarts the unit on success). Prefer a quiet maintenance window; keep `SATISFACTORY_NETWORK_CHECK=1` if you want a hard fail when offline.

### “Incompatible version” / update did not help

1. **Stable vs Experimental** — The Satisfactory **client** branch must match the **server** branch. The updater logs whether SteamCMD is using **public (stable)** or **Experimental** (`-beta experimental`). If you installed with `satisfactory.sh` and chose stable but your Steam client uses **Experimental**, switch the client to the default branch or reinstall the server with the experimental option (or set `SATISFACTORY_BETA=experimental` when updating and align your `satisfactory.service` / reinstall so both match).

2. **Confirm buildids** — After `sudo ./update-sf.sh`, check stderr or `/var/log/satisfactory-update.log` for `pre_steamcmd` and `post_steamcmd` **buildid** lines. If **buildid unchanged** and the game still complains, you are usually on a branch mismatch or Steam did not apply a newer depot.

3. **Epic / different store** — Versioning must still align with the same **game build** the dedicated server expects; branch mismatch behaves like a version error.

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

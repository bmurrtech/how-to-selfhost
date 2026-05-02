# Satisfactory dedicated server

Scripts to install and run a Satisfactory dedicated game server on Linux (SteamCMD + systemd + UFW).

## How the scripts work (overview)

| Script | Role |
|--------|------|
| `satisfactory.sh` | First-time (or **full**) setup: packages, optional UFW, Steam user, SteamCMD, initial game files, `satisfactory.service`, SSH/Fail2ban/unattended-upgrades. **Idempotent**: if `satisfactory.service` already exists, you can choose **Quick** mode to switch **stable ↔ Experimental** and refresh Steam files + systemd **without** redoing the firewall or full security wizard. |
| `update-sf.sh` | Routine **Steam depot** update: stops the unit if needed, **archives SaveGames** (`.bak` tree + `.tar.gz`), runs SteamCMD `validate`, **restores** saves if the `server/` tree lost `.sav` files, prints an **installed-version summary**, then **`systemctl restart satisfactory`**. |

Dedicated saves on Linux (official layout) live under the **`steam` user** at:

`~/.config/Epic/FactoryGame/Saved/SaveGames/` (including `server/` and `blueprints/`).  
Backups default to `/home/steam/satisfactory-save-archives/` (`SaveGames-YYYYMMDD-HHMMSS.bak` + matching `.tar.gz`). Steam **`validate`** usually leaves saves alone; restore only runs if `.sav` files disappear from `server/` after the update.

## Interactive prompts (`satisfactory.sh`)

Asked in order (full install) or a subset (Quick reconfigure). Defaults shown in brackets.

| Step | Input | Options / default | Why you might choose it |
|------|--------|-------------------|-------------------------|
| Run mode (only if `satisfactory.service` **already exists**) | `1` or `2` | **1** Quick — branch + Steam + systemd only | Switch from **Experimental** back to **stable** (or the reverse) without resetting UFW or re-running Fail2ban/SSH steps. |
| | | **2** Full wizard | New machine, or you want **apt upgrade**, **UFW** changes, and security bundles refreshed. |
| Experimental server branch? | `y` / `n` | **n** = public (stable) Steam depot | Matches a normal Steam client (non-Experimental), e.g. client UI like *Update 1.2.x — Build 460533*. |
| | | **y** = `-beta experimental` | Matches a Steam client set to the **experimental** beta. Mismatch here causes “incompatible version” even when both sides are “latest”. |
| Full mode: apt upgrade (if reinstalling) | `y` / `N` | **N** skip (default on re-run) | Faster reconfigure when you only care about the game depot. **y** pulls all package updates (good for long-term maintenance). |
| Full mode: UFW reset (if reinstalling) | `y` / `N` | **N** keep rules (default) | Avoids wiping firewall rules on a live server. **y** only if you intend to rebuild UFW from the script’s wizard. |
| Firewall scenario (if UFW reset proceeds) | `1` / `2` | **1** LAN party | Game (and optional SSH) only from your LAN CIDR. |
| | | **2** VPS + trusted IPs | SSH + game from your IP; extra player IPs from `/etc/satisfactory/trusted_players_whitelist.txt`. |
| Steam user password | `Y` / `n` | **n** skip | Use sudo / console to act as `steam`; avoids a local password on the account. |

`update-sf.sh` is **non-interactive** (flags/env only); use `sudo ./update-sf.sh --dry-run` to preview.

## How to download and run

From the game server (SSH or Proxmox console):

```bash
cd ~
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/satisfactory/satisfactory.sh -O satisfactory.sh
chmod +x satisfactory.sh
sudo ./satisfactory.sh
```

The script installs SteamCMD and app **1690800**, creates the `satisfactory` systemd service, and in **full** mode applies baseline hardening (UFW, Fail2ban, unattended-upgrades). See the [main README](../README.md) for prerequisites and troubleshooting.

After a **game client update**, run **`update-sf.sh`** so the Steam depot matches the client build and the service is restarted.

## Updating the server (`update-sf.sh`)

The updater resolves **`SATISFACTORY_INSTALL_DIR`** (default `/home/steam/sfserver`), validates **`FactoryServer.sh`**, takes a **flock** lock, stops **`satisfactory`** when it is running, **backs up SaveGames**, runs SteamCMD **`app_update` + `validate`**, restores saves if needed, prints a **version banner** (Steam `buildid` + `Build.version` when present), then **`systemctl restart satisfactory`** on success (as root). Logs: stderr and **`/var/log/satisfactory-update.log`** when root can write `/var/log`.

### Download

```bash
wget 'https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/satisfactory/update-sf.sh' -O update-sf.sh
chmod +x update-sf.sh
```

### Run (recommended)

```bash
sudo ./update-sf.sh
```

```bash
sudo ./update-sf.sh --dry-run
```

```bash
sudo ./update-sf.sh --install-dir /home/steam/sfserver
```

### Environment variables (`update-sf.sh`)

| Variable | Purpose |
|----------|---------|
| `SATISFACTORY_INSTALL_DIR` | Server root (default `/home/steam/sfserver`). |
| `SATISFACTORY_STEAMCMD` | Path to `steamcmd` if not auto-detected. |
| `SATISFACTORY_BETA` | `experimental` forces `-beta experimental` (else inferred from `satisfactory.service` when possible). |
| `SATISFACTORY_SKIP_SERVICE` | `1` = SteamCMD only (no systemd stop/restart). |
| `SATISFACTORY_NO_RESTART` | `1` = do not `systemctl restart` after success. |
| `SATISFACTORY_NETWORK_CHECK` | `1` = require Steam API reachability (`curl`). |
| `SATISFACTORY_HEALTH_CHECK` | `1` = after restart, probe port 7777 with `ss`. |
| `SATISFACTORY_UPDATE_LOG` | Append structured logs to this path. |
| `SATISFACTORY_SAVE_ARCHIVE_DIR` | Override backup directory (default `/home/steam/satisfactory-save-archives`). |
| `SATISFACTORY_SKIP_SAVE_BACKUP` | `1` = skip SaveGames archive before SteamCMD. |

Optional `satisfactory.sh` / install-time: **`SATISFACTORY_SAVE_ARCHIVE_DIR`**, **`SATISFACTORY_SKIP_SAVE_BACKUP`** (same semantics as above).

### Check installed server version (CLI, no extra script)

Default install dir is `/home/steam/sfserver`. Adjust `SF=` if yours differs.

**Steam depot `buildid` + Unreal `Build.version` (if shipped with the build):**

```bash
SF=/home/steam/sfserver
echo "--- Steam appmanifest (buildid) ---"
grep -m1 '"buildid"' "$SF/steamapps/appmanifest_1690800.acf" || echo "(run SteamCMD once if file missing)"
echo "--- Engine Build.version (first match under install) ---"
BV=$(find "$SF" -name 'Build.version' -print -quit 2>/dev/null)
if [[ -n "${BV:-}" ]]; then cat "$BV"; else echo "(not found — compare Steam buildid to client)"; fi
```

Compare **`buildid`** and the **Changelist** / version fields in `Build.version` to the Steam client (**Library → Satisfactory → Properties**). Both scripts also print a short summary after a successful Steam update (`satisfactory.sh` after SteamCMD; `update-sf.sh` at the end of a run).

### “Incompatible version” / update did not help

1. **Stable vs Experimental** — Client branch must match server branch (see interactive table above).
2. **Confirm buildids** — Use the one-liner and/or `/var/log/satisfactory-update.log`.
3. **Epic / other stores** — Same build expectation as Steam.

## Scripts

| Script | Description |
|--------|-------------|
| `satisfactory.sh` | Full or **Quick** setup; idempotent re-run; SaveGames backup before SteamCMD; prints installed version summary after update. |
| `update-sf.sh` | Idempotent depot update, SaveGames archive + conditional restore, flock, systemd restart, version banner. |

## Service

- **Service name:** `satisfactory`
- **Commands:** `sudo systemctl start satisfactory` \| `stop` \| `restart` \| `status satisfactory`
- **Logs:** `sudo tail -f /var/log/satisfactory.log` and `sudo tail -f /var/log/satisfactory.err`
- **Update log:** `sudo tail -f /var/log/satisfactory-update.log` (when the updater runs as root and `/var/log` is writable)
- **Save archives:** `/home/steam/satisfactory-save-archives/` (default)

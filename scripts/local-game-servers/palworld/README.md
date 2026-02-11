# Palworld dedicated server

Scripts to install, configure, and manage a Palworld dedicated server on Linux (SteamCMD + systemd + UFW), including world save import/export and interactive server configuration. Scripts target **Palworld server 0.7.1**; parameters may change in future game versions.

## How to download and run

From the game server (SSH or Proxmox console), download the script(s) you need. Replace `~/scripts` with any directory you prefer.

**Choose one install script for initial server creation:**

| If you want… | Download and run |
|--------------|------------------|
| **Casual** (easier rates, less penalty) | `palworld-casual.sh` |
| **Normal** (balanced defaults) | `palworld-normal.sh` |
| **Hard** (harder rates, more penalty) | `palworld-hard.sh` |
| **Hardcore** (no respawn, permanent loss; all hardcore options on) | `palworld-hardcore.sh` |
| **Custom** (full config wizard before first start) | `palworld-custom.sh` |
| **Default / vanilla** (no PalWorldSettings preset; optional Admin password and REST API only) | `palworld.sh` |

```bash
mkdir -p ~/scripts
cd ~/scripts

# Example: install with Normal preset (choose the script that matches your desired mode)
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld/palworld-normal.sh -O palworld-normal.sh
chmod +x palworld-normal.sh
sudo ./palworld-normal.sh

# Or: full custom config before first start (wizard runs at setup time)
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld/palworld-custom.sh -O palworld-custom.sh
chmod +x palworld-custom.sh
sudo ./palworld-custom.sh

# Or: default/vanilla install (no config preset; only Admin password and REST API prompts)
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld/palworld.sh -O palworld.sh
chmod +x palworld.sh
sudo ./palworld.sh
```

**Post-creation scripts (save import/export, or change config after server exists):**

```bash
wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld/import-palworld-save.sh -O import-palworld-save.sh
chmod +x import-palworld-save.sh

wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld/export-palworld-save.sh -O export-palworld-save.sh
chmod +x export-palworld-save.sh

wget https://raw.githubusercontent.com/bmurrtech/how-to-selfhost/refs/heads/main/scripts/local-game-servers/palworld/config-palworld.sh -O config-palworld.sh
chmod +x config-palworld.sh
```

See the [main README](../README.md) for prerequisites and troubleshooting.

---

## Where Palworld saves live (Windows, Steam)

On Windows (Steam), saves are **not** under `steamapps/common/Palworld/Pal`. They are in your user profile:

- **Direct path:** `C:\Users\<YourWindowsUsername>\AppData\Local\Pal\Saved\SaveGames`
- **Shortcut (Explorer or Win+R):** `%USERPROFILE%\AppData\Local\Pal\Saved\SaveGames`

Inside `SaveGames` you get **two** levels of subfolders:

1. A folder named after your Steam ID (or similar string).
2. Under that, **one folder per world** — the folder name is a long hex-style string that **varies per player and per save** (e.g. different for each world).

**Path you must zip for import:**

```
C:\Users\<YourWindowsUsername>\AppData\Local\Pal\Saved\SaveGames\<string>\<specific-save-string>
```

- `<string>` = first subfolder (e.g. Steam ID).
- **`<specific-save-string>`** = the **world folder** (e.g. a long hex name). This is the folder that contains `Level.sav`, `LevelMeta.sav`, `LocalData.sav`, etc. **Zip this folder** (or its contents). Do **not** include `WorldOption.sav` in the zip (it can override server settings).

So: open `SaveGames\<string>\`, then zip the **specific world folder** you want to import (the one with the `.sav` files). The exact folder name is different for every player/world; use your own world’s folder name.

**Zip structure for import:** Zip either (1) that single world folder (so the zip has one top-level folder with the .sav files inside) or (2) the **contents** of that folder at the zip root (`Level.sav`, `LevelMeta.sav`, `Players/`, etc.). The import script accepts both.

---

## World save management

Paths below assume default install `/home/steam/palserver`. Server save path: `.../Pal/Saved/SaveGames/0/<Folder>/`.

### Method A: SCP / SFTP (no cloud bucket)

Use this if you prefer to copy files directly from your PC to the server without a cloud bucket or scripts.

1. **Stop the server** (on the game server, SSH or Proxmox console):
   ```bash
   sudo systemctl stop palworld
   ```

2. **On your Windows PC**, your local save is under the path above, e.g. `%USERPROFILE%\AppData\Local\Pal\Saved\SaveGames\<SteamID>\<WorldFolder>\`. (In-game: Start Game → select world → click folder icon to open that path.)

3. **On the server**, save path is:
   ```
   /home/steam/palserver/Pal/Saved/SaveGames/0/<Folder>/
   ```
   If the server already created a world, there will be one folder (e.g. a long UUID). Replace that folder’s *contents* with your local save files, or create a new folder and upload into it (then set `DedicatedServerName` in config to that folder name).

4. **Copy files** using WinSCP, FileZilla, or PowerShell SCP. Do **not** upload `WorldOption.sav` (it can override server settings).

5. **Restart the server**:
   ```bash
   sudo systemctl start palworld
   ```

### Method B: Import from URL (import-palworld-save.sh)

1. Zip your world folder as described in **Where Palworld saves live** (exclude `WorldOption.sav`). The script installs `unzip` and `wget` on Debian/Ubuntu if missing.
2. Upload the zip to a publicly reachable URL (or use a presigned URL).
3. On the game server:
   ```bash
   sudo ./import-palworld-save.sh "https://your-url/palworld-world.zip"
   ```
   Or run `sudo ./import-palworld-save.sh` and enter the URL when prompted. Optional: `PAL_INSTALL_DIR=/home/steam/palserver` if you used a different install path.

The script stops the server, downloads the zip, extracts to the save directory, fixes ownership, updates `DedicatedServerName` if needed, and restarts the server. On failure it prints recovery steps.

### Export / backup (export-palworld-save.sh)

1. Optional: configure rclone and a remote (see [S3 / MinIO guide](../../guides/how-to_s3-minio.md)).
2. Set the remote for uploads (optional):
   ```bash
   export PALWORLD_BACKUP_REMOTE=minio:palworld-backups
   ```
3. Run:
   ```bash
   sudo ./export-palworld-save.sh
   ```
   The script stops the server, creates a local backup copy, zips it, restarts the server, saves a zip locally, and if `PALWORLD_BACKUP_REMOTE` is set, uploads via rclone.

---

## Server configuration (config-palworld.sh)

**config-palworld.sh** is intended to be run **after** the Palworld server has been created. Use it when you want to **modify configuration after deployment** (e.g. change difficulty, rates, or options on an existing server). It assumes the server already exists and stops it before applying changes.

By default, `PalWorldSettings.ini` on the server (and on Windows) is empty or minimal; game/save data does not include it. You can either use a preset at install time (casual/normal/hard/hardcore), full custom at install (palworld-custom.sh), or change settings later with **config-palworld.sh**.

**config-palworld.sh** is an interactive wizard that:

- Asks **Advanced mode? [N/y]**. If you press **N** or Enter: simple **difficulty** mode (choose **casual**, **normal**, **hard**, or **hardcore**); the script writes a preset and exits. If you choose **y**: **Custom** difficulty and full fine-grained control of all settings.
- Stops the Palworld service before making changes (required — edits while the server is running are overwritten on shutdown).
- In advanced mode: walks through [configuration parameters](https://docs.palworldgame.com/settings-and-operation/configuration) with **ranges and defaults** (e.g. day/night speed 0.1–5, EXP rate 0.1–20, autosave 30s/1m/5m/10m/15m/30m, death penalty default “Drop all items except equipment”, max structures 400/500/2000/5000/10000/No limit). Input is normalized (e.g. spaces in numbers ignored) and validated.
- Writes to `Pal/Saved/Config/LinuxServer/PalWorldSettings.ini` (default install path `/home/steam/palserver`).
- Optionally restarts the server when done.

Run after install or anytime you want to change server settings:

```bash
sudo ./config-palworld.sh
```

Optional: `PAL_INSTALL_DIR=/home/steam/palserver` if you used a different install path.

### Modes and settings controls

- **Simple mode (default):** Choose **casual** | **normal** | **hard** | **hardcore**. One preset is written; no per-setting prompts.
- **Advanced mode:** Custom difficulty; every setting is prompted with a tip, default, and (where applicable) min/max range. Use when you need fine-grained control (e.g. exact EXP rate, autosave interval, raid events on/off, predator Pals on/off).

Some settings (Random Pal Mode, RandomizerSeed, bIsRandomizerPalLevelRandom, bHardcore, bPalLost, bCharacterRecreateInHardcore) **must be set before the first world creation**; they cannot be applied retroactively. The main install script (`palworld.sh`) and preset scripts prompt for these during setup. For custom config at setup time, use **palworld-custom.sh**.

---

## Configuration parameters reference

Source: [Configuration parameters \| Palworld Server Guide](https://docs.palworldgame.com/settings-and-operation/configuration) (0.7.1). The following is a short reference; the official page is the authority.

| Category | Parameters (examples) |
|----------|------------------------|
| **Performances** | BaseCampMaxNumInGuild, BaseCampWorkerMaxNum, ItemContainerForceMarkDirtyInterval, MaxBuildingLimitNum, ServerReplicatePawnCullDistance |
| **Server management** | AdminPassword, bAllowClientMod, bIsShowJoinLeftMessage, bIsUseBackupSaveData, ChatPostLimitPerMinute, CrossplayPlatforms, LogFormatType, PublicIP, PublicPort, RCONEnabled, RCONPort, RESTAPIEnabled, RESTAPIPort, ServerDescription, ServerName, ServerPassword, ServerPlayerMaxNum |
| **Features** | AutoResetGuildTimeNoOnlinePlayers, bAllowEnhanceStat_*, bAllowGlobalPalboxExport/Import, bAutoResetGuildNoOnlinePlayers, bBuildAreaLimit, bCharacterRecreateInHardcore, bEnableFastTravel, bEnableFastTravelOnlyBaseCamp, bEnableInvaderEnemy, bExistPlayerAfterLogout, bHardcore, bIsRandomizerPalLevelRandom, bIsStartLocationSelectByMap, bShowPlayerList, RandomizerSeed, RandomizerType |
| **Game balances** | BlockRespawnTime, bPalLost, BuildObjectDamageRate, BuildObjectDeteriorationDamageRate, CollectionDropRate, CollectionObjectHpRate, CollectionObjectRespawnSpeedRate, DayTimeSpeedRate, DeathPenalty, EnemyDropItemRate, EquipmentDurabilityDamageRate, ExpRate, GuildPlayerMaxNum, ItemCorruptionMultiplier, ItemWeightRate, NightTimeSpeedRate, Pal/Player damage and regen rates, PalCaptureRate, PalEggDefaultHatchingTime, PalSpawnNumRate, SupplyDropSpan, etc. |

API schema (for programmatic settings): [REST API – Get server settings](https://docs.palworldgame.com/api/rest-api/settings).

---

## In-game admin commands

Admin commands are run **from within the game**: press **Enter** and type the command. You must set **AdminPassword** in `PalWorldSettings.ini` (or during install) and then run **`/AdminPassword <password you set>`** in-game once to gain administrative privileges.

Source: [Commands \| Palworld Server Guide](https://docs.palworldgame.com/settings-and-operation/commands#how-to-exec-command).

| Command | Description |
|---------|-------------|
| `/AdminPassword <password>` | Obtain admin privileges using the password set in config. |
| `/Shutdown [Seconds] [MessageText]` | Shut down the server; optional delay and message to players. |
| `/DoExit` | Force stop the server. |
| `/Broadcast <MessageText>` | Send a message to all players. |
| `/KickPlayer <SteamID>` | Kick a player. |
| `/BanPlayer <SteamID>` | Ban a player. |
| `/UnBanPlayer <SteamID>` | Unban a player. |
| `/TeleportToPlayer <SteamID>` | Teleport yourself to that player. |
| `/TeleportToMe <SteamID>` | Teleport that player to you. |
| `/ShowPlayers` | Show all connected players. |
| `/Info` | Show server information. |
| `/Save` | Save the world data. |
| `/ToggleSpectate` | Toggle spectator mode (use \\ to switch). |

If AdminPassword is not set in the config, these commands will not work. The install script prompts for an admin password; you can skip and set it later in `PalWorldSettings.ini`, then restart the server.

---

## REST API (WIP)

Palworld provides a [REST API](https://docs.palworldgame.com/api/rest-api/palwold-rest-api) for server info, player list, settings, metrics, announce, kick/ban, save, shutdown, etc. It is **not** designed to be exposed directly to the Internet.

**WARNING:** Only enable the REST API for **LAN** use. Publishing it directly to the Internet may result in unauthorized manipulation of the server and interfere with play.

To use the API, set **`RESTAPIEnabled=True`** in your server configuration (e.g. when prompted during `palworld.sh` install, or via `config-palworld.sh`). Authentication uses HTTP Basic Auth. Integration guides and automation (e.g. dashboards, backups via API) are **WIP** in this repo.

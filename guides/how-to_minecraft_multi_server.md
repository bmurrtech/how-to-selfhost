# How-to Minecraft Multi-Server with Crafty Web UI

Crafty is a **free, open-source** web UI for managing self-hosted Minecraft servers. It gives you a professional control panel similar to paid Minecraft hosting sites — dashboard, terminal, file editor, and metrics — all from your browser.

---

## Table of Contents

- [What You'll Learn](#what-youll-learn)
- [Install Crafty](#install-crafty)
- [Import a Modded Server into Crafty](#import-a-modded-server-into-crafty)
- [Run Multiple Minecraft Servers](#run-multiple-minecraft-servers)
- [FTB Server (Standalone Install)](#ftb-server-standalone-install)
- [Minecraft Server Settings](#minecraft-server-settings)
- [Useful Minecraft Server Commands](#useful-minecraft-server-commands)
- [Minecraft Forge Server (Vanilla) — WIP](#minecraft-forge-server-vanilla--wip)

---

## What You'll Learn

- Create and manage modded Minecraft servers
- Use Crafty's web UI to control servers remotely (via reverse proxy)
- Run multiple Minecraft servers on the same machine
- Configure whitelists, ops, and server properties

### Crafty at a glance

| Feature | Description |
|---------|-------------|
| **Dashboard** | Start/stop servers, view status |
| **Terminal** | Run Minecraft commands in-browser |
| **File editor** | Edit configs without SSH |
| **Metrics** | RAM, CPU, player count |

![Crafty Dashboard](https://i.imgur.com/k6Oqvfe.png)
*Crafty Dashboard*

![Crafty Terminal](https://i.imgur.com/gtBrDi3.png)
*Crafty Terminal (for Minecraft server commands)*

![Crafty File Editor](https://i.imgur.com/cetW09C.png)
*Crafty File Editor*

![Crafty Server Metrics](https://i.imgur.com/rdz55vv.png)
*Crafty Server Metrics*

---

## Install Crafty

> **Reference:** [Crafty Linux Installer Guide](https://docs.craftycontrol.com/pages/getting-started/installation/linux/) — check their docs for the latest changes.

**Prerequisites:** Linux VPS or VM (e.g. Ubuntu). [Proxmox cloud-init guide](how-to_ultimate_proxmox.md) for VM creation.

### Steps

1. **Create a `crafty` user**
   ```bash
   sudo useradd crafty -s /bin/bash
   sudo mkdir /home/crafty/server
   sudo chown -R crafty:crafty /home/crafty
   cd /home/crafty
   ```

2. **Run the installer**
   ```bash
   git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git && \
     cd crafty-installer-4.0 && \
     sudo ./install_crafty.sh
   ```

3. **Access Crafty**
   - Open `http://<server-IP>:8443` (e.g. `192.168.1.57:8443`)

4. **Get default credentials**
   ```bash
   cat /home/crafty/crafty-4/app/config/default-creds.txt
   ```
   Copy the password, log in, and **change it immediately**. See [Crafty's access docs](https://docs.craftycontrol.com/pages/getting-started/access/).

> **Security note:** Default credentials are now a unique 64-character string due to recent attacks targeting Crafty. Always change the password after first login.

---

## Import a Modded Server into Crafty

This method gives you control over the install directory, which is important for importing FTB and other custom modpacks.

### Steps

1. **Create a new server in Crafty** — choose the same Minecraft/Java versions as your modpack.

   ![createcraftyserver](https://i.imgur.com/ALFTb2v.png)

2. **Note the server folder path** — Crafty > Config > folder path (e.g. `/home/crafty/crafty-4/servers/<name>`).

   ![folderpathtoFTBGenesis](https://i.imgur.com/Gmr2980.png)

3. **On the Linux host**, navigate to that folder and clear it:
   ```bash
   cd /home/crafty/crafty-4/servers/<nameoffoldercraftymade>
   rm -r *
   ```

4. **Download the modpack installer** (example: FTB Genesis)
   ```bash
   wget https://api.modpacks.ch/public/modpack/120/11425/server/linux
   mv linux serverinstall_120_11425
   chmod +x serverinstall_120_11425
   ./serverinstall_120_11425
   ```
   When prompted, hit `ENTER` and `y` to install into the current directory.

5. **Configure Crafty for the modpack**
   - Get the Java execution string from the modpack's `start.sh`:
     ```bash
     cat start.sh
     ```
   - Copy the `java ... nogui` line into Crafty > Config > **Server Execution Command**
   - Set **Server Executable** to the `.jar` file (e.g. `minecraft_server.1.19.2.jar`)
   - Click **Update Executable** first, then **Save**

6. **Start the server** — Dashboard > Play. Accept the EULA if prompted.

---

## Run Multiple Minecraft Servers

You can run multiple Minecraft servers on the same machine if your CPU and RAM can handle it. Crafty makes this straightforward.

1. **In Crafty:** Server > Config > **Server Port** — set a different port (e.g. `25566` instead of `25565`).

   ![multimc1](https://i.imgur.com/qh7vmdZ.png)

2. **In `server.properties`:** Change `server-port=` to match.

   ![mulitmc2](https://i.imgur.com/YxH0A9o.png)

3. **Port forward** the new port on your router firewall.

4. **Connect:** Use `IP:<port>` (e.g. `192.168.1.57:25566`).

![proofofmultimcservers](https://i.imgur.com/HsIAjkD.png)
*Example: multiple Minecraft servers in Crafty*

---

## FTB Server (Standalone Install)

Use this section if you want an FTB server **without** Crafty — direct install on the host.

### Prerequisites

- Ubuntu VM (e.g. [Proxmox cloud-init](how-to_ultimate_proxmox.md))
- **4–6 GB RAM** (check modpack recommendations)

### Provision resources

![ftbgenesis](https://i.imgur.com/P4u6QnB.png)
*FTB Genesis: 4 GB min, 6 GB recommended*

### Install steps

1. **Create a user**
   ```bash
   sudo useradd -m -s /bin/bash ftbgenesis
   passwd ftbgenesis
   sudo usermod -aG sudo ftbgenesis
   su - ftbgenesis
   ```

2. **Download the modpack installer**
   - From [FTB](https://www.feedthebeast.net/): Modpack > Versions > Server Files > copy URL for your OS/CPU
   - Example (FTB Genesis Linux x64):
     ```bash
     cd /home/ftbgenesis && mkdir server && cd server
     wget https://api.modpacks.ch/public/modpack/120/11425/server/linux
     mv linux serverinstall_120_11425
     chmod +x serverinstall_120_11425
     ./serverinstall_120_11425
     ```
     When prompted: `ENTER`, `y`, `y`.

3. **Make start script executable**
   ```bash
   chmod +x start.sh
   ```

4. **Run** `./start.sh` and accept the EULA with `y`.

### Systemd auto-start

Create `/etc/systemd/system/minecraft.service`:

```ini
[Unit]
Description=Minecraft FTBGenesis Server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Type=simple
User=ftbgenesis
Group=ftbgenesis
StandardOutput=append:/var/log/minecraft.log
StandardError=append:/var/log/minecraft.err
Restart=on-failure
ExecStart=/home/ftbgenesis/server/start.sh
WorkingDirectory=/home/ftbgenesis/server/
TimeoutSec=240

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable minecraft
sudo systemctl start minecraft
```

### Troubleshooting: Insufficient memory

Edit `user_jvm_args.txt` or `start.sh` and adjust `-Xmx` / `-Xms` to match your RAM (e.g. `-Xmx4G -Xms2G` for 4 GB).

---

## Minecraft Server Settings

> You must be in the server folder (or use Crafty's file editor) to access these files.

### Whitelist

- In `server.properties`: set `white-list=true`
- In `whitelist.json`:
  ```json
  [
    { "uuid": "f430dbb6-5d9a-444e-b542-e47329b2c5a0", "name": "username" },
    { "uuid": "e5aa0f99-2727-4a11-981f-dded8b1cd032", "name": "username2" }
  ]
  ```
  > Tip: Use [Minecraft UUID Converter](https://mcuuid.net/) to find UUIDs.

### Operator (admin) in-game

Add yourself to `ops.json` to use commands like `/whitelist add`:

```json
{
  "uuid": "389c92c7-eb5c-4a15-92b8-01a27348ac63",
  "name": "your_username",
  "level": 4,
  "bypassesPlayerLimit": false
}
```

---

## Useful Minecraft Server Commands

| Action | Command |
|--------|---------|
| Whitelist player | `/whitelist add <username>` |
| Ban player | `/ban <username>` |
| Ban IP | `/ban-ip <IP>` |
| Unban | `/pardon <username>` |
| View ban list | `/banlist` |
| Give admin | `/op <username>` |
| Remove admin | `/deop <username>` |
| Gamerules | `/gamerule <rule> <value>` |
| Save world | `/save-all` |
| Diagnostics | `/perf` |
| PM player | `/msg <username> <message>` |
| Teleport | `/tp <username>` |
| Stop server | `/stop` |

---

## Access Crafty Web UI Remotely

To manage Minecraft servers from outside your LAN, use a **reverse proxy** or **secure tunnel** — don't expose Crafty's port directly to the internet.

| Option | Description |
|--------|-------------|
| **Cloudflare Tunnels** | [Deploy guide](how-to_ultimate_proxmox.md#remote-access) — zero trust, no open ports |
| **Tailscale** | Mesh VPN; access Crafty via Tailscale IP |
| **NGINX + Let's Encrypt** | Traditional reverse proxy (requires more setup) |

---

## Crafty Auto-Start on Boot

```bash
sudo systemctl enable crafty.service
```

In Crafty: Server > Config > toggle **Server Auto Start** (bottom of page).

### Bypass Crafty auto-start (optional)

If Crafty's auto-start fails, create a systemd service for the server directly. Note: server stats won't show in Crafty.

Example `/etc/systemd/system/ftbskies.service`:

```ini
[Unit]
Description=Minecraft FTB Skies
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Type=simple
User=crafty
Group=crafty
StandardOutput=append:/var/log/ftbskies.log
StandardError=append:/var/log/ftbskies.err
Restart=on-failure
ExecStart=/home/crafty/crafty-4/servers/<folder-name>/start.sh
WorkingDirectory=/home/crafty/crafty-4/servers/<folder-name>
TimeoutSec=240

[Install]
WantedBy=multi-user.target
```

---

## Minecraft Forge Server (Vanilla) — WIP

> This section is a work in progress. It covers a clean Forge install without a modpack installer (e.g. FTB).

**Requirements:**
- Choose Minecraft + Forge versions in advance
- Replace version-specific commands below

### Install Java 8

```bash
sudo apt install openjdk-8-jdk
java -version
# Switch versions if needed:
sudo update-alternatives --config java
```

### Prepare environment

```bash
sudo apt update && apt -y upgrade
sudo apt install screen
sudo useradd -m minecraft
sudo passwd minecraft
su - minecraft
mkdir -p /opt/modserver && cd /opt/modserver
```

### Download Forge installer

- Get the Forge installer JAR from [files.minecraftforge.net](https://files.minecraftforge.net/)
- Run the installer and follow prompts for server setup

*(Guide continues in a future update.)*

---

## References

- [Crafty documentation](https://docs.craftycontrol.com/)
- [FTB server install guide](https://feedthebeast.notion.site/Installing-a-Feed-the-Beast-Server-aeaea8a7220945d0ad0357c80c6c9d12)
- [Minecraft Wiki — dedicated server](https://minecraft.wiki/w/Tutorials/Creating_a_Minecraft_server)

# How-to Pterodactyl Multi-Game Server Manager

Pterodactyl is a game server manager with a web UI for creating and managing multiple game servers. If your server is dedicated to games and you want the versatility of adding, removing, and running different game servers on one dedicated VPS or VM, this guide is for you.

---

## Table of Contents

- [Automated Pterodactyl Install Method](#automated-pterodactyl-install-method)
- [Manual Pterodactyl Install Method](#manual-pterodactyl-install-method)

---

## Automated Pterodactyl Install Method

Pterodactyl has multiple dependencies (Let's Encrypt, MySQL, etc.), which complicates installation. Thanks to the gaming community, **vilhelmprytz** created an automated bash script that makes installing Pterodactyl straightforward.

### Resources

| Resource | Link |
|----------|------|
| **Unofficial installer** | [Pterodactyl installer on GitHub](https://github.com/pterodactyl-installer/pterodactyl-installer) |
| **Video walkthrough** | [SoulStriker's tutorial](https://www.youtube.com/watch?v=E2hEork-DYc) |

> **Disclaimer:** This repo has not verified whether the bash script is malicious. If you are concerned about potential malware or boot/root-kits, exercise zero trust and read through the source code before running. Otherwise, choose between convenience and [manually installing Pterodactyl yourself](#manual-pterodactyl-install-method).

### Prerequisites

- [Portainer installed](how-to_ultimate_proxmox.md#portainer) as your Docker container manager

### Steps

1. **Create an Ubuntu container**
   - In Portainer: `Local > Home > App Templates > Select Ubuntu` from the list
   - Name the container **Pterodactyl**
   - Set Network to **bridge**
   - Grant access control to **administrators**
   - Click **Deploy the container** (status should show "running")

2. **Connect to the container console**
   - `Containers > Click container name > Console > Connect (as root)`

   ![port_console](https://i.imgur.com/DBiQF3w.png)

3. **Update and install curl**
   ```bash
   apt update && apt upgrade -y
   apt install curl
   ```

4. **Run the vilhelmprytz install script**
   ```bash
   bash <(curl -s https://pterodactyl-installer.se)
   ```

5. **Follow the prompts**
   - Install both **panel** and **wings** — enter `2`
   - Choose usernames and passwords for panel access and admin
   - Enter your timezone (e.g. `America/Chicago`, `America/New_York`)
   - Enter your FQDN for the panel

   > **FQDN help:** Use your server's public IP, or create an `A` record pointing to it (e.g. Type: A, Name: panel, Content: [serverIP], Proxy: DNS only/off, TTL: 1 min).

   - Agree with `y` to prompts (UFW, MySQL, auto config, etc.)
   - Install wings and allow automatic configurations
   - Panel address: same FQDN as above
   - Allow traffic on port `3306`

   > **Important:** Ensure ports **3306** and **2022** are open on your router or VPS firewall.

   - Create username and password for the Pterodactyl database when prompted

### Troubleshooting

| Issue | Action |
|-------|--------|
| "Host is down" | Restart the container. Check: `systemctl list-units --type=service` |
| Can't access web UI | Verify Portainer publishes the required ports for panel access. Research Pterodactyl's port requirements. |

---

## Manual Pterodactyl Install Method

If you prefer not to run an unofficial bash installer and want more control over the installation, follow [TechnoTim's Pterodactyl install using Docker](https://www.youtube.com/watch?v=_ypAmCcIlBE).

### Prerequisites

- [Portainer installed](how-to_ultimate_proxmox.md#portainer)

### Steps

1. **Get the Docker Compose file**
   - Fetch `docker-compose-example.yml` from [Pterodactyl's official GitHub](https://github.com/pterodactyl/panel/blob/develop/docker-compose.example.yml)
   - Modify according to [TechnoTim's config](https://www.youtube.com/watch?v=_ypAmCcIlBE) if using Cloudflare reverse proxy

2. **Example `docker-compose.yml` snippet**

   ```yaml
   version: '3.8'
   x-common:
     database:
       &db-environment
       MYSQL_PASSWORD: &db-password "CHANGE_ME"
       MYSQL_ROOT_PASSWORD: "CHANGE_ME_TOO"
     panel:
       &panel-environment
       APP_URL: "http://example.com"
       APP_TIMEZONE: "UTC"
       # ... (see official example for full config)

   services:
     database:
       image: mariadb:10.5
       # ...
     panel:
       image: ghcr.io/pterodactyl/panel:latest
       # ...
   ```

3. **Create an admin user** (no user is created by the `.yml` by default)
   ```bash
   docker-compose run --rm panel php artisan p:user:make
   ```
   Follow the on-screen prompts, then log in to the Pterodactyl web UI.

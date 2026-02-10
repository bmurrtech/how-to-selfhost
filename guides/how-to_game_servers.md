License: MIT (see [LICENSE.md](LICENSE.md)).

# Table of Contents
- [How-to Pterodactyl Multi-game Server Manager](#pterodactyl)
- [How-to Satisfactory Gamer Server](#satisfactory)
- [How-to ARK Survival Evolved Game Server](#ark)
- [How-to Modded Minecraft Server + Crafty Web Mangement UI](#modded-minecraft-with-crafty-web-ui)
- [How-to Run Multiple Minecraft Servers on Same Machine](#run-simultaneous-minecraft-servers)
- [How-to FTB Server](#ftb-minecraft-server)
- [Edit Minecraft Server Settings](#minecraft-server-settings)
- [Useful Minecraft Server Commands](#useful-minecraft-server-commands)

# Pterodactyl
Pterodactly is a game server manager with a web UI for creating and managing mulitple game servers. If your server is dedicated for games, and you want the versatility of adding/removing/running different game servers on one dedicated VPS or VM, I reccommend installing it.

There are multiple dependencies required by Pterodactly, from Let's Encrypt to a MySQL database which complicates installation; however, thanks to the amazing gaming comminity, vilhelmprytz has created an automated `bash` script to make installing Pterodactyl a breeze!

### Automated Pterodactyl Install Method

__Resources__:
- See the __unofficial__ Pterodactyl script by vilhelmprytz on his: [Github](https://github.com/pterodactyl-installer/pterodactyl-installer)
- And watch [SoulStriker's tutorial video](https://www.youtube.com/watch?v=E2hEork-DYc) on how to use vilhelmprytz installer script.

> Disclaimer: I have not verified if this `bash` script is malicious or not. Nor have I checked the Pterodactl code. If you are concerned about potential malware or boot/root-kits, exercise zero trust and read through source code line by line to verify nothing is malicous. If this is not worth it, you have to make a choice between convenience and manually installing Pterodactyl yourself.

__Start of My Guide__
- For starters, I'm installing Portainer as my Docker container manager. Open a new tab and [follow my Portainer install guide here](how-to_ultimate_proxmox.md#portainer) and come back to this guide.
- With Portainer installed, login and navigate to:

```
Local > Home > App Templates > Select Ubuntu from list
```

- Name the container __Pterodactyl__ and set the Network to __bridge__.
- Grant access conrol to __administrators__
- Click "Deploy the container" button (you should see a "running" status).
- Now, access the __console__ of the new container:

```
Containers > Click Name of Container > Console > Connect (as root)
```

![port_console](https://i.imgur.com/DBiQF3w.png)

- As root, you don't have to use `sudo`, but we want to update and install `curl` in the container first:

```
apt update && apt upgrade -y
apt install curl
```

- Next, run the `bash` install script from vilhelmprytz:

```
bash <(curl -s https://pterodactyl-installer.se)
```

- Choose to install both the __panel__ and __wings__ by entering __2__.
- Enter two separate, preferred usernames and passwords for both the panel access and the admin account (this will be used to access the Pterodactyl web UI in a moment).
- Enter you time zone (ex. `America/Chicago`, `America/New_York`)
- Enter your FQDN for the panel.

> If you don't know what an FQDN is, use your server's public IP address or create `A` name records pointing to your server's public IP address (ex. Type: A, Name: panel, Conent: [serverIP], Proxy status: DNS only/off, TTL: 1min).

- Agree with `y` to all the prompts (i.e. ufw, MySQL, auto config user, etc.) with `y` to continue with the installation.
- Agree to install wings and all the automatic configurations (i.e. UFW, MySQL, database hosts, etc.).
- Ener the panel address (same as the FQDN you enter previously).
- Agree to allow traffic on port `3306`.

> Note: You must ensure that port `3306` and `2022` is open on your router or VPS firewall, too!

- You will be prompted to make a username and password for the pterodactyl database, also.

__Troubleshooting__
- If you get a response stating that the "host is down" something went wrong. Try restarting the container and enter the following to test:

```
sytemctl lsit-units --type=service
```

- Research the required ports to run Pterodactyl and ensure that the Portainer Dockerized netowrk is publishing those necessary ports for panel web UI access.

__WIP__


#### Manual Pterodactyl Install Method

If you are more concerned about security and running an unofficial `bash` installer script, then start with [TechnoTim's Pterodactyl install using Docker](https://www.youtube.com/watch?v=_ypAmCcIlBE&pp=ygUacHRlcm9kYWN0eWwgcGFuZWwgaW5zdGFsbCA%3D)

- For starters, I'm installing Portainer as my Docker container manager. Open a new tab and [follow my Portainer install guide here](how-to_ultimate_proxmox.md#portainer) and come back to this guide.
- Now, we need the contents of Pterodactyl's `docker-compose.yml`.
- I'm grabbing the `docker-compose-example.yml` [from Pterodactyl's official Github](https://github.com/pterodactyl/panel/blob/develop/docker-compose.example.yml)
- Next, I have modified the contents of the default `.yml` file according to [TechnoTim's Pterodactyl config](https://www.youtube.com/watch?v=_ypAmCcIlBE&pp=ygUacHRlcm9kYWN0eWwgcGFuZWwgaW5zdGFsbCA%3D) to enable my reverse proxy service with Cloudflare to work with Pterodactyl.

```
version: '3.8'
x-common:
  database:
    &db-environment
    # Do not remove the "&db-password" from the end of the line below, it is important
    # for Panel functionality.
    MYSQL_PASSWORD: &db-password "CHANGE_ME"
    MYSQL_ROOT_PASSWORD: "CHANGE_ME_TOO"
  panel:
    &panel-environment
    APP_URL: "http://example.com"
    # A list of valid timezones can be found here: http://php.net/manual/en/timezones.php
    APP_TIMEZONE: "UTC"
    APP_SERVICE_AUTHOR: "noreply@example.com"
    # Uncomment the line below and set to a non-empty value if you want to use Let's Encrypt
    # to generate an SSL certificate for the Panel.
    # LE_EMAIL: ""
  mail:
    &mail-environment
    MAIL_FROM: "noreply@example.com"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"

#
# ------------------------------------------------------------------------------------------
# DANGER ZONE BELOW
#
# The remainder of this file likely does not need to be changed. Please only make modifications
# below if you understand what you are doing.
#
services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "/srv/pterodactyl/database:/var/lib/mysql"
    environment:
      <<: *db-environment
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"
  cache:
    image: redis:alpine
    restart: always
  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "80:80"
      - "443:443"
    links:
      - database
      - cache
    volumes:
      - "/srv/pterodactyl/var/:/app/var/"
      - "/srv/pterodactyl/nginx/:/etc/nginx/http.d/"
      - "/srv/pterodactyl/certs/:/etc/letsencrypt/"
      - "/srv/pterodactyl/logs/:/app/storage/logs"
    environment:
      <<: [*panel-environment, *mail-environment]
      DB_PASSWORD: *db-password
      APP_ENV: "production"
      APP_ENVIRONMENT_ONLY: "false"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
      DB_HOST: "database"
      DB_PORT: "3306"
networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

- Since no user was created via the `.yml` file, we need to run a specific command to set one so we can access the Pterodactyl web UI. Run the following command to create an admin user:

```
docker-compose run --rm panel php artisan p:user:mak
```

- Follow the on-screen prompts to create an admin user.
- Once completed, try to login to your Pterodactyl web UI (ex. https://x.x.x.x:xxxx).

__WIP__

# Satisfactory
[Ref. video](https://www.youtube.com/watch?v=b4ZrXxJ_DcM)

- __Create a VM__ running Ubuntu server. Ideally, clone a VM from a [cloud init 20.04 on Proxmox hypervisor](how-to_ultimate_proxmox.md)!

- __Allocate 12-16GB of RAM__ to the VM

- __Install dependencies as `root`__:

> Ensure you run commands as `root` or `admin` with proper permission level. Type `sudo -i` to switch to root user. Note: Some servers disable `root` by default, therefore, you need to give your user account root/admin permissions to run the commands required for a _64-bit machine_.

```
sudo add-apt-repository multiverse
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
sudo apt update && apt -y upgrade
sudo apt install lib32gcc1
```

- __Check the firewall__ settings:

```
sudo ufw status
```

- If the firewall settings return: `Status: inactive` then __enable it and open up the right ports__.
- __Open up the port__ that is __specific to Satisfactory__ as follows:

```
sudo ufw allow 15777
sudo ufw allow 22
sudo ufw enable
sudo ufw status
```

> The status should report port 22 as `ALLOW`.

- __Create a Steam user__ (must run as admin)

```
sudo useradd -m -s /bin/bash steam
```

- __Set/create a password__

```
sudo passwd steam
```

```
sudo -s
usermod -aG sudo steam
su - steam
```

- __Install `steamcmd`__:

```
sudo apt-get install steamcmd
```

> Learn more about `steamcmd` and how it functions from the [Steam developer Wiki](https://developer.valvesoftware.com/wiki/SteamCMD)

- __Login as `steam` user__:

```
su - steam
```

- Choose your path 1) [Make the sever start automatically on boot](#automatically-start-satisfactory-server) or 2) [Start the server manually every time](#manually-start-satisfactory-server). See paths below:

### Automatically Start Satisfactory Server
In order to make the server start on boot automatically, you have to create a custom `systemd` service file. Systemd is the service management system installed for many Linux distributions. You can read more about the concepts of `systemd` [service files here](https://docs.linuxgsm.com/configuration/running-on-boot). Thankfully, the [SatisfactoryWiki already created the service file](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service) for gamers to implement. Here's how to do it:

- First, __login as an admin user__ (required for `sudo` to work when creating a `service.file`).
- __Make a link__ from `/user/steam/steamcmd` to /home/steam/:

```
ln -s /usr/games/steamcmd steamcmd
```

- __Create a new service file__ for Satisfactory:

```
sudo nano /etc/systemd/system/satisfactory.service
```

- __Copy & paste__ the following contents into the new file:

```
[Unit]
Description=Satisfactory dedicated server
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Environment="LD_LIBRARY_PATH=./linux64"
ExecStartPre=/home/steam/steamcmd +force_install_dir "/home/steam/sfserver" +login anonymous +app_update 1690800 validate +quit
ExecStart=/home/steam/sfserver/FactoryServer.sh
User=steam
Group=steam
StandardOutput=append:/var/log/satisfactory.log
StandardError=append:/var/log/satisfactory.err
Restart=on-failure
WorkingDirectory=/home/steam/sfserver
TimeoutSec=240

[Install]
WantedBy=multi-user.target
```

- __Save it__:

```
CTRL + X, Y, ENTER
```

> Note: If you changed the username or decided to run the non-experimental server, you will need to change this service file to reflect your customized configuration. See the [raw service file template from the SatisfactoryWiki for refrence.](https://satisfactory.fandom.com/wiki/Dedicated_servers/Running_as_a_Service)


- After creating the service, you will need to __execute a daemon-reload__ to load the new `service.file` into systemd. To keep the server running enter:

```
sudo systemctl daemon-reload
```

- To __start the Satisfactory server__, enter the following to commands:

```
sudo systemctl start satisfactory
```

- You can __check the running status__ with:

```
sudo systemctl status satisfactory.service
```

- If configured correctly, the output should look something like:

```
● satisfactory.service - Satisfactory dedicated server
     Loaded: loaded (/etc/systemd/system/satisfactory.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2021-11-02 15:30:13 CET; 2min 21s ago
   Main PID: 2529 (FactoryServer.s)
      Tasks: 24 (limit: 7053)
     Memory: 8G
        CPU: 4min 5.965s
     CGroup: /system.slice/satisfactory.service
             ├─2529 /bin/sh /home/steam/sfserver/FactoryServer.sh
             └─2536 /home/steam/sfserver/Engine/Binaries/Linux/UE4Server-Linux-Shipping FactoryGame
```

- To stop/restart the server, enter:

```
sudo systemctl stop satisfactory
sudo systemctl restart satisfactory
```

- Once your server is up and running, you can create a `screen` and monitor the log in real-time with a `tail` command:

```
# monitor the log file
tail -n3 -f /var/log/satisfactory.log

# monitor the log file
tail -n3 -f /var/log/satisfactory.err
```

### Joining the Satisfactory Server for the First Time

- Now, __open you copy of the game__, and __navigate to "Server Manager"__ in the game.

- You will be prompted to __enter the local IP address of the machine running the server__ (check your router DHCP server IPs and set it to a static IP so it doesn't change in the future) and the port # `15777`. Hit `Confrim`.

- __Enter a name__ for your server, and __set an admin password__.
- __Create a new game__ from the Satisfactory Server GUI
- __Configure your server settings__ as you wish
- __Click `Create Game`__ and __enter a unique session name__

> If you get a `timeout error`, just wait for the server to finish creating.

### Manually Start Satisfactory Server

- __Invoke the `steamcmd` to install the Satisfactory server__ in this new `steam` user directory/folder as follows:

```
steamcmd
force_install_dir /home/steam/sfserver/
login anonymous
app_update 1690800 -validate
```

> You can also run it as one line:
> ```
> steamcmd +force_install_dir /home/steam/sfserver/ +login anonymous +app_update 1690800 validate +quit
> ```
> Change the line after `+login anonymous` to `+app_update 1690800 -beta experimental +quit` if you want to install the experimental gamer server version.

- __Wait for__ the __downloads and processes to complete__. Depending on the size of the download, it may take awhile, but you should see a message such as: _"Sucecss! App '1690800' fully installed."_


- We could start the server as-is, right now (see below on how) __BUT if you want the Satisfactory server to start AUTOMATICALLY on boot__, then you'll want to follow the steps outlined in [this section](###satisfactory-server-start-on-reboot):

> ```
> cd /home/steam/sfserver
> ls
> ```
> - __Finding the bash file `FactoryServer.sh`__ or similar and run it:
> ```
> screen -S sfserver
> cd sfserver
> ./FactoryServer.sh
> ```
> This will start the actual Satisfactory game server with logs inside a `screen`.
> - On the Linux server screen, you can __type `CTRL + A, D`__ to _close out the screen_. See [more details about screen here](https://www.tecmint.com/screen-command-examples-to-manage-linux-terminals/).
> ```
> # to see running screens/servers
> screen -ls
> # to bring the server screen back up
> screen -r [screen_name]
> # to kill the server
> CTRL + A,  K
> ```

__FIN__


# ARK
- [Ref video for ARK](https://www.youtube.com/watch?v=oPN08QKYGvg)
- [Ref ARK Wiki](https://ark.fandom.com/wiki/Dedicated_server_setup)

- __Create a VM__ running Ubuntu server. Ideally, clone a VM from a [cloud init 20.04 on Proxmox hypervisor](how-to_ultimate_proxmox.md)!

- __Allocate 12-16GB of RAM__ to the VM

- __Configure/optomize settings for the Ark gameserver__:

```
echo "fs.file-max=100000" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
echo "*soft nofile 100000" >> /etc/security/limits.conf
echo "*hard nofile 100000" >> /etc/security/limits.conf
ulimit -n 100000
```

- __Install dependencies as `root`__:

> Ensure you run commands as `root` or `admin` with proper permission level. Type `sudo -i` to switch to root user. Note: Some servers disable `root` by default, therefore, you need to give your user account root/admin permissions to run the commands required for a _64-bit machine_.

```
sudo add-apt-repository multiverse
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
sudo apt update && apt -y upgrade
sudo apt install lib32gcc1
```

- __Create a Steam user__ (must run as admin)

```
sudo useradd -m -s /bin/bash steam
```

- __Set/create a password__

```
sudo passwd steam
```

```
sudo -s
usermod -aG sudo steam
su - steam
```

- __Check the firewall__ settings:

```
sudo ufw status
```

- If the firewall settings return: `Status: inactive` then __enable it and open up the right ports__.
- __Open up the port__ that is __specific to Satisfactory__ as follows:

```
sudo ufw allow 22
sudo ufw allow 7777
sudo ufw allow 7778
sudo ufw allow 27015
sudo ufw enable
sudo ufw status
```

> The status should report ports as `ALLOW`.

- Also, __don't forget to port forward `7777`, `7778`, and `27015` TCP and UDP on your router__.

- __Install `steamcmd`__:

```
sudo apt-get install steamcmd
```

- Progress through the installer screen that pops up (select `OK` and agree to terms).

> Learn more about `steamcmd` and how it functions from the [Steam developer Wiki](https://developer.valvesoftware.com/wiki/SteamCMD)

- __Login as `steam` user__:

```
su - steam
```

- __Make a link__ from `/user/steam/steamcmd` to /home/steam/:

```
ln -s /usr/games/steamcmd steamcmd
```

- Download and install the ARK game server from Steam:

```
steamcmd +login anonymous +force_install_dir /home/steam/arkserver +app_update 376030 +quit
```

> Depending on your internet speed and server specs, download and install times will vary. _Wait until the entire installation process completes_ before continuing. You should see a message like, "Success! App fully installed."

### Create an Ark `systemd` Service file
This `systemd` file will make the ARK server start automatically on boot.

- First, __login as an admin user__ (required for `sudo` to work when creating a `service.file`).

> Note: After running this command, you should see a new directory in `/home/steam/arkserver` called `steamcmd`

-__Create a new service file__ for Ark

```
sudo nano /etc/systemd/system/ark.service
```

- __Copy & paste__ the following contents into the new file:

```
[Unit]
Description=ARK Survival Evolved
Wants=network-online.target
After=syslog.target network.target nss-lookup.target network-online.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
User=steam
Group=steam
ExecStartPre=/home/steam/steamcmd +force_install_dir /home/steam/arkserver +login anonymous +app_update 376030 +quit
ExecStart=/home/steam/arkserver/ShooterGame/Binaries/Linux/ShooterGameServer TheIsland?listen?SessionName=ArkServer -server -log -NoBattlEye
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s INT $MAINPID
WorkingDirectory=/home/steam/arkserver/ShooterGame/Binaries/Linux
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
```

> To be cross compatiable with the EPIC game launcher, add `-NoBattlEye` after `-log` on the `ExecStart` line (note: _already included_ in the above configuration).

- __Save it__:

```
CTRL + X, Y, ENTER
```

- After creating the service, you will need to __execute a daemon-reload__ to load the new `service.file` into systemd. To keep the server running enter:

```
sudo systemctl daemon-reload
```

- Use the following commands to control your new Ark server:

```
# choose to run as the `steam` user
systemctl start ark
systemctl status ark.service

# restart or stop the server
systemctl restart ark
systemctl stop ark
```

- You can __check the running status__ with:

```
sudo systemctl status ark.service
```
- If configured correctly, the output should look something like:

```
● ark.service - Ark dedicated server
     Loaded: loaded (/etc/systemd/system/ark.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2021-11-02 15:30:13 CET; 2min 21s ago
   Main PID: 2529 (arkserver.s)
      Tasks: 24 (limit: 7053)
     Memory: 8G
        CPU: 4min 5.965s
     CGroup: /system.slice/ark.service
             ├─2529 /bin/sh /home/steam/arkserver/...
             └─2536 /home/steam/ariserver...e
```

- OPTIONAL __Set the server password__ and admin server password:

```
sudo nano /home/steam/arkserver/ShooterGame/Saved/Config/LinuxServer/GameUserSettings.ini

# add and modify these lines in the .ini file
ServerPassword=YourServerPassword
ServerAdminPassword=YourServerAdminPassword
```

> __WARNING__ If you decide to set a password for your ARK server, __Epic Games__ clients will __NOT be able to join__.

### Joining the ARK Server

#### ARK on Epic Games
- Open ARK and select the `HOST / LOCAL` option in the menu.
- Click `Play Single Player` - there is no need to edit settings or change the map as this doesn't affect you connecting to the server.
- When loaded in, press `TAB` to open the game's Console.
- In the Console, type `open [SERVER_IP]:7777`. This will then begin connecting you to your server.

> Note that your ARK server may be running on port `27015` as this is the port required by Steam, but for Epic Games, you will need to use port `7777`, to allow for direct connection to your server.

#### ARK on Steam Games
- In the _Steam client_ (not the ARK game) under _View_ (top navigation) > _Servers_, click the _Favorites_ tab.
- Add your server by clicking _Add A Server_, then entering your server address `[SEVER_IP:25017]` into the popup box and clicking _Add This Address To Favorites_.
- Open the game ARK and click _Join ARK_.
- In the bottom left corner under the filter options, _change the Session Filter to Favorites_.
- Press _refresh_, and then you should see your server and be able to join.

### ARK Server Troubleshooting

If you are expericing installation issues and errors, run through the `steamcmd` install manually in the following steps:

```
cd /home/steam/
steamcmd
force_install_dir /home/steam/arkserver
login anonymous
app_update 376030 validate
exit
```

- Now, retry the `systemctl start ark`. If you are still having issues, run a `systemctl status ark.service` and research the specific error message you have on the ARK forums and wiki for solutions.

# FTB Minecraft Server
This tutorial assumes that you already have an Ubuntu server VM ready to go -- if not, then [check out my Proxmox guide](how-to_ultimate_proxmox.md) on how to create a `cloud-init` template. 


### Provision Server Resources Appropriately
![ftbgenesis](https://i.imgur.com/P4u6QnB.png)

> As seen above, a FTB Genesis server requirements are at least `4GB` of RAM but reccomended is `6GB`. Check the recc'd servers specs for your server of choice and provision accordingly in [Proxmox](how-to_ultimate_proxmox.md). 

### FTB Server Install
> FTB Server installs are simpler because they provide installers for your CPU and OS of choice. (i.e. `.exe` for Windows and/or `.deb` or `.rpm` file for Linux).

- For ref. this guide follow the official FTB Server installer guide: https://feedthebeast.notion.site/Installing-a-Feed-the-Beast-Server-aeaea8a7220945d0ad0357c80c6c9d12

- Since we are running a Linux Ubuntu OS, we will need to open a terminal to the VM and download (or transfer) the installer to the virtural machine.

#### Create a User for Server Management

- Switch to `root` user to create and give admin rights to the new user. Enter the following series of commands:

```
sudo su
useradd -m -s /bin/bash ftbgenesis
# Check folder path of new user at:
cd /home/ftbgenesis
# Create a password for the new user:
passwd ftbgenesis
# Type in your new password for this user twice
# Add new user to admin group:
usermod -aG sudo ftbgenesis
# Switch to new user
su - ftbgenesis
```

> You can name the user whatever you like. I chose `ftbgenesis` because it fits the modpack name.

- Select one of the following options to get the modpack installer script (I think Option 1 is easiest, IMO):

#### Option 1: Download Files Directly via `wget`
- Get the URL to the installer script from the FTB website: Modpack > Versions > Server Files > Right-click appropriate OS (depends on your CPU and OS; i.e. 64-bit Linux) > Copy the URL

![ftbserverinstallersbyos](https://i.imgur.com/LWuH0o5.png)

#### Option 2: Transfer Files to VM via File Transfer Protocol
- Please refer to my FileZilla guide on how to transfer to and from your Linxu VMs [here](how-to_ultimate_proxmox.md#filezilla).

> Whatever option you choose proceed with the following once you have the installer:

- Create a new directory in `ftbgenesis`:

```
cd /home/ftbgenesis
mkdir server
cd server

# FTBGenesis Modpack URL for Linux x64
wget https://api.modpacks.ch/public/modpack/120/11425/server/linux

# This assumes you are downloading FTB Genesis for Linux, if you want a different modpack, you'll need to change the URL.

# Check the directory with:
ls
```

- You should now see `linux` (assuming you downloaded the linux version) in the newly created directory.

![linuxinstallerindir](https://i.imgur.com/rmSzHEZ.png)

- If you try to run the `linux` file as-is you will get a parse error; therefore, we must rename the file to whatever the file name of the FTB download is. To get the file name, you must:
    - left-click the file name to download it,
    - then copy the file name (exactly as it shows in the download)
    - then change the name of `linux` to `<file-download-name-as-shown>`

![filenameashown](https://i.imgur.com/e9sgeSV.png) 

- In this case we will change the name to `serverinstall_120_11425`. To change the name in Linux:

```
# Action the following from the same directory as before "server"
mv linux serverinstall_120_11425
```

- If you `ls` the directory, you should now see `serverinstall_120_11425` listed. Now, make this file executable so we can run the installer:

```
chmod +x serverinstall_120_11425
```

- Now, we can finally install the modpack server with:

```
./serverinstall_120_11425
```

- When prompted "Where would you like to install the server hit:

```
ENTER
y
y
```

![ftbserverinstallerprompts](https://i.imgur.com/qshcUjV.png)

- Now, sit back and watch the matrix (all the downloads of mods and dependencies). Every new download supports a mod creator. According to the FTB guide, "Depending on your internet connection this can take a while. A full server installation is around a few hundreds megabytes in size." In the end you should see:

![ftbgenesisinstallcompeted](https://i.imgur.com/W4jbnJA.png)

- After the install has completed `ls` the directory and you should see a bunch of new files/folders:

![newftbgenesisfiles](https://i.imgur.com/LLmO6dr.png)

- First, let's `rm serverinstall_120_11425` to conserve a bit of space (we don't need the installer anyway).

- Next, we need to make the starting `bash` script executable with `chmod +x start.sh`

### Create Minecraft Server Daemon
> This process can be skipped if you don't mind starting the server manually, but this it's handy to implement an auto-start for server on boot especially if you have friends playing on the server.

- Start by switching to the `root` user with `sudo su`
- Next, navigate to: `cd /etc/systemd/system`
- Now create a new `minecraft.service` file with `touch minecraft.service`
- Let's edit this new file with `nano minecraft.service`
- Paste the following inside the file:

```
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

- To save the added text, press `CTRL + X` then `y` then `ENTER` to save the changes.
- If you `cat minecraft.service` you should see the pasted text added.
- Now, we need to make this file executable with `chmod +x /etc/systemd/system/minecraft.service`
- If you `ls` the directory, you should see `minecraft.service` change colors indicating it is now executable.
- With the newly added `minecraft.service` we need to reload the `systemd` with `systemctl daemon-reload`
- Finally, let's enable the service with `systemctl enable minecraft.service`

### Starting the FTB Server

#### Non-auto-start Method (no minecraft.service file)

- To start the server in a separate screen, run:

```
screen -S ftbserver
cd ~/server
./start.sh
# This will start the game server with logs inside a screen.

# On the Linux server screen, you can type CTRL + A, D to close out the screen

# To see running screens/servers
screen -ls

# To bring the ftbserver screen back up
screen -r <screen_name>

# To kill the server
CTRL + A,  K
```

- Finally, we need to run it `./start.sh` and accept the EULA with `y`

#### Systemd Auto-start Method
```
screen -S ftbserver
systemctl start minecraft.service
# This will start the game server with logs inside a screen.
# On the Linux server screen, you can type CTRL + A, D to close out the screen
```

- You will be prompted to authenticate as the `ftbgenesis` user with the password you set:

![promptedforpasswordtolaunchsystemdmc](https://i.imgur.com/FJc1fMl.png)

- Enter the password and then check on the service with: `systemctl status minecraft.service` and you should see:

![statusofftbgenserverservice](https://i.imgur.com/sJ6Vgck.png)

- If you want to view a log of the server's activity enter:

```
# monitor the log file
tail -n3 -f /var/log/minecraft.log

# monitor the log file
tail -n3 -f /var/log/minecraft.err
```

### Troubleshooting FTB Server

#### Insufficient Memory error
![Insufficientmemjava](https://i.imgur.com/VFTaYPi.png)
- To fix, simply edit the Java parameters with: `nano user_jvm_args.txt` and change it to the specs you have availalbe or is reccomended by the modpack creator (see below):

![recspecsforftbgenesis](https://i.imgur.com/n68Fn2Q.png)

- In my case, I have RAM to spare, so I'm allocating more than necessary, but you can change the RAM to your liking by changing the `user_jvm_args.txt` as you see below:

```
# Xmx and Xms set the maximum and minimum RAM usage, respectively.
# They can take any number, followed by an M or a G.
# M means Megabyte, G means Gigabyte.
# For example, to set the maximum to 3GB: -Xmx3G
# To set the minimum to 2.5GB: -Xms2500M

# A good default for a modded server is 4GB.
# Uncomment the next line to set it.
-Xmx16G - Xms4G
```

- If that doesn't work, then `nano start.sh` and change the `-Xmx` and `-Xms` parameters there.

# Modded Minecraft with Crafty Web UI

> Crafty is a totally free GUI for managing self-hosted Minecraft servers. It gives you professional control panel similar to what paid Minecraft hosting sites provide.

Crafty Dashboard
![](https://i.imgur.com/k6Oqvfe.png)

Crafty Terminal (for Minecraft server commands)
![](https://i.imgur.com/gtBrDi3.png)

Crafty File Editor
![](https://i.imgur.com/cetW09C.png)

Crafty Server Metrics
![](https://i.imgur.com/rdz55vv.png)

In this guide, you will learn how to:
- Create modded Minecraft servers
- Manage your self-hosted Minecraft server remotely using the Crafty GUI throught a reverse proxy (i.e. enter www.yourdomain.com and oversee your server)

There are several steps to accomplish our goal:
1. Create a VM to host your Minecraft servers
1. Install Crafty
1. Import you modded Minecraft server into Crafty
1. Create a reverse proxy to access Crafty GUI remotely and securely

This guide assumes you already have a Linux VPS or VM to host your Minecraft server and we will jump right into installing Crafty to manage your Minecraft servers.

### Install Crafty
Ref. Crafty Linux Installer Guide: https://docs.craftycontrol.com/pages/getting-started/installation/linux/

> Check Crafty documentaion to ensure that this guide matches recent changes to Crafty.

#### My Installer Method
> Running this method gives you control over the directory of the Crafty install which is vital to import modded server `.zip` files and other custom modded content from FTB for example. 

- Install software dependencies:

- Create a `crafty` user

```
sudo useradd crafty -s /bin/bash
```

- Create a place for your Crafty file contents:

```
sudo mkdir /home/crafty/server
```

- Make the directories owned by `crafty`:

```
sudo chown -R crafty:crafty /home/crafty
```

- `cd` to the new directory

```
cd /home/crafty
```
> Please be sure to be in `/home/crafty` folder before you run the auto installer. To check type `pwd` and make sure.

-  Deploy the one-liner installer `cmdlet` provided by Crafty

```
git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git && \
 cd crafty-installer-4.0 && \
 sudo ./install_crafty.sh
```

- Done. Open a webrowser and enter `the-IPv4-address-of-your-server` and add the port `:8443` to access the Crafty web GUI. For example, if you are self-hosting, it will be IP assigned by your router such as: `192.168.1.57:8443`.

> __Important Security Note:__ Due to recent cyberattacks targetting Crafty servers (read about it on Crafty's Discord), the default login credentials have been changed to a unique 64-character string for the login password is generated at new Crafty server creation. Therefore, you must `cat` the `app/config/default-creds.txt` which is found in the root folder path you installed Crafty (if you followed this guide, that will be `/home/crafty/crafty-4/app/config/default-creds.txt`. Copy the password and paste it into the web GUI to get access to your new Crafty dashboard, and DON'T FORGET TO CHANGE THE PASSWORD after you successfully login. Read [Crafty's post-install documentaion here](https://docs.craftycontrol.com/pages/getting-started/access/)

### Importing a Custom Modded Server into Crafty
- Create a new server (choose the __same__ versions as your choice modded server)

![createcraftyserver](https://i.imgur.com/ALFTb2v.png)

- Click on the newly created server to open the server details.

![opennewlycreatedserver](https://i.imgur.com/r7mRrKT.png)

- Open `Config` and take note of the folder path to your newly created server. You will need this to modify the folder contents insdie Linux VM/VPS hosting your server.

![folderpathtoFTBGenesis](https://i.imgur.com/Gmr2980.png)

- Back on your Linux machine, navigate to the folder path of the new Crafty server:

```
cd /home/crafty/crafty-4/servers/<nameoffoldercraftymade>
```

- Since we are importing our own custom modpack of choice, we do not need all the pre-built files, so we can remove them all with `rm -r *`

- If you `ls` the folder (i.e. 
`/home/crafty/crafty-4/servers/<nameoffoldercraftymade>`) it should display no contents now. This is what we want.

- Now, we are clear to `wget` your modpack of choice. For this demonstration, we are going to `wget` the FTBGenesis server modpack. Refer to my [FTB server installer guide](#ftb-esrver-install) on how to get the clean link. From inside the `/home/crafty/crafty-4/servers/<nameoffoldercraftymade>` enter:

```
wget https://api.modpacks.ch/public/modpack/120/11425/server/linux
```

![wgetdemoshowlinux](https://camo.githubusercontent.com/c32ff251bc6b7932c7edb915616cc85ce6722a124902fd7e99aeef266295147a/68747470733a2f2f692e696d6775722e636f6d2f726d537a48455a2e706e67)
> You should now see linux (assuming you downloaded the linux version) in the newly created directory, but if you try to run the `linux` file as-is you will get a parse error; therefore, we must rename the file to whatever the file name of the FTB download is.

- Rename the `linux` file to `<name-of-FTB-download-modpack-ID>`, in the case of FTB Genesis, we simply take the URL `/120/11425` and change `linux` to `serverinstall_120_11425` (we are simply adding `serverinstall` and replacing the `\` with `_`). Make sense? In this case, the command would be:

```
mv linux serverinstall_120_11425
```

- Once the file has been renamed, we need to make that installer executable with:

```
chmod +x serverinstall_120_11425
```

- And now, we run it!

```
./serverinstall_120_11425
```

- When prompted _"Where would you like to install the server? [current directory]"_, hit `ENTER` and `y` to everything to install it to the Crafty directory we created prior. 

> Depending on the server modpack size and your internet speed, this may take a few minutes. Download times vary. In the end you should see _"The server installed sucessfully"_.

- In the end, `ls` the directory and you _should_ see all the modded server files and folders. If not, you may have accidentally installed the files somewhere else...

### Crafty x Custom Modpack Settings
> In order to make a custom modded Minecraft server work, you have to `cat` whatever the `run.sh` or `start.sh` generated by the modpack author (if there isn't one, you'll have to create one which is outside the scope of this tutorial, but basically, you need to create the custom server execution command required to run the server. Search "minecraft server execution scripts" to get an idea on how to make your own).

- To get the custom server execution command for our example modded server for FTB Genesis, you need to run:

```
cat start.sh
```

- You'll need to copy the server exec snippet that looks like this:

```
"/usr/lib/jvm/java-17-openjdk-amd64/bin/java" -javaagent:log4jfix/Log4jPatcher-1.0.0.jar -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -Xmx6144M -Xms4096M @user_jvm_args.txt @libraries/net/minecraftforge/forge/1.19.2-43.3.5/unix_args.txt nogui
```

- Paste the string you copied from the `start.sh` into the `Server Execution Command` text box in Crafty.

- Also, you'll need the change the `Server Executable` text box to whatever the `.jar` is in the modpack. In my case, it is `minecraft_server.1.19.2.jar`

![FTBgencustomconfigcrafty](https://i.imgur.com/fVWRKl1.png)

- Next, hit the `Update Executable` yellow button __FIRST__ and then the `Save` button after the server updates the executable settings (do not hit `Save` first because this bricked my Crafty UI for some reason.)

- It's finally time to start the server, so navigate to the dashboard and hit the play button on the server.

> If this is the first time you have to agree to the Minecraft EULA first then start the server again.

- __Server fail to launch?__ If the server fails to start, check `Terminal` for errors and troubleshoot accordingly (in my case, I had a typo in my `Server Executable`).

### Start Crafty and Server on Boot
- Let's start by enabling Crafty on boot with `systemctl enable crafty.service` this will ensure the Crafty UI is available at boot.
- Next, navigate to Crafty Web UI > <Server Name> > Config > and toggle on "Server Auto Start" (scroll to bottom of config page).

![autostartservercrafty](https://i.imgur.com/V6dqZAX.png)

### If Crafty Failes to Auto Start Server

- If Crafty's auto start ever fails you can always create bypass it with a service file.

> Note: This method will also bypass Crafty and the server stats will not dispaly in the Crafty UI. So, only use this method if you want the convenience of uptime, but don't need the Crafty UI.

- Start by entering `sudo su` to switch to the `root` user then `cd /` to go to the root directory and then `cd /etc/systemd/system` where we need to create a new `.service` file.
- `pwd` to makes sure in the right folder, and then create a new service file with `touch <server_name>.service`. For example, `touch ftbskies.service`.
- Next, edit the new file with `nano ftbskies.service` and paste the following:

```
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
ExecStart=/home/crafty/crafty-4/servers/<folder-name-of-crafty-server>/start.sh
WorkingDirectory=/home/crafty/crafty-4/servers/<folder-name-of-crafty-server>
TimeoutSec=240

[Install]
WantedBy=multi-user.target
```

> To get the exact folder name, you'll need to open a new screen with `screen -S crafty`, then `su - crafty`, then `cd ~/crafty/crafty-4/servers`, to find the right folder. If you `cd` to the folder and then `pwd` then you can copy the long folder name to then paste in the `.service` file.

- After customizing the `.service` file to your specific server, save the file and then run `systemctl enable <server_name>.service` to launch the server at boot.

> If you want to prevent the server from launching at boot simply run `systemctl disable server_name>.service`.

### Access Crafty Web UI Remotely
If you want to manage your Minecraft servers remotely, you'll need a reverse proxy like NGNIX, but that requires Docker and other VMs. Not to mention, you'll be exposing your server to the outside world tempting hackers to crypto-jack or deploy ransomware on your server, so I prefer to use Cloudflare's free zero-trust tunnels. Learn how to [deploy Cloudflare reverse proxy here](how-to_ultimate_proxmox.md#remote-access), otherwise, you won't be able to access it outside your network. Alternatively, you could consider using TailScale which is another secure method of access.

### Minecraft Server Settings
> You must be in the server folder to access the following server files.

- To enable whitelisting, `nano server.properties` and change `white-list: false` to `white-list: true` and save it.
- To add players to the white list,  `nano whitelist.json` and edit the following sample whitelist below:
```
[
  {
    "uuid": "f430dbb6-5d9a-444e-b542-e47329b2c5a0",
    "name": "username"
  },
  {
    "uuid": "e5aa0f99-2727-4a11-981f-dded8b1cd032",
    "name": "username"
  }
]
```
> Tip: To find the UUID of a player, use the [Minecraft UUID Converter](https://mcuuid.net/)

- If you want to add yourself as operator in-game so you can add whitelists on the fly in-game, `nano ops.json` and paste the following:

```
{
    "uuid": "389c92c7-eb5c-4a15-92b8-01a27348ac63",
    "name": "hero887",
    "level": 4,
    "bypassesPlayerLimit": false
  },
```

### Run Simultaneous Minecraft Servers
- Yes! It is possible to run more than one Minecraft server at the same time on different ports assuming your server specs (CPU + RAM) can support it (provision accordingly). 
![proofofmultimcservers](https://i.imgur.com/HsIAjkD.png)

- Running more than one server at a time is even easier thanks to Crafty. Simply edit a few properties and you are good to go! In this case we need to change the server port in the Crafty UI > <Minecraft Server Name> > Config > Server Port (set as something other than the default 25565, in my case I went with 25566).
![multimc1](https://i.imgur.com/qh7vmdZ.png)
- And don't forget to change the port defaults in the actual `server.properties` settings, see below:
![mulitmc2](https://i.imgur.com/YxH0A9o.png)
- As a last and final step, you must open whatever port you assigned in your router firewall port forwarding rules.

> Note: When trying to join your server in-game, you must use the IP:<unique_port_you_made>. So, in my case it would be: <my_public_IP_address:25565>. You must also map your DNS A records to the unique `25566` port you made 

## Useful Minecraft Server Commands

| Description | Example |
| -------- | ---------- |
| whitelist players | /whitelist add <username> |
| ban player  | /ban <username> |
| ban IP address | /ban-ip <public IP address> |
| unban player | /pardon <username> |
| view the ban list | /banlist |
| give player admin | /op <username> | 
| show all op players | /ops |
| remove player admin | /deop <username> |
| change gamerules | /gamerule <value> |
| save a server backup | /save-all |
| generate diag logs | /perf |
| send PM to player | /msg <username> <message> |
| give XP to player | /xp <username> |
| teleport to player | /tp <username> |
| clear weather | /weather clear |
| list commands usage | /help <value> |
| stop server | /stop |
| reboot server | /restart |

# Minecraft Forge Sever - Vanilla
> The following guide is to set up a clean `Forge` server install without a server installer (as shown above with FTB).

This guide assumes that:

1. You have a modded server picked out in advance (this matters for what Java version and Forge version you install). In this guide, we are going to create a server for: Minecraft version `<ver>` running `Forge` as the modbase. 
1. You can modify the `cmdlets` provded to fit your specific version of choice. This guide _should_ work for other versions of Minecraft, `Java`, and `Forge`, but you need to replace all the commands with your-version-specific needs. For example: `apt install default-jre` to install defaults may not work for your version.

### Install Java 8
- As an admin user, run the following installation commands:

```
sudo apt install openjdk-8-jdk
java -version
```

- If the `Java` version is different from wahat you wish, you can change it using:

 ```
 sudo update-alternatives --config java
 ```
 
 #### Crafting Environment

- If you haven't already, run an update on your Ubutnu system:

```
sudo apt update && apt -y upgrade
```

- Update `Screen`, a command that will contain and tail the server logs:

```
sudo apt install screen
```

- __Create a new user__ (must run as admin)

```
sudo useradd -m minecraft
```

- __Set/create a password__

```
sudo passwd minecraft
```

- __Change to new user__

```
su - minecraft
```

- Now, __create a new directory__ for the `mcserver`

```
cd /opt
mkdir modserver
cd modserver
```

> If you type `pwd` you should see the file path as follows: `/home/minecraft/modserver` you will need to __copy/input this path__ after you install the `steamcmd` package.

- __Download the Forge Installer__ (necessary for modded Minecraft):







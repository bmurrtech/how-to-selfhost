
# How-to Email Server

![compatible_OS](https://i.imgur.com/uvdqtOs.png)
- [Read through the mailcow documentation](https://docs.mailcow.email/prerequisite/prerequisite-system/#minimum-system-resources) to ensure you meet minimum requirements.

### Step 1 Get a VPS

> Self-hosting is not ideal for running an email server b/c 1) you need to manage reverse DNS 2) you need a dedicated, static IP. If you have these for your homelab, go for it.

__Minimum Email Server Specs for 1 Email User__

| vCPU        | RAM         | HHD/SSD     |
| ----------- | ----------- | ----------- |
| 1GHz        | 6GB         | 20GB

- [A2 Hosting](https://www.a2hosting.com/vps-hosting/managed?aid=presearchnode&bid=3b8941fc) offers an __unmanaged__ VPS (cheaper than managed) that would work great.
- Alternatively, if you're lucky and there's resources available in your nearest Oracle datatcenter, you can [create a free cloud account with Oracle](https://www.oracle.com/cloud/sign-in.html) (get a free 4 ARM-based CPUs, 28GB RAM, w/50GB of block storage for free!).
- After making your account, create a new Oracle cloud instance:
  - Select Ubuntu 18.04 as the OS.
  - Must select ARM as your CPU for the free verision.
- Create a 50GB block volume and attach it to your instance.
  - See [Oracle's documentation](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/addingstorage.htm) on how to attach the block storage to the instance.
  - Or this [Oracle Learning video](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/addingstorage.htm)

### Step 2 Secure Your System
- Create a new user/password:

```
sudo -s
sudo useradd -m -s /bin/bash [user]
sudo passwd [user]
su - [user]
```

- Update your system:

```
sudo apt update -y && apt upgrade -y
```

- [Configure SSH, passwordless login](https://linuxize.com/post/how-to-setup-passwordless-ssh-login/) (if you haven't already).

- Prevent brute force attacks by installing `Fail2Ban`

```
sudo apt install fail2ban -y
```

### Install Docker

- If you always want to automatically get the latest version of Docker on Ubuntu, you must add its official repository to Ubuntu system. To do that, run the commands below to install prerequisite packages:

```
sudo apt update -y && apt upgrade -y

sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
```

- Next, run the commands below to download and install Docker’s official GPG key. The key is used to validate packages installed from Docker’s repository making sure they’re trusted.

```
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88
```

- The response would be like this:

```
Response:

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]
```

- Now that the official GPG key is installed, run the commands below to add its stable repository to Ubuntu.

```
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
```

> To add the nightly or test repository, add the word nightly or test (or both) after the word stable in the commands below.

- The command below will always install the highest possible Docker version:

```
curl -sSL https://get.docker.com/ | CHANNEL=stable sh
```

- Reboot your instance:

```
sudo reboot
```

- To verify that Docker CE is installed correctly you can run the __hello-world__ image:

```
sudo docker run hello-world

# if it is installed correctl you should see:
Response:

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
1. The Docker client contacted the Docker daemon.
2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
(amd64)
3. The Docker daemon created a new container from that image which runs the
executable that produces the output you are currently reading.
4. The Docker daemon streamed that output to the Docker client, which sent it
to your terminal.
```

### Install Docker Compose 
> If you wanted to install a specific version of `docker-compose` then follow the steps below. Otherwise skip to the next section.

- To install a custom version of `docker-compose` (mailcow requires v2 and newer). Please [refer to the official Docker Github for latest releases](https://github.com/docker/compose/releases) and change the `<DESIRED_VER>` version number below to match what you choose:

```
sudo curl -L "https://github.com/docker/compose/releases/download/<DESIRED_VER>/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# for example:
sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

- After downloading it, run the commands below to apply executable permissions to the binary file and create a symbolic link to `/usr/binary`:

```
sudo chmod +x /usr/local/bin/docker-compose

sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

- Now, Docker Compose should work. To test it, we will run the command below:

```
sudo docker-compose --version

# the response should read something like:
Response:
docker-compose version v2.18.1
```

### Install Portainer

- You can use Docker command to deploy the Portainer Server; note the agent is not needed on standalone hosts, however, it does provide additional functionality if used.
- To get the server installed, run the commands below:

```
cd ~/
sudo docker volume create portainer_data
sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
```

> Note: the `-v /var/run/docker.sock:/var/run/docker.sock` option can be used in Linux environments only.

- At this point, all you need to do is access Portainer portal to manage Docker. Open your web browser and browse to the server’s hostname or IP address followed by port #9443

```
https://<SERVER_IP>:9443
```

- You should get Portainer login page to create an admin password.
- Submit a new password (make it a good one as this is publically accessible if hosted on a VPS).
- Select __Local__ as the type of envirnoment you want to manage (if unavailalbe, select "Getting Started").
- Since we installed Docker on the same machine, select to connect and manage Docker locally.

#### Install mailcow with Portainer
Installing mailcow with Portainer is probably the easiest method as it is a simple copy and paste of the `git` link or `docker-compose.yml` file (see end of guide for full `.yml` file contents).

![port_create_mailcow](https://i.imgur.com/GKBB2m6.png)

- Copy and paste the following (see screenshot for example):

```
https://github.com/mailcow/mailcow-dockerized
```

- Click "Deploy Stack" (button)

__ERROR__

![depoly_mailcow_fail](https://i.imgur.com/K9Hg96A.png)

#### Install mailcow without Portainer
If the above method failed, consider installing w/o Portainer.

- Make sure your `umask` equals `0022` __before__ you clone the `Mailcow` git.

```
umask
0022 # <-- Verify it is 0022

# if it returns 0002, then change to root by running:
sudo -s
umask
0022 # <-- Verify it is 0022
```

- If `umask` is showing `0022` now, you are good to go:

```
cd /opt
git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized
./generate_config.sh
```

- Enter your `FQDN`. This should be _your server's public IP address_, which is why a self-hosted homelab isn't ideal for an email server.
- Enter your timezone (ex. `America/New_York`).
- Select the `master branch` as we wish to have the most stable version of `Mailcow`.
- Now, the `Mailcow` `bash` script should have created a config file which you may edit to your liking:

```
sudo nano mailcow.conf
```

- Now, apply the changes made and start the mail server:

```
sudo docker-compose up -d
```

> Note, the first run will take some time as there are numerous downloads required.

- After the completion, you should see some green "done" indicators on screen. To check the status, run:

```
sudo docker-compose ps
```

- You should notice an "Up" text maker in the `STATUS` column.
- If all looks good, time to configure the firewall rules.
- 
### Configure Firewall Rules

#### VPS Firewall Config
- Every VPS provider may be a little different, but you need to find the firewall/security, port, ingress/egress settings and configure them. I am working in [Oracle Cloud's ingress rules](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm), so this tutorial assumes as much.

![mailcow_ports](https://i.imgur.com/9qiTMcr.png)
- Add ingress rules for `22, 25, 80, 110, 443, 465, 587, 993, 995, 4190/tcp` ports. Follow the template configuration below when configuring your ingress rules:

```
# Mailcow ingress/egress rule
Stateless: Checked
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Sorce Port Range: All (leave blank)
Destination Port Range: 22
Description: Mailcow

# Mailcow ingress rule 
Stateless: Checked/egress
Source CIDR: 0.0.0.0/0
IP Protocol: TCP
Sorce Port Range: All (leave blank)
Destination Port Range: 25
Description: Mailcow

# continue to add ingress rules for every port listed above
```

#### Docker Firewall Config
Turns out that Docker firewall settings are difficult. ["One of the most annoying things with Docker has been how it interacts with iptables. And ufw. And firewalld."](https://unrouted.io/2017/08/15/docker-firewall/) But, thanks to a recent Docker 17.06 update and higher, ["you can add rules to a new table called `DOCKER-USER`. This can be useful if you need to pre-populate iptables rules that need to be in place before Docker runs."](https://docs.docker.com/engine/userguide/networking/#links)
- To demonstrate the port issues of Docker before configuration, run a `telnet` to check if port `25` is open and listening:

```
telnet 127.0.0.1 25
```

- If it returns a `Connection refused`, then we know the Docker firewall is still blocking it. In which case, we need to update the firewall rules.
- First, create a new `iptables.conf`

```
nano /etc/iptables.conf
```

- Next, copy and paste the following contents into that file and save it:

```
*filter
:INPUT ACCEPT [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:FILTERS - [0:0]
:DOCKER-USER - [0:0]

-F INPUT
-F DOCKER-USER
-F FILTERS

-A INPUT -i lo -j ACCEPT
-A INPUT -p icmp --icmp-type any -j ACCEPT
-A INPUT -j FILTERS

-A DOCKER-USER -i ens33 -j FILTERS
-A FILTERS -m state --state ESTABLISHED,RELATED -j ACCEPT
-A FILTERS -m state --state NEW -s 1.2.3.4/32 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 25 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 110 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 465 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 587 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 993 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 995 -j ACCEPT
-A FILTERS -m state --state NEW -m tcp -p tcp --dport 4190 -j ACCEPT
-A FILTERS -j REJECT --reject-with icmp-host-prohibited

COMMIT
```

- Now, load this config into the kernel with:

```
sudo iptables-restore -n /etc/iptables.conf
```

> "That `-n` flag is crucial to avoid breaking Docker. This firewall avoids touching areas Docker is likely to interfere with. You can restart Docker over and over again and it will not harm or hinder our rules in `INPUT`, `DOCKER-USER` or `FILTERS`."

- And start the firewall at boot by creating a new `systemd.service` file:

```
# creates the file
sudo nano /etc/systemd/system/iptables.service

# contents to be added to file
[Unit]
Description=Restore iptables firewall rules
Before=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore -n /etc/iptables.conf

[Install]
WantedBy=multi-user.target

# now, enable it to start at boot
sudo systemctl enable --now iptables

# if the above failes to start it, try:
sudo systemctl enable iptables
sudo systemctl start iptables
```

- To make changes, open the firewall settings in your favourite text editor, add or remove a rule from the `FILTERS` section, then reload the firewall with:

```
# open firewall settings
sudo nano /etc/iptables.conf

# save changes then update with:
sudo systemctl restart iptables
```

__Troubleshooting__
- To confirm this suspicion further, run `netstat -tulpen` and `telnet 127.0.0.1 25` and see what ports are open. If you the ports are still returning "Connection refused" dig deeper into your `iptables`, VPS ingress/network port settings, and check Portainer > Local > Networks for anything that looks off.


#### Protainer x Ngix x Mailcow
If you wish to run `Nginx`, then you will need to make special configurations. We have to create a number of custom files to make Portainer and Mailcow play nicely together.

- Within the `mailcow-dockerized` root folder, create a new new file as follows:

```
cd /
cd /opt/mailcow-dockerized
sudo nano docker-compose.override.yml
```

- Copy and paste the following contents into that new `.yml` file:

```
version: '2.1'
services:
    portainer-mailcow:
      image: portainer/portainer-ce
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - ./data/conf/portainer:/data
      restart: always
      dns:
        - 172.22.1.254
      dns_search: mailcow-network
      networks:
        mailcow-network:
          aliases:
            - portainer
```

- Save and exit that `.yml` file.
- Create a `data/conf/nginx/portainer.conf` config file:

```
sudo nano data/conf/nginx/portainer.conf
```

- Copy and paste the following contents into that new `data/conf/nginx/portainer.conf` file:

```
upstream portainer {
  server portainer-mailcow:9000;
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
```

- Save and exit that `.conf` file.
- Insert a new location to the default mailcow site by creating the file `data/conf/nginx/site.portainer.custom`:

```
sudo nano data/conf/nginx/site.portainer.custom
```

- Copy and paste the following conents:

```
  location /portainer/ {
    proxy_http_version 1.1;
    proxy_set_header Host              $http_host;   # required for docker client's sake
    proxy_set_header X-Real-IP         $remote_addr; # pass on real client's IP
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout                 900;

    proxy_set_header Connection "";
    proxy_buffers 32 4k;
    proxy_pass http://portainer/;
  }

  location /portainer/api/websocket/ {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_pass http://portainer/api/websocket/;
  }
```
- Save and exit that `.custom` file.

```
sudo docker-compose up -d && docker-compose restart nginx-mailcow
```

> Note: The nginx-mailcow restart seems to always produce the following error: `
ERROR: Invalid interpolation format for "environment" option in service "postfix-mailcow": "REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}"`

### Resources
- [Install a mail server on Linux in 10 minutes - docker, docker-compose, mailcow
](https://www.youtube.com/watch?v=4rzc0hWRSPg)
- [Opentaq! - SELF-HOSTED | Set up and run your own Mailserver with Mailcow | DNS, Security, Installation, Test](https://www.youtube.com/watch?v=_z6do5BSJmg&t=287s)
- [Install a mail server on Linux in 10 minutes - docker, docker-compose, mailcow
](https://www.youtube.com/watch?v=4rzc0hWRSPg)
- [Portainer Install Ubuntu tutorial - manage your docker containers
](https://www.youtube.com/watch?v=ljDI5jykjE8)
- [Mailcow Docker Compose](https://docs.mailcow.email/i_u_m/i_u_m_install/)
- [Mailcow Nginx Configurations](https://docs.mailcow.email/third_party/portainer/third_party-portainer/)
- [Opening port 80 on Oracle Cloud Infrastructure Compute](https://stackoverflow.com/questions/54794217/opening-port-80-on-oracle-cloud-infrastructure-compute-node)
- [See 3 "Enable Internet Access" section of Oracle Cloud doc](https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/apache-on-ubuntu/01oci-ubuntu-apache-summary.htm)

### mailcow Docker Compose .yml
```
version: '2.1'
services:

    unbound-mailcow:
      image: mailcow/unbound:1.17
      environment:
        - TZ=${TZ}
      volumes:
        - ./data/hooks/unbound:/hooks:Z
        - ./data/conf/unbound/unbound.conf:/etc/unbound/unbound.conf:ro,Z
      restart: always
      tty: true
      networks:
        mailcow-network:
          ipv4_address: ${IPV4_NETWORK:-172.22.1}.254
          aliases:
            - unbound

    mysql-mailcow:
      image: mariadb:10.5
      depends_on:
        - unbound-mailcow
      stop_grace_period: 45s
      volumes:
        - mysql-vol-1:/var/lib/mysql/
        - mysql-socket-vol-1:/var/run/mysqld/
        - ./data/conf/mysql/:/etc/mysql/conf.d/:ro,Z
      environment:
        - TZ=${TZ}
        - MYSQL_ROOT_PASSWORD=${DBROOT}
        - MYSQL_DATABASE=${DBNAME}
        - MYSQL_USER=${DBUSER}
        - MYSQL_PASSWORD=${DBPASS}
        - MYSQL_INITDB_SKIP_TZINFO=1
      restart: always
      ports:
        - "${SQL_PORT:-127.0.0.1:13306}:3306"
      networks:
        mailcow-network:
          aliases:
            - mysql

    redis-mailcow:
      image: redis:7-alpine
      volumes:
        - redis-vol-1:/data/
      restart: always
      ports:
        - "${REDIS_PORT:-127.0.0.1:7654}:6379"
      environment:
        - TZ=${TZ}
      sysctls:
        - net.core.somaxconn=4096
      networks:
        mailcow-network:
          ipv4_address: ${IPV4_NETWORK:-172.22.1}.249
          aliases:
            - redis

    clamd-mailcow:
      image: mailcow/clamd:1.61
      restart: always
      depends_on:
        - unbound-mailcow
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      environment:
        - TZ=${TZ}
        - SKIP_CLAMD=${SKIP_CLAMD:-n}
      volumes:
        - ./data/conf/clamav/:/etc/clamav/:Z
        - clamd-db-vol-1:/var/lib/clamav
      networks:
        mailcow-network:
          aliases:
            - clamd

    rspamd-mailcow:
      image: mailcow/rspamd:1.92
      stop_grace_period: 30s
      depends_on:
        - dovecot-mailcow
      environment:
        - TZ=${TZ}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - IPV6_NETWORK=${IPV6_NETWORK:-fd4d:6169:6c63:6f77::/64}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
      volumes:
        - ./data/hooks/rspamd:/hooks:Z
        - ./data/conf/rspamd/custom/:/etc/rspamd/custom:z
        - ./data/conf/rspamd/override.d/:/etc/rspamd/override.d:Z
        - ./data/conf/rspamd/local.d/:/etc/rspamd/local.d:Z
        - ./data/conf/rspamd/plugins.d/:/etc/rspamd/plugins.d:Z
        - ./data/conf/rspamd/lua/:/etc/rspamd/lua/:ro,Z
        - ./data/conf/rspamd/rspamd.conf.local:/etc/rspamd/rspamd.conf.local:Z
        - ./data/conf/rspamd/rspamd.conf.override:/etc/rspamd/rspamd.conf.override:Z
        - rspamd-vol-1:/var/lib/rspamd
      restart: always
      hostname: rspamd
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      networks:
        mailcow-network:
          aliases:
            - rspamd

    php-fpm-mailcow:
      image: mailcow/phpfpm:1.84
      command: "php-fpm -d date.timezone=${TZ} -d expose_php=0"
      depends_on:
        - redis-mailcow
      volumes:
        - ./data/hooks/phpfpm:/hooks:Z
        - ./data/web:/web:z
        - ./data/conf/rspamd/dynmaps:/dynmaps:ro,z
        - ./data/conf/rspamd/custom/:/rspamd_custom_maps:z
        - rspamd-vol-1:/var/lib/rspamd
        - mysql-socket-vol-1:/var/run/mysqld/
        - ./data/conf/sogo/:/etc/sogo/:z
        - ./data/conf/rspamd/meta_exporter:/meta_exporter:ro,z
        - ./data/conf/phpfpm/sogo-sso/:/etc/sogo-sso/:z
        - ./data/conf/phpfpm/php-fpm.d/pools.conf:/usr/local/etc/php-fpm.d/z-pools.conf:Z
        - ./data/conf/phpfpm/php-conf.d/opcache-recommended.ini:/usr/local/etc/php/conf.d/opcache-recommended.ini:Z
        - ./data/conf/phpfpm/php-conf.d/upload.ini:/usr/local/etc/php/conf.d/upload.ini:Z
        - ./data/conf/phpfpm/php-conf.d/other.ini:/usr/local/etc/php/conf.d/zzz-other.ini:Z
        - ./data/conf/dovecot/global_sieve_before:/global_sieve/before:z
        - ./data/conf/dovecot/global_sieve_after:/global_sieve/after:z
        - ./data/assets/templates:/tpls:z
        - ./data/conf/nginx/:/etc/nginx/conf.d/:z
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      environment:
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
        - LOG_LINES=${LOG_LINES:-9999}
        - TZ=${TZ}
        - DBNAME=${DBNAME}
        - DBUSER=${DBUSER}
        - DBPASS=${DBPASS}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
        - MAILCOW_PASS_SCHEME=${MAILCOW_PASS_SCHEME:-BLF-CRYPT}
        - IMAP_PORT=${IMAP_PORT:-143}
        - IMAPS_PORT=${IMAPS_PORT:-993}
        - POP_PORT=${POP_PORT:-110}
        - POPS_PORT=${POPS_PORT:-995}
        - SIEVE_PORT=${SIEVE_PORT:-4190}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - IPV6_NETWORK=${IPV6_NETWORK:-fd4d:6169:6c63:6f77::/64}
        - SUBMISSION_PORT=${SUBMISSION_PORT:-587}
        - SMTPS_PORT=${SMTPS_PORT:-465}
        - SMTP_PORT=${SMTP_PORT:-25}
        - API_KEY=${API_KEY:-invalid}
        - API_KEY_READ_ONLY=${API_KEY_READ_ONLY:-invalid}
        - API_ALLOW_FROM=${API_ALLOW_FROM:-invalid}
        - COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-mailcow-dockerized}
        - SKIP_SOLR=${SKIP_SOLR:-y}
        - SKIP_CLAMD=${SKIP_CLAMD:-n}
        - SKIP_SOGO=${SKIP_SOGO:-n}
        - ALLOW_ADMIN_EMAIL_LOGIN=${ALLOW_ADMIN_EMAIL_LOGIN:-n}
        - MASTER=${MASTER:-y}
        - DEV_MODE=${DEV_MODE:-n}
        - DEMO_MODE=${DEMO_MODE:-n}
        - WEBAUTHN_ONLY_TRUSTED_VENDORS=${WEBAUTHN_ONLY_TRUSTED_VENDORS:-n}
      restart: always
      networks:
        mailcow-network:
          aliases:
            - phpfpm

    sogo-mailcow:
      image: mailcow/sogo:1.117
      environment:
        - DBNAME=${DBNAME}
        - DBUSER=${DBUSER}
        - DBPASS=${DBPASS}
        - TZ=${TZ}
        - LOG_LINES=${LOG_LINES:-9999}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
        - MAILCOW_PASS_SCHEME=${MAILCOW_PASS_SCHEME:-BLF-CRYPT}
        - ACL_ANYONE=${ACL_ANYONE:-disallow}
        - ALLOW_ADMIN_EMAIL_LOGIN=${ALLOW_ADMIN_EMAIL_LOGIN:-n}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - SOGO_EXPIRE_SESSION=${SOGO_EXPIRE_SESSION:-480}
        - SKIP_SOGO=${SKIP_SOGO:-n}
        - MASTER=${MASTER:-y}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      volumes:
        - ./data/hooks/sogo:/hooks:Z
        - ./data/conf/sogo/:/etc/sogo/:z
        - ./data/web/inc/init_db.inc.php:/init_db.inc.php:z
        - ./data/conf/sogo/custom-favicon.ico:/usr/lib/GNUstep/SOGo/WebServerResources/img/sogo.ico:z
        - ./data/conf/sogo/custom-theme.js:/usr/lib/GNUstep/SOGo/WebServerResources/js/theme.js:z
        - ./data/conf/sogo/custom-sogo.js:/usr/lib/GNUstep/SOGo/WebServerResources/js/custom-sogo.js:z
        - mysql-socket-vol-1:/var/run/mysqld/
        - sogo-web-vol-1:/sogo_web
        - sogo-userdata-backup-vol-1:/sogo_backup
      labels:
        ofelia.enabled: "true"
        ofelia.job-exec.sogo_sessions.schedule: "@every 1m"
        ofelia.job-exec.sogo_sessions.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-tool expire-sessions $${SOGO_EXPIRE_SESSION} || exit 0\""
        ofelia.job-exec.sogo_ealarms.schedule: "@every 1m"
        ofelia.job-exec.sogo_ealarms.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-ealarms-notify -p /etc/sogo/sieve.creds || exit 0\""
        ofelia.job-exec.sogo_eautoreply.schedule: "@every 5m"
        ofelia.job-exec.sogo_eautoreply.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-tool update-autoreply -p /etc/sogo/sieve.creds || exit 0\""
        ofelia.job-exec.sogo_backup.schedule: "@every 24h"
        ofelia.job-exec.sogo_backup.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-tool backup /sogo_backup ALL || exit 0\""
      restart: always
      networks:
        mailcow-network:
          ipv4_address: ${IPV4_NETWORK:-172.22.1}.248
          aliases:
            - sogo

    dovecot-mailcow:
      image: mailcow/dovecot:1.23
      depends_on:
        - mysql-mailcow
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      cap_add:
        - NET_BIND_SERVICE
      volumes:
        - ./data/hooks/dovecot:/hooks:Z
        - ./data/conf/dovecot:/etc/dovecot:z
        - ./data/assets/ssl:/etc/ssl/mail/:ro,z
        - ./data/conf/sogo/:/etc/sogo/:z
        - ./data/conf/phpfpm/sogo-sso/:/etc/phpfpm/:z
        - vmail-vol-1:/var/vmail
        - vmail-index-vol-1:/var/vmail_index
        - crypt-vol-1:/mail_crypt/
        - ./data/conf/rspamd/custom/:/etc/rspamd/custom:z
        - ./data/assets/templates:/templates:z
        - rspamd-vol-1:/var/lib/rspamd
        - mysql-socket-vol-1:/var/run/mysqld/
      environment:
        - DOVECOT_MASTER_USER=${DOVECOT_MASTER_USER:-}
        - DOVECOT_MASTER_PASS=${DOVECOT_MASTER_PASS:-}
        - LOG_LINES=${LOG_LINES:-9999}
        - DBNAME=${DBNAME}
        - DBUSER=${DBUSER}
        - DBPASS=${DBPASS}
        - TZ=${TZ}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
        - MAILCOW_PASS_SCHEME=${MAILCOW_PASS_SCHEME:-BLF-CRYPT}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - ALLOW_ADMIN_EMAIL_LOGIN=${ALLOW_ADMIN_EMAIL_LOGIN:-n}
        - MAILDIR_GC_TIME=${MAILDIR_GC_TIME:-7200}
        - ACL_ANYONE=${ACL_ANYONE:-disallow}
        - SKIP_SOLR=${SKIP_SOLR:-y}
        - MAILDIR_SUB=${MAILDIR_SUB:-}
        - MASTER=${MASTER:-y}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
        - COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-mailcow-dockerized}
      ports:
        - "${DOVEADM_PORT:-127.0.0.1:19991}:12345"
        - "${IMAP_PORT:-143}:143"
        - "${IMAPS_PORT:-993}:993"
        - "${POP_PORT:-110}:110"
        - "${POPS_PORT:-995}:995"
        - "${SIEVE_PORT:-4190}:4190"
      restart: always
      tty: true
      labels:
        ofelia.enabled: "true"
        ofelia.job-exec.dovecot_imapsync_runner.schedule: "@every 1m"
        ofelia.job-exec.dovecot_imapsync_runner.no-overlap: "true"
        ofelia.job-exec.dovecot_imapsync_runner.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu nobody /usr/local/bin/imapsync_runner.pl || exit 0\""
        ofelia.job-exec.dovecot_trim_logs.schedule: "@every 1m"
        ofelia.job-exec.dovecot_trim_logs.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu vmail /usr/local/bin/trim_logs.sh || exit 0\""
        ofelia.job-exec.dovecot_quarantine.schedule: "@every 20m"
        ofelia.job-exec.dovecot_quarantine.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu vmail /usr/local/bin/quarantine_notify.py || exit 0\""
        ofelia.job-exec.dovecot_clean_q_aged.schedule: "@every 24h"
        ofelia.job-exec.dovecot_clean_q_aged.command: "/bin/bash -c \"[[ $${MASTER} == y ]] && /usr/local/bin/gosu vmail /usr/local/bin/clean_q_aged.sh || exit 0\""
        ofelia.job-exec.dovecot_maildir_gc.schedule: "@every 30m"
        ofelia.job-exec.dovecot_maildir_gc.command: "/bin/bash -c \"source /source_env.sh ; /usr/local/bin/gosu vmail /usr/local/bin/maildir_gc.sh\""
        ofelia.job-exec.dovecot_sarules.schedule: "@every 24h"
        ofelia.job-exec.dovecot_sarules.command: "/bin/bash -c \"/usr/local/bin/sa-rules.sh\""
        ofelia.job-exec.dovecot_fts.schedule: "@every 24h"
        ofelia.job-exec.dovecot_fts.command: "/usr/bin/curl http://solr:8983/solr/dovecot-fts/update?optimize=true"
        ofelia.job-exec.dovecot_repl_health.schedule: "@every 5m"
        ofelia.job-exec.dovecot_repl_health.command: "/bin/bash -c \"/usr/local/bin/gosu vmail /usr/local/bin/repl_health.sh\""
      ulimits:
        nproc: 65535
        nofile:
          soft: 20000
          hard: 40000
      networks:
        mailcow-network:
          ipv4_address: ${IPV4_NETWORK:-172.22.1}.250
          aliases:
            - dovecot

    postfix-mailcow:
      image: mailcow/postfix:1.68
      depends_on:
        - mysql-mailcow
      volumes:
        - ./data/hooks/postfix:/hooks:Z
        - ./data/conf/postfix:/opt/postfix/conf:z
        - ./data/assets/ssl:/etc/ssl/mail/:ro,z
        - postfix-vol-1:/var/spool/postfix
        - crypt-vol-1:/var/lib/zeyple
        - rspamd-vol-1:/var/lib/rspamd
        - mysql-socket-vol-1:/var/run/mysqld/
      environment:
        - LOG_LINES=${LOG_LINES:-9999}
        - TZ=${TZ}
        - DBNAME=${DBNAME}
        - DBUSER=${DBUSER}
        - DBPASS=${DBPASS}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
      cap_add:
        - NET_BIND_SERVICE
      ports:
        - "${SMTP_PORT:-25}:25"
        - "${SMTPS_PORT:-465}:465"
        - "${SUBMISSION_PORT:-587}:587"
      restart: always
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      networks:
        mailcow-network:
          ipv4_address: ${IPV4_NETWORK:-172.22.1}.253
          aliases:
            - postfix

    memcached-mailcow:
      image: memcached:alpine
      restart: always
      environment:
        - TZ=${TZ}
      networks:
        mailcow-network:
          aliases:
            - memcached

    nginx-mailcow:
      depends_on:
        - sogo-mailcow
        - php-fpm-mailcow
        - redis-mailcow
      image: nginx:mainline-alpine
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      command: /bin/sh -c "envsubst < /etc/nginx/conf.d/templates/listen_plain.template > /etc/nginx/conf.d/listen_plain.active &&
        envsubst < /etc/nginx/conf.d/templates/listen_ssl.template > /etc/nginx/conf.d/listen_ssl.active &&
        envsubst < /etc/nginx/conf.d/templates/sogo.template > /etc/nginx/conf.d/sogo.active &&
        . /etc/nginx/conf.d/templates/server_name.template.sh > /etc/nginx/conf.d/server_name.active &&
        . /etc/nginx/conf.d/templates/sites.template.sh > /etc/nginx/conf.d/sites.active &&
        . /etc/nginx/conf.d/templates/sogo_eas.template.sh > /etc/nginx/conf.d/sogo_eas.active &&
        nginx -qt &&
        until ping phpfpm -c1 > /dev/null; do sleep 1; done &&
        until ping sogo -c1 > /dev/null; do sleep 1; done &&
        until ping redis -c1 > /dev/null; do sleep 1; done &&
        until ping rspamd -c1 > /dev/null; do sleep 1; done &&
        exec nginx -g 'daemon off;'"
      environment:
        - HTTPS_PORT=${HTTPS_PORT:-443}
        - HTTP_PORT=${HTTP_PORT:-80}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - TZ=${TZ}
        - SKIP_SOGO=${SKIP_SOGO:-n}
        - ALLOW_ADMIN_EMAIL_LOGIN=${ALLOW_ADMIN_EMAIL_LOGIN:-n}
        - ADDITIONAL_SERVER_NAMES=${ADDITIONAL_SERVER_NAMES:-}
      volumes:
        - ./data/web:/web:ro,z
        - ./data/conf/rspamd/dynmaps:/dynmaps:ro,z
        - ./data/assets/ssl/:/etc/ssl/mail/:ro,z
        - ./data/conf/nginx/:/etc/nginx/conf.d/:z
        - ./data/conf/rspamd/meta_exporter:/meta_exporter:ro,z
        - sogo-web-vol-1:/usr/lib/GNUstep/SOGo/
      ports:
        - "${HTTPS_BIND:-}:${HTTPS_PORT:-443}:${HTTPS_PORT:-443}"
        - "${HTTP_BIND:-}:${HTTP_PORT:-80}:${HTTP_PORT:-80}"
      restart: always
      networks:
        mailcow-network:
          aliases:
            - nginx

    acme-mailcow:
      depends_on:
        - nginx-mailcow
      image: mailcow/acme:1.84
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      environment:
        - LOG_LINES=${LOG_LINES:-9999}
        - ACME_CONTACT=${ACME_CONTACT:-}
        - ADDITIONAL_SAN=${ADDITIONAL_SAN}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
        - DBNAME=${DBNAME}
        - DBUSER=${DBUSER}
        - DBPASS=${DBPASS}
        - SKIP_LETS_ENCRYPT=${SKIP_LETS_ENCRYPT:-n}
        - COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-mailcow-dockerized}
        - DIRECTORY_URL=${DIRECTORY_URL:-}
        - ENABLE_SSL_SNI=${ENABLE_SSL_SNI:-n}
        - SKIP_IP_CHECK=${SKIP_IP_CHECK:-n}
        - SKIP_HTTP_VERIFICATION=${SKIP_HTTP_VERIFICATION:-n}
        - ONLY_MAILCOW_HOSTNAME=${ONLY_MAILCOW_HOSTNAME:-n}
        - LE_STAGING=${LE_STAGING:-n}
        - TZ=${TZ}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
        - SNAT_TO_SOURCE=${SNAT_TO_SOURCE:-n}
        - SNAT6_TO_SOURCE=${SNAT6_TO_SOURCE:-n}
      volumes:
        - ./data/web/.well-known/acme-challenge:/var/www/acme:z
        - ./data/assets/ssl:/var/lib/acme/:z
        - ./data/assets/ssl-example:/var/lib/ssl-example/:ro,Z
        - mysql-socket-vol-1:/var/run/mysqld/
      restart: always
      networks:
        mailcow-network:
          aliases:
            - acme

    netfilter-mailcow:
      image: mailcow/netfilter:1.52
      stop_grace_period: 30s
      depends_on:
        - dovecot-mailcow
        - postfix-mailcow
        - sogo-mailcow
        - php-fpm-mailcow
        - redis-mailcow
      restart: always
      privileged: true
      environment:
        - TZ=${TZ}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - IPV6_NETWORK=${IPV6_NETWORK:-fd4d:6169:6c63:6f77::/64}
        - SNAT_TO_SOURCE=${SNAT_TO_SOURCE:-n}
        - SNAT6_TO_SOURCE=${SNAT6_TO_SOURCE:-n}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
      network_mode: "host"
      volumes:
        - /lib/modules:/lib/modules:ro

    watchdog-mailcow:
      image: mailcow/watchdog:1.97
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      tmpfs:
        - /tmp
      volumes:
        - rspamd-vol-1:/var/lib/rspamd
        - mysql-socket-vol-1:/var/run/mysqld/
        - postfix-vol-1:/var/spool/postfix
        - ./data/assets/ssl:/etc/ssl/mail/:ro,z
      restart: always
      environment:
        - IPV6_NETWORK=${IPV6_NETWORK:-fd4d:6169:6c63:6f77::/64}
        - LOG_LINES=${LOG_LINES:-9999}
        - TZ=${TZ}
        - DBNAME=${DBNAME}
        - DBUSER=${DBUSER}
        - DBPASS=${DBPASS}
        - DBROOT=${DBROOT}
        - USE_WATCHDOG=${USE_WATCHDOG:-n}
        - WATCHDOG_NOTIFY_EMAIL=${WATCHDOG_NOTIFY_EMAIL:-}
        - WATCHDOG_NOTIFY_BAN=${WATCHDOG_NOTIFY_BAN:-y}
        - WATCHDOG_SUBJECT=${WATCHDOG_SUBJECT:-Watchdog ALERT}
        - WATCHDOG_EXTERNAL_CHECKS=${WATCHDOG_EXTERNAL_CHECKS:-n}
        - WATCHDOG_MYSQL_REPLICATION_CHECKS=${WATCHDOG_MYSQL_REPLICATION_CHECKS:-n}
        - WATCHDOG_VERBOSE=${WATCHDOG_VERBOSE:-n}
        - MAILCOW_HOSTNAME=${MAILCOW_HOSTNAME}
        - COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-mailcow-dockerized}
        - IPV4_NETWORK=${IPV4_NETWORK:-172.22.1}
        - IP_BY_DOCKER_API=${IP_BY_DOCKER_API:-0}
        - CHECK_UNBOUND=${CHECK_UNBOUND:-1}
        - SKIP_CLAMD=${SKIP_CLAMD:-n}
        - SKIP_LETS_ENCRYPT=${SKIP_LETS_ENCRYPT:-n}
        - SKIP_SOGO=${SKIP_SOGO:-n}
        - HTTPS_PORT=${HTTPS_PORT:-443}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
        - EXTERNAL_CHECKS_THRESHOLD=${EXTERNAL_CHECKS_THRESHOLD:-1}
        - NGINX_THRESHOLD=${NGINX_THRESHOLD:-5}
        - UNBOUND_THRESHOLD=${UNBOUND_THRESHOLD:-5}
        - REDIS_THRESHOLD=${REDIS_THRESHOLD:-5}
        - MYSQL_THRESHOLD=${MYSQL_THRESHOLD:-5}
        - MYSQL_REPLICATION_THRESHOLD=${MYSQL_REPLICATION_THRESHOLD:-1}
        - SOGO_THRESHOLD=${SOGO_THRESHOLD:-3}
        - POSTFIX_THRESHOLD=${POSTFIX_THRESHOLD:-8}
        - CLAMD_THRESHOLD=${CLAMD_THRESHOLD:-15}
        - DOVECOT_THRESHOLD=${DOVECOT_THRESHOLD:-12}
        - DOVECOT_REPL_THRESHOLD=${DOVECOT_REPL_THRESHOLD:-20}
        - PHPFPM_THRESHOLD=${PHPFPM_THRESHOLD:-5}
        - RATELIMIT_THRESHOLD=${RATELIMIT_THRESHOLD:-1}
        - FAIL2BAN_THRESHOLD=${FAIL2BAN_THRESHOLD:-1}
        - ACME_THRESHOLD=${ACME_THRESHOLD:-1}
        - RSPAMD_THRESHOLD=${RSPAMD_THRESHOLD:-5}
        - OLEFY_THRESHOLD=${OLEFY_THRESHOLD:-5}
        - MAILQ_THRESHOLD=${MAILQ_THRESHOLD:-20}
        - MAILQ_CRIT=${MAILQ_CRIT:-30}
      networks:
        mailcow-network:
          aliases:
            - watchdog

    dockerapi-mailcow:
      image: mailcow/dockerapi:2.04
      security_opt:
        - label=disable
      restart: always
      dns:
        - ${IPV4_NETWORK:-172.22.1}.254
      environment:
        - DBROOT=${DBROOT}
        - TZ=${TZ}
        - REDIS_SLAVEOF_IP=${REDIS_SLAVEOF_IP:-}
        - REDIS_SLAVEOF_PORT=${REDIS_SLAVEOF_PORT:-}
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock:ro
      networks:
        mailcow-network:
          aliases:
            - dockerapi

    solr-mailcow:
      image: mailcow/solr:1.8.1
      restart: always
      volumes:
        - solr-vol-1:/opt/solr/server/solr/dovecot-fts/data
      ports:
        - "${SOLR_PORT:-127.0.0.1:18983}:8983"
      environment:
        - TZ=${TZ}
        - SOLR_HEAP=${SOLR_HEAP:-1024}
        - SKIP_SOLR=${SKIP_SOLR:-y}
      networks:
        mailcow-network:
          aliases:
            - solr

    olefy-mailcow:
      image: mailcow/olefy:1.11
      restart: always
      environment:
        - TZ=${TZ}
        - OLEFY_BINDADDRESS=0.0.0.0
        - OLEFY_BINDPORT=10055
        - OLEFY_TMPDIR=/tmp
        - OLEFY_PYTHON_PATH=/usr/bin/python3
        - OLEFY_OLEVBA_PATH=/usr/bin/olevba
        - OLEFY_LOGLVL=20
        - OLEFY_MINLENGTH=500
        - OLEFY_DEL_TMP=1
      networks:
        mailcow-network:
          aliases:
            - olefy

    ofelia-mailcow:
      image: mcuadros/ofelia:latest
      restart: always
      command: daemon --docker
      environment:
        - TZ=${TZ}
      depends_on:
        - sogo-mailcow
        - dovecot-mailcow
      labels:
        ofelia.enabled: "true"
      security_opt:
        - label=disable
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock:ro
      networks:
        mailcow-network:
          aliases:
            - ofelia

    ipv6nat-mailcow:
      depends_on:
        - unbound-mailcow
        - mysql-mailcow
        - redis-mailcow
        - clamd-mailcow
        - rspamd-mailcow
        - php-fpm-mailcow
        - sogo-mailcow
        - dovecot-mailcow
        - postfix-mailcow
        - memcached-mailcow
        - nginx-mailcow
        - acme-mailcow
        - netfilter-mailcow
        - watchdog-mailcow
        - dockerapi-mailcow
        - solr-mailcow
      environment:
        - TZ=${TZ}
      image: robbertkl/ipv6nat
      security_opt:
        - label=disable
      restart: always
      privileged: true
      network_mode: "host"
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock:ro
        - /lib/modules:/lib/modules:ro

networks:
  mailcow-network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br-mailcow
    enable_ipv6: true
    ipam:
      driver: default
      config:
        - subnet: ${IPV4_NETWORK:-172.22.1}.0/24
        - subnet: ${IPV6_NETWORK:-fd4d:6169:6c63:6f77::/64}

volumes:
  vmail-vol-1:
  vmail-index-vol-1:
  mysql-vol-1:
  mysql-socket-vol-1:
  redis-vol-1:
  rspamd-vol-1:
  solr-vol-1:
  postfix-vol-1:
  crypt-vol-1:
  sogo-web-vol-1:
  sogo-userdata-backup-vol-1:
  clamd-db-vol-1:
```

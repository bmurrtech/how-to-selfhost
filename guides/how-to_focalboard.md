# Self-host Focalboard

![focalbaord_sampel](https://i.imgur.com/D96WVlz.png)

References:
- [Focalboard KB](https://www.focalboard.com/docs/personal-edition/ubuntu/)
- [NGINX TLS Guide](https://docs.nginx.com/nginx/admin-guide/security-controls/terminating-ssl-http/)
- [Let's Encrypt Certbot](https://certbot.eff.org/lets-encrypt/ubuntubionic-nginx)

## 1. Deploy Docker and Portainer
- See my guide [here](how-to_ultimate_proxmox.md#install-docker-compose).

## 2. Log into Portainer 
- Open a new URL, input `https://you-VM-WAN-IP:9443`

> Firewall Settings Note: You must ensure that the necessary ingress ports for your Portainer instance is accessible through your `default` firewall settings. Otherwise, you'll get a browser time out error. See above for tips.

- Follow the prompts to create a new admin account

 ![portainer_auto_lockout](https://i.imgur.com/JUY4F1e.png)
 
> For security reasonse, the Portainer first time login will auto-timeout, so you may need to run: `docker restart portainer` and try again.

## 3. Deploy Focalboard App Stack
We are going to deploy two separate `stacks` (or two separate `docker compose yaml` files if you are not using Portainer) to build A) the Focalboard app stack and B) reverse proxy and SSL certificate authority (for secure, HTTPS connections) within the same Docker network. Start by creating the Docker network with:

```docker
docker network create focalboard_network
```
> We need this pre-made network to attach our `stacks` to or else we will get "network focalboard_network declared as external, but could not be found" error which indicates that the Docker Compose file for NGINX and Certbot is referencing an external network (focalboard_network) that hasn't been created yet. This can happen when the network is declared as external in one Docker Compose file, but it hasn't been created beforehand or by another Docker Compose file.

### Focalboard App Stack
- Click `stack` and use the `Web Editor` to copy and paste the following `docker compose yaml` contents:

```yaml
version: '3.8'

services:
  focalboard:
    container_name: focalboard_app
    image: mattermost/focalboard
    volumes:
      - focalboard-data:/data
    ports:
      - "8001:8000"
    environment:
      - DB_TYPE=postgres
      - DB_HOST=db
      - DB_PORT=5432
      - DB_USER=focalboard
      - DB_PASSWORD=<CHANGEME>
      - DB_DATABASE=focalboard_db
    depends_on:
      - db
    restart: unless-stopped
    networks:
      - focalboard_network

  db:
    container_name: focalboard_db
    image: postgres:latest
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=focalboard_db
      - POSTGRES_USER=focalboard
      - POSTGRES_PASSWORD=<CHANGEME>
    restart: unless-stopped
    networks:
      - focalboard_network

networks:
  focalboard_network:
    driver: bridge

volumes:
  focalboard-data:
  postgres-data:
  ```
- Now, try accessing Focalboard directly via `http://your_server_ip:8001`

![no_SSL_focalboard_proof](https://i.imgur.com/ef8p7uH.png)

> If you are using a `standalone` or different DNS plugin than `webroot`, you may consider modifying the `yaml` file to account for this divergence. The specific configuration will vary depending on the plugin and your particular requirements. Make sure to refer to the documentation for your chosen method for any additional requirements or steps. If you are NOT using a web server (i.e. no NGINX reverse proxy), then refer to my [Certbot guide](how-to_certbot.md) for reference.

### Reverse Proxy & SSL Cert
- Repeat the process for the reverse proxy stack:

```yaml
version: '3.8'

services:
  nginx:
    container_name: nginx_proxy
    image: 'jc21/nginx-proxy-manager:latest'
    ports:
      - "4080:80"
      - "4443:443"
      - "4081:81"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    restart: unless-stopped
    networks:
      - focalboard_network

networks:
  focalboard_network:
    external: true
```

## 4. Configure Ngnix Reverse Proxy
If you want to remove the dreaded "Not Secure" from the URL bar for your Focalboard, you'll need a reverse proxy and Let's Encrypt SSL certificate. Here's how:

- Test that you NGINX directly via `http://your_server_ip:4081`

![correct_NGINX_screen](https://i.imgur.com/qE22rq7.png)

> Troubleshooting Note: You may encounter a NGINX broken screen that looks like this:
> ![incorrect_nginx_screen](https://i.imgur.com/LdwB72A.png)
> If you cannot reach the _correct_ login page for NGINX with the username and password fields (as pictured above), check your firewall settings and make sure to open _all three_ ports: `4443`, `4080`, and `4081` port to access it. It will NOT work unless you open up all three ports.

The following guide assumes: __A)__ You have already own an active domai and __B)__ you use Cloudflare to manage your DNS. To configure NGINX reverse proxy to manage SSL certificates for HTTPS connections, see [RaidOwl's Cloudflare x NGINX tutorial](https://youtu.be/GarMdDTAZJo?feature=shared&t=463). Simply modify the NGINX web UI settings specifically for Focalboard (which is __http__ and set the port as `8001` if you used my `yaml` configuration).
______________________________________________________________

WIP

## 3. Deploy New ULTIMATE Focalboard Stack
- In your `local` Portainer, click `Stacks` and copy and paste the following Focalboard `docker-compose.yaml`:

 ```yaml
version: '3.8'

services:
  focalboard:
    container_name: focalboard_app
    image: mattermost/focalboard
    ports:
      - "8001:8000"
    volumes:
      - focalboard-data:/data
    environment:
      - DB_TYPE=postgres
      - DB_HOST=db
      - DB_PORT=5432
      - DB_USER=focalboard
      - DB_PASSWORD=<CHANGEME>
      - DB_DATABASE=focalboard
    depends_on:
      - db
    networks:
      - focalboard_network
    restart: unless-stopped

  db:
    container_name: focalboard_db
    image: postgres:latest
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=focalboard
      - POSTGRES_USER=focalboard
      - POSTGRES_PASSWORD=<CHANGEME>
    networks:
      - focalboard_network
    restart: unless-stopped

  nginx:
    container_name: nginx_proxy
    image: nginx:latest
    ports:
      - "4080:80"
      - "4443:443"
      - "4081:81"
    volumes:
      - ./nginx/sites-enabled:/etc/nginx/sites-enabled
      - certbot-data:/etc/letsencrypt
      - ./nginx/certbot-www:/var/www/certbot
    depends_on:
      - focalboard
    networks:
      - focalboard_network
    restart: unless-stopped

  certbot:
    container_name: certbot_ssl
    image: certbot/certbot
    environment:
      - CERTBOT_EMAIL=your-email@example.com # Replace with your email address
    command: certonly --webroot --webroot-path=/var/www/certbot --agree-tos --no-eff-email -d yourdomain.com # Replace with your domain
    volumes:
      - certbot-data:/etc/letsencrypt
      - ./nginx/certbot-www:/var/www/certbot
    entrypoint: >
     /bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'
    depends_on:
      - nginx
    networks:
      - focalboard_network
    restart: unless-stopped

networks:
  focalboard_network:
    external: true

volumes:
  certbot-data:
  focalboard-data:
  postgres-data:
```
- You should now see 4 new containers created:

![4_new_focalboard](https://i.imgur.com/LpYRHQ3.png)

- Now, try accessing Focalboard directly via `http://your_server_ip:8001`

![no_SSL_focalboard_proof](https://i.imgur.com/ef8p7uH.png)

> If you are using a `standalone` or different DNS plugin than `webroot`, you may consider modifying the `yaml` file to account for this divergence. The specific configuration will vary depending on the plugin and your particular requirements. Make sure to refer to the documentation for your chosen method for any additional requirements or steps. If you are NOT using a web server (i.e. no NGINX reverse proxy), then refer to my [Certbot guide](how-to_certbot.md) for reference.

## 4. Configure Ngnix Reverse Proxy
If you want to remove the dreaded "Not Secure" from the URL bar, you'll need a reverse proxy and Let's Encrypt SSL certificate. Here's how:

- Test that you NGINX directly via `http://your_server_ip:4081`

![correct_NGINX_screen](https://i.imgur.com/qE22rq7.png)

> Troubleshooting Note: You may encounter a NGINX broken screen that looks like this:
> ![incorrect_nginx_screen](https://i.imgur.com/LdwB72A.png)
> If you cannot reach the _correct_ login page for NGINX with the username and password fields (as pictured above), check your firewall settings and make sure to open _all three_ ports: `4443`, `4080`, and `4081` port to access it. It will NOT work unless you open up all three ports.

- Assuming NGINX is loaded correctly, create a `focalboard` config file in `/etc/nginx/sites-enabled`. To access config files of containers, you have to use a special docker command via SSH such as:

```
docker exec -it <nginx_container_name> bash
cd /etc/nginx/sites-enabled
```

- Check you are in the right directory with `pwd` and if you are in `/etc/nginx/sites-enabled` proceed by creating a new config file with:

```
touch focalboard && nano focalboard
```
> If you get the error: `bash: nano: command not found` then you must intall `nano` first with `apt-get update && apt-get install nano -y`
> Note: You will have to perform this _everytime_ you use `docker exec`.

- Copy and paste the following configurations into `focalboard`:

```
upstream focalboard {
    server localhost:8001; # Ensure this matches the Focalboard container's internal port
    keepalive 32;
}

server {
    listen 80 default_server;
    server_name focalboard.example.com; # Replace with your domain

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name focalboard.example.com; # Replace with your domain

    ssl_certificate /etc/letsencrypt/live/focalboard.example.com/fullchain.pem; # Replace with your domain
    ssl_certificate_key /etc/letsencrypt/live/focalboard.example.com/privkey.pem; # Replace with your domain

    location ~ /ws/* {
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 50M;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        client_body_timeout 60;
        send_timeout 300;
        lingering_timeout 5;
        proxy_connect_timeout 1d;
        proxy_send_timeout 1d;
        proxy_read_timeout 1d;
        proxy_pass http://focalboard;
    }

    location / {
        client_max_body_size 50M;
        proxy_set_header Connection "";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        proxy_read_timeout 600s;
        proxy_cache_revalidate on;
        proxy_cache_min_uses 2;
        proxy_cache_use_stale timeout;
        proxy_cache_lock on;
        proxy_http_version 1.1;
        proxy_pass http://focalboard;
    }
}
```
- After making these changes, make sure to test the configuration with `nginx -t` and then reload NGINX to apply them with `nginx -s reload`
- In this configuration:

  - The first `server` block listens on port 80 (HTTP) and includes a location directive to serve the Let's Encrypt challenge files from `/var/www/certbot`. It also redirects all HTTP traffic to HTTPS.

  - The second `server` block listens on port 443 (HTTPS) and includes the SSL certificate configurations for `focalboard.example.com`. It serves both the WebSocket endpoints (/ws/*) and regular HTTP traffic, proxying requests to the Focalboard application.

  - Replace `focalboard.example.com` with your actual domain and ensure the paths to the SSL certificates match where Let's Encrypt places them on your server.

  - Make sure the `upstream focalboard` section is correctly pointing to your Focalboard server's address and port. The example uses `localhost:8000`, but this should match your actual Focalboard setup.

  - This combined configuration should handle SSL termination with Let's Encrypt certificates and proxy requests to Focalboard while ensuring secure WebSocket connections.

- Remember to reload or restart NGINX after making these changes for them to take effect. After adding the necessary custom config, type `exit` and then restart the `nginx` container with: `docker restart <container_name_of_nginx>` to apply the config settings.

## 5. Configure Your DNS Settings

Prerequisites
-------------

*   **DNS Management Access**: You need access to your domain's DNS management panel, typically provided by your domain registrar.
*   **Public WAN IP**: The public WAN IP address of your VM.

Step-by-Step Instructions
-------------------------

### Step 1: Access DNS Management

1.  **Log In**: Go to your domain registrar's website and log in.
2.  **DNS Section**: Navigate to the DNS management section. This may be labeled as 'DNS Settings', 'Manage Domains', or 'DNS Zone Editor'.

### Step 2: Locate DNS Records

1.  **DNS Records**: In the DNS management area, find where you can view and edit DNS records.
2.  **Record Types**: You'll see various record types like A, CNAME, MX, etc.

### Step 3: Update the A Record

1.  **Find/Edit A Record**: Locate the A record for your domain. Edit this record, or create a new one if it doesn't exist.
2.  **Configure Record**:
    *   **Host Name/Name**: Set this to `@` for your root domain or a specific subdomain like `www`.
    *   **IP Address/Points to**: Enter your VM's public WAN IP address.
3.  **Save Changes**: Apply and save the modifications.

### Step 4: Verify the Update

1.  **Propagation Time**: DNS updates can take from a few minutes up to 48 hours to fully propagate.
2.  **Check Propagation**:
    *   Use `nslookup`:
        
        bashCopy code
        
        `nslookup yourdomain.com`
        
    *   Or `dig`:
        
        bashCopy code
        
        `dig yourdomain.com`
        
3.  **Expected Result**: Your domain should resolve to your VM's public WAN IP after propagation.

### Step 5: Configure NGINX

1.  **NGINX Setup**: Make sure your NGINX on the VM is set up to handle requests for your domain.
2.  **Edit NGINX Config**: Update NGINX configuration to listen to your domain and proxy requests appropriately.

Additional Notes
----------------

*   **Firewall and Security**: Make sure the VM's firewall allows traffic on HTTP/HTTPS (port 80/443).
*   **Dynamic WAN IP**: If you have a dynamic WAN IP, consider using a Dynamic DNS (DDNS) service.

* * *

_Replace `yourdomain.com` with your actual domain name and adjust the VM details as needed._
export this as markdown .md text into a text file

## 6. (Optional) Auto-renew SSL Cert
Since the following snippet was already included in the `docker-compose.yaml` above, a cron job to renew SSL is not necessary. However, if you are following the official Focalboard guide and didn't use Docker to create your Focalboard, then this cron job step is important.

```yaml
entrypoint: >
  /bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'
```

Before dicussing the cron job, allow me to explain the logic and comparision of SSL certificat renewal methods in Docker.

Comparing SSL Certificate Renewal Methods in Docker
---------------------------------------------------

Both methods are designed to renew SSL certificates managed by Certbot, but they have different approaches and execution timings.

### Method 1: Continuous Loop with `sleep` in Entrypoint

`entrypoint: >   /bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'`

*   **Continuous Loop**: This approach runs an infinite loop within the container.
*   **Renewal Frequency**: Executes `certbot renew` every 12 hours.
*   **Signal Responsiveness**: Uses `trap exit TERM` to respond correctly to shutdown signals.
*   **Pros**:
    *   Self-contained renewal mechanism.
    *   The container continuously checks for certificate renewal.
*   **Cons**:
    *   The container remains running, which might be slightly more resource-intensive.

### Method 2: Direct Renew Command in Entrypoint

`entrypoint: certbot renew --webroot --webroot-path=/var/www/certbot`

*   **Single Execution**: Runs the `certbot renew` command once upon container startup.
*   **No Looping**: Lacks an internal looping or scheduling mechanism.
*   **Webroot Plugin**: Specifies the `--webroot` plugin for serving challenge files.
*   **Pros**:
    *   Simple and straightforward.
    *   Executes renewal as a one-time action per container startup.
*   **Cons**:
    *   Requires container restart or external scheduling for periodic renewal checks.

### Summary

The first method offers a self-sufficient, continuously running solution ideal for Docker environments. The second method is simpler but requires external mechanisms to ensure frequent enough execution for timely certificate renewals. To create a cron job that updates the SSL certificate using Certbot every 30 days, you will need to edit the crontab file on your server where Docker and Certbot are running. Here's how you can do it:

### Create a Cron Job (non-Docker Method)

1.  **Open the Crontab Configuration**:
    
    *   Open a terminal on your server.
    *   Type `crontab -e` to edit the crontab for the current user. If you need to edit the crontab for the root user (which might be necessary for Docker commands), use `sudo crontab -e`.
2.  **Add the Cron Job**:
    
    *   Add the following line to the crontab file:
        
        rubyCopy code
        
        `0 0 1 * * /usr/bin/docker run --rm --name certbot -v "/etc/letsencrypt:/etc/letsencrypt" -v "/var/lib/letsencrypt:/var/lib/letsencrypt" certbot/certbot renew`
        
    *   This cron job runs at midnight on the first day of every month. Certbot automatically checks if the certificate is due for renewal (it renews if the certificate is within 30 days of expiration).
3.  **Save and Exit**:
    
    *   Save and exit the editor. In vi or vim, you can do this by typing `:wq` and then pressing Enter.
4.  **Verify the Cron Job**:
    
    *   Verify that your cron job is correctly scheduled by listing the cron jobs: `crontab -l`.
5.  **Ensure Correct Volume Mappings**:
    
    *   Make sure that the paths you map into the Certbot container (`/etc/letsencrypt` and `/var/lib/letsencrypt`) correctly correspond to where your certificates and Let's Encrypt data are stored on the host machine. Adjust the paths if necessary.
6.  **Docker Permissions**:
    
    *   If you are running this cron job as a non-root user, make sure that your user has permissions to run Docker commands.

### Notes:

*   Certbot's `renew` command is intelligent and only attempts renewal if the certificate is nearing expiration (within 30 days).
*   Running the renewal command frequently (like daily) is generally fine, as Certbot only renews certificates close to expiration. However, it's a common practice to run the renewal process less frequently (like once a month) to reduce unnecessary operations.
*   Always ensure your server's time zone is correctly set, as cron jobs rely on the system clock.


ref: https://ghost.org/docs/install/ubuntu/

ref. 2: https://codecurated.com/blog/how-to-set-up-a-self-hosted-ghost-blogging-platform/

ref. 3: non-docker install: https://www.youtube.com/watch?v=99FzAidIHXs&t=78s

ref. 4: ghost-cli: https://ghost.org/docs/ghost-cli/

# Contents

- Docker Compose `yaml` Files
- [Deployment Overview](#deployment-overview)
- [Setting Up DNS Records in Cloudflare for a Blog Subdomain](#setting-up-dns-records-in-cloudflare-for-a-blog-subdomain)
- [Configure Cloud Firewall for Cloud Self-hosting](#configuring-a-firewall-on-a-digital-ocean-droplet)

## Deployment Overview

You can approach the deployment in a couple of ways:

### A) Using an Orchestration Tool like Portainer (Preferred)
This method is recommended for editing `.env` variables easily and managing stacks visually. 

### B) CLI Deployment
This method will not be covered in this guide, but you can access the `docker-compose.yml` files at `/docker_projects/` of this repository.

### Overview

1. **Cost Savings**: Most importantly, this method saves you $31/month (see [Ghost Pricing](https://ghost.org/pricing/)), as it is an open-source blog platform and enables 1000+ integrations that are not available in the cheaper starter plan.
2. **Firewall Configuration Assumptions**: This guide assumes you have properly configured your firewall to permit ports 80 and 443. For self-hosting, I suggest using ProxMox as your hypervisor, pfSense as your virtual firewall, and port forwarding those ports to the static IP address of the pfSense VM.
3. **VM Specifications**: To host your own Ghost blog securely, you'll need a VM with minimum specifications as follows:
   - **CPU**: 1 vCPU
   - **RAM**: 2 GB
   - **Storage**: 10 GB SSD (minimum)
   - **Network**: Static IP address
   I suggest self-hosting, as you can convert an old laptop into a webserver Ghost blog, but you can also use a VPS hosting provider like Digital Ocean (just avoid ARM CPU architecture, as I encountered compatibility issues here).
4. **Ghost-Stack and Reverse Proxy**: You will need to use my Ghost-Stack (which includes a MySQL database) and a separate reverse proxy container build using Traefik. A link to the `docker-compose.yml` files for each, including a `traefik.yml` template to get you started, may be found at `/docker_projects/`.

## Step 1: Deploy Traefik
See `/docker_projects/traefik` for details, but essentially you must:

1. **Create a Folder for Traefik Config File**: Navigate to your folder path where you want the Traefik compose file, then create a `config` folder inside it.
2. **Download Traefik Config File**: Use the following `wget` command to download the configuration file:
   ```bash
   wget <placeholder URL for traefik.yaml>
   ```
3. **Configure Traefik**: Edit the config file using your favorite text editor and change the email address to your email.

Take special note that if you want to enable the Traefik Web UI/dashboard (which is not recommended for production), you'll need to uncomment the following lines:

```yaml
api:
  dashboard: true
  insecure: true
```

Since this guide assumes you have already pre-configured Cloudflare and have an API token for the `dnsChallenge`, we will leave the `httpChallenge` commented out (change this if your situation is different along with the provider you are using).

Lastly, the "staging" section for certificate resolution is for testing purposes to avoid getting rate-limited by Let's Encrypt (5 certs per hour is the limit). If you are not worried about this, comment out the staging section and uncomment the "production" section instead. For more details on this process, watch Christian Lempa's video [here](https://www.youtube.com/watch?v=wLrmmh1eI94). Note that we are using variables slightly differently in this guide.

After configuring Traefik, use the `Stacks > Repository` feature in Portainer to pull the `docker-compose.yml`:

1. Navigate to `Stacks > Repository`.
2. Enter the `.git` URL for `docker_projects` and designate `/traefik/docker-compose.yml`.
3. Launch the stack and check the logs to ensure it's functional.

## Step 2: Deploying the Ghost Blog Stack

1. **Create a New Folder**: Create a new folder to house the files for your new Ghost blog.
2. **Deploy the Stack**: Navigate to `Stacks > Repository` in Portainer and enter the `.git` URL as you did for the Traefik setup, but this time use `/ghost_blog/docker-compose.yml`.
3. **Set Environment Variables**: Check the `.env.staging.example` and `.env.production.example` files in the repo at `docker_projects/ghost_blog` to determine which environment you want to use. Assuming you want production right away, set your variables accordingly.
4. **Deploy**: Deploy the stack, and Traefik will automatically route inbound traffic to the Ghost blog.

## Step 3: Securing Your Ghost Admin Login
To secure your Ghost admin login, I suggest using Cloudflare Zero Trust tunneling to the `/ghost` login page. If you cannot use Zero Trust or Teleport for two-factor authentication (2FA), ensure that you set a strong password to protect it. Without additional security measures like Zero Trust, brute-force attacks are a potential risk.

This should get you going! See the rest for how to set up your DNS records to access your Ghost blog from the web.

## Setting Up DNS Records in Cloudflare for a Blog Subdomain

### Step 1: Add an A Record for the Blog Subdomain

1. **Log in to Cloudflare**: Go to your Cloudflare dashboard and select the domain you're working with.
2. **Navigate to the DNS Management Section**: Find the DNS settings page.
3. **Create an A Record**:
   - **Type**: Select "A" from the dropdown menu.
   - **Name**: Enter `blog` as the name. Cloudflare automatically appends the domain, resulting in `blog.yourdomain.com`.
   - **IPv4 address**: Enter the IP address of your VPS where the blog is hosted.
   - **Proxy status**: Decide if you want the traffic proxied through Cloudflare (recommended for additional security and performance optimization).
   - **Save**: Add the record by clicking "Save".

### Step 2: Configure CNAME Record for WWW Subdomain

If you want `www.blog.yourdomain.com` to reroute to `blog.yourdomain.com`, create a CNAME record:

1. **Create a CNAME Record**:
   - **Type**: Select "CNAME".
   - **Name**: Enter `www.blog`.
   - **Target**: Enter `blog.yourdomain.com`.
   - **Proxy status**: Typically, keep it consistent with your A record.
   - **Save**: Click "Save" to add the record.

### Additional Notes

- **SSL/TLS Configuration**: Ensure SSL/TLS certificates are set up for secure connections. Cloudflare offers flexible SSL settings for domains proxied through it.

## Configuring a Firewall on a Digital Ocean Droplet

### Step 1: Enable UFW and Set Defaults

This sets the firewall to deny all incoming connections by default.

### Step 2: Allow Necessary Ports

Allow traffic for:
- **SSH (Port 22)**: To manage your server.
- **HTTP (Port 80) and HTTPS (Port 443)**: For web traffic.

For MySQL, allow connections only from the application server if necessary:

### Step 3: Enable UFW

### Step 4: Verify Firewall Status

### Best Practices for Firewall Configuration

- **Principle of Least Privilege**: Open only essential ports.
- **Secure SSH Access**: Change the SSH port from 22 to a non-standard port and use key-based authentication.
- **Database Security**: Limit MySQL access to localhost or use an SSH tunnel for remote connections.



## Configuring a Firewall on a Digital Ocean Droplet

When configuring a firewall on a Digital Ocean droplet (or any VPS) that's serving as an Nginx reverse proxy for a blog site, along with SSH access and a MySQL database, you'll want to ensure that only the necessary ports are open to maintain security. Here's a basic setup using `ufw` (Uncomplicated Firewall) on Ubuntu, which is commonly pre-installed. If your VPS uses a different operating system or you prefer another firewall tool, the principles remain the same but the commands might differ.

### Step 1: Enable UFW and Deny All Incoming Traffic by Default

```bash
sudo ufw default deny incoming
```

This command sets the firewall to deny all incoming connections, which is a secure default stance.

### Step 2: Allow Necessary Ports

You'll need to allow traffic on a few specific ports:

- **SSH (Port 22)**: To manage your server.
- **HTTP (Port 80) and HTTPS (Port 443)**: For web traffic to your Nginx reverse proxy.
- **MySQL (Port 3306)**: Only if necessary from external sources. It's more secure to only allow local connections unless remote access is absolutely needed.

```bash
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
```

For MySQL, consider if you truly need remote access. If your application and database run on the same server, or if you can connect to the database via an SSH tunnel, you don't need to open the MySQL port (3306) to the public. If your application is on a different server than your database, then you'll need to:

```bash
sudo ufw allow from [Application Server IP] to any port 3306
```

Replace `[Application Server IP]` with the IP address of the server needing to access MySQL.

### Step 3: Enable UFW

After configuring your rules:

```bash
sudo ufw enable
```

This command starts the firewall and applies your configuration.

### Step 4: Check Your Firewall Status

```bash
sudo ufw status
```

This command shows which rules are active to verify your configuration.

### Best Practices for Firewall Configuration

1. **Principle of Least Privilege**: Only open the ports that are absolutely necessary for your application to function. If a service doesn't need to be accessed from outside, it's best to keep its ports closed or restrict access to specific IP addresses.

2. **Secure SSH Access**:
   - Consider changing the default SSH port (22) to a non-standard port.
   - Use SSH key-based authentication instead of passwords for added security.
   - Implement fail2ban or a similar tool to protect against brute-force attacks.

3. **Database Security**:
   - If possible, avoid exposing your MySQL server to the public internet. Use local connections or secure, encrypted tunnels for remote access.
   - Regularly update and patch your MySQL server to protect against vulnerabilities.

4. **Regularly Review Firewall Rules**: Over time, your application's requirements may change. Regularly review and update firewall rules to remove unnecessary allowances.

5. **Use Connection Limiting and Rate Limiting**: `ufw` is relatively basic, but if you're using more advanced firewall tools or directly configuring iptables, consider rules that limit connection attempts and rates to mitigate DDoS attacks.

By following these steps and best practices, you'll significantly enhance the security of your Digital Ocean droplet or any other VPS running a blog with Nginx, SSH access, and a MySQL database.

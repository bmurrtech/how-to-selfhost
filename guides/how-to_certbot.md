# About Certbot
Certbot is a free, open-source software tool for automatically using Let's Encrypt certificates on manually-administered websites to enable HTTPS. It's designed to simplify the process of obtaining, installing, and renewing SSL/TLS certificates. Here's a summary of its key aspects:

1. Automated Certificate Management: Certbot can automate the certificate issuance and installation process with Let's Encrypt, an ACME (Automated Certificate Management Environment) server. It handles the process of validating domain ownership and installing the certificate on a web server.
1. Let's Encrypt Integration: Certbot is primarily designed to work with Let's Encrypt, a free, automated, and open Certificate Authority (CA). It makes it easy for website owners to secure their sites with HTTPS.
1. Ease of Use: The tool is user-friendly and aims to provide a hassle-free experience for obtaining SSL/TLS certificates. It simplifies the complex process of certificate management.
1. Various Plugins: Certbot supports various plugins that extend its functionality. These plugins can be used for different web servers (like Apache, NGINX) and for different DNS providers (like Cloudflare, Google DNS) to automate the DNS challenge process.
1. Automatic Renewals: Certbot includes the ability to automatically renew certificates before they expire. This ensures continuous HTTPS protection without manual intervention.
1. Security Focused: By enabling HTTPS, Certbot enhances the security of websites, protecting the data transmitted between the user and the site from eavesdropping and tampering.
1. Wide Compatibility: Certbot is compatible with many operating systems and web server configurations, making it a versatile tool for a broad range of environments.

In summary, Certbot is a crucial tool for website administrators aiming to secure their sites with HTTPS, providing an automated, efficient, and free solution for certificate issuance and management.

### Certbot Configuration in Docker Compose Without Webroot Plugin

If you're not using the Certbot `webroot` plugin, you need to configure the Certbot service in your Docker Compose YAML file differently based on the method you are using, such as `standalone`, `dns`, etc.

#### Using Standalone Plugin

The `webroot` plugin for Certbot is used for obtaining SSL/TLS certificates from Let's Encrypt when you already have a web server running. It works by placing a special file (for the ACME challenge) in the `.well-known/acme-challenge` directory within your web server's root directory. Let's Encrypt then verifies this file to prove control over the domain and issue an SSL certificate.

- __When to Use `webroot`__: Use the `webroot` plugin when you have a web server like NGINX or Apache already serving content, and you can place files in its root directory.

- __How it Works__: You tell Certbot where your web server's root directory is, and it places the ACME challenge file in that location.

- __In Our Use Case__: Running Focalboard Without a Web Server (i.e. no NGINX or Apache)
For our use case with Focalboard we ARE using NGINX, so a `standalone` DNS plugin is NOT required:
  - No Separate Web Server: If Focalboard is the only application running and you don't have a separate web server like NGINX or Apache, you may not be able to use the webroot plugin, since Focalboard itself doesn't serve arbitrary files from a directory.
  - Alternative - Standalone Plugin: Instead, you might use Certbot's standalone plugin. This plugin spins up a temporary web server specifically for the ACME challenge. It's useful if you can afford to briefly stop your web server or don't have one running:

The `standalone` plugin is used when no web server is running, or you can temporarily stop your web server. It creates a temporary web server for the ACME challenge. Here’s how to set it up:

```yaml
services:
  certbot:
    image: certbot/certbot
    command: certonly --standalone --preferred-challenges http --email your-email@example.com --agree-tos --no-eff-email -d yourdomain.com
    # ...
```

#### Using DNS Plugin
- DNS Plugin Use Case: DNS plugins are typically used for wildcard certificates or when you can't expose ports 80/443 (required for the HTTP challenge).
- Our Scenario: If you're running Focalboard behind a firewall or in a context where ports 80/443 are not exposed to the internet, a DNS plugin might be more suitable. It proves domain control by creating DNS records.
- Plugin Choice: The choice of DNS plugin depends on your DNS provider (like Cloudflare, Google DNS, AWS Route 53, etc.). Each provider has a specific Certbot DNS plugin.

For DNS plugins, which are common for wildcard certificates or when ports 80/443 can't be exposed, the setup depends on your DNS provider. For example, with the `dns-digitalocean` plugin:

```yaml
services:
  certbot:
    image: certbot/dns-digitalocean
    environment:
      - CERTBOT_EMAIL=your-email@example.com
      - DO_API_TOKEN=your_digitalocean_api_token
    command: certonly --dns-digitalocean --dns-digitalocean-credentials /path/to/credentials.ini --agree-tos -d yourdomain.com
    volumes:
      - digitalocean_credentials:/path/to/credentials.ini
      - certbot-data:/etc/letsencrypt
    # ...
```

        To modify your Docker Compose YAML file for use with the Cloudflare DNS plugin for Certbot, you'll need to use the `certbot/dns-cloudflare` Docker image and provide the necessary Cloudflare credentials. The Cloudflare plugin utilizes an API token to safely interact with your Cloudflare account for DNS-based challenges.

Here's how you can set up the Docker Compose configuration:

1.  **Cloudflare Credentials**:
    
    *   Create a Cloudflare API token with the necessary permissions to modify DNS records.
    *   Store your Cloudflare credentials in a file. This file typically contains lines like:
        
        javaCopy code
        
        `dns_cloudflare_email = your-email@example.com dns_cloudflare_api_key = your_api_key`
        
        Replace `your-email@example.com` and `your_api_key` with your actual Cloudflare account email and API token.
2.  **Docker Compose Configuration**:
    

yamlCopy code

`version: '3.8'  services:   certbot:     image: certbot/dns-cloudflare     volumes:       - ./path/to/cloudflare.ini:/etc/letsencrypt/cloudflare.ini       - certbot-data:/etc/letsencrypt     environment:       - CERTBOT_EMAIL=your-email@example.com     command: certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini --agree-tos -d yourdomain.com     # ... other configurations ...  volumes:   certbot-data:   # ... other volumes ...`

In this configuration:

*   Replace `./path/to/cloudflare.ini` with the actual path to your Cloudflare credentials file on the host machine.
*   Replace `your-email@example.com` with the email associated with your Cloudflare account.
*   Replace `yourdomain.com` with the domain you're securing with SSL.

3.  **Security Note**:
    *   Ensure the `cloudflare.ini` file has restrictive permissions, as it contains sensitive information. Typically, it should be readable only by the user running the Certbot process.
    *   You might use `chmod 600 cloudflare.ini` to set these permissions.

After updating your Docker Compose file, apply the changes with `docker-compose up -d`. This setup will enable Certbot to automatically handle the DNS challenges via Cloudflare for your SSL certificates.

#### General Notes
- Adjust the command in the service definition to reflect the specific plugin and options you need.
- Ensure you have the necessary volume mounts if your chosen method requires access to specific files (like API credentials for DNS plugins).

- To configure Certbot to work with Google Cloud Platform's DNS for automated SSL certificate issuance using DNS challenges, you'll need to use a Docker image that supports the Certbot DNS plugin for Google Cloud DNS. You'll also have to provide the necessary credentials for Certbot to interact with your Google Cloud DNS.

Here's how you can set up your Docker Compose configuration for Google Cloud DNS:

1.  **Google Cloud Credentials**:
    
    *   Create a service account in your Google Cloud project.
    *   Grant this service account permission to manage DNS entries (DNS Administrator role is typically sufficient).
    *   Create and download a JSON key for this service account.
2.  **Docker Compose Configuration**:
    

yamlCopy code

`version: '3.8'  services:   certbot:     image: certbot/dns-google     volumes:       - ./path/to/your/google-credentials.json:/etc/letsencrypt/google-credentials.json       - certbot-data:/etc/letsencrypt     environment:       - GOOGLE_APPLICATION_CREDENTIALS=/etc/letsencrypt/google-credentials.json       - CERTBOT_EMAIL=your-email@example.com     command: certonly --dns-google --dns-google-credentials /etc/letsencrypt/google-credentials.json --agree-tos -d yourdomain.com     # ... other configurations ...  volumes:   certbot-data:   # ... other volumes ...`

In this configuration:

*   Replace `./path/to/your/google-credentials.json` with the actual path to your Google Cloud service account JSON key file.
*   Replace `your-email@example.com` with the email address you wish to use for Certbot notifications.
*   Replace `yourdomain.com` with your domain name.

3.  **Security Note**:
    *   Ensure the service account JSON key file (`google-credentials.json`) has restrictive permissions, as it contains sensitive credentials.
    *   Use a command like `chmod 600 google-credentials.json` to set these permissions.

After updating your Docker Compose file, apply the changes by running `docker-compose up -d`. This setup will enable Certbot to automatically handle DNS challenges through Google Cloud DNS for your SSL certificates.

Always ensure you follow best practices for handling credentials and limit the permissions of the service account to only what is necessary.

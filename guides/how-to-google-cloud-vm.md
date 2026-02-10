# Google Cloud Platform (GCP) Free Account and VM Setup Guide

## 1. Creating a New Free Account on Google Cloud Platform
- Visit [Google Cloud Platform](https://console.cloud.google.com).
- Click on "Get started for free" to sign up.
- Follow the prompts to create your account. This will require you to provide billing information, but you won't be charged unless you upgrade.

## 2. Logging in for the First Time
- Once your account is created, log in at [Google Cloud Console](https://console.cloud.google.com).
- You may be prompted to take a tour or see an overview; you can choose to skip or take the tour.

## 3. Navigating to Compute Engine and Enabling API
- In the Google Cloud Console, navigate to the hamburger menu (☰) on the top left.
- Go to "Compute Engine" > "VM instances."
- If prompted, enable the Compute Engine API for your project.

## 4. Creating a VM Instance
- Click on "Create Instance."
- For **Name**, choose a unique name for your VM.

### Selecting Machine Type and Region
- Under **Machine type**, select "e2-micro" (2 vCPUs, 1 GB memory), which is eligible for the free tier.
- Choose a **Region** and **Zone** that are part of the free tier. Refer to the [Free Tier Requirements](https://cloud.google.com/free/docs/free-cloud-features) for available options.
- Set the Book disk size to 30GB
- Change the book disk to the following settings (standard persistent disk is the free tier):

![boot_disk](https://i.imgur.com/2oAFsoE.png)

### Free Tier Specs:
![freetier](https://i.imgur.com/zDzU8E9.png)

### Network and Egress Settings
- Under **Networking**, select "standard" for **Network Service Tier**.
- **Note**: Choosing "standard" tier can save costs, but be aware of potential charges if your usage exceeds 1GB of outbound data transfer.

### Adding SSH Key
- Generate a custom public key using PuTTY in the format: `ssh-rsa AAAZ...key-blob...10ea/ username@example.com`.
- In the VM instance creation screen, expand "Advanced options."
- Navigate to **Security** > **SSH Keys**.
- Click on "Add Item" and paste your SSH public key.

## 7. Creating the Instance
- Review your settings and click "Create" to deploy your VM instance.

## 8. Hardening the VM Instance
- Once the VM is created, go back to the main menu.
- Navigate to "VPC Network" > "Firewall rules."
- Remove default rules and create custom rules for enhanced security.
- Use a service like [What's My IP](https://www.whatsmyip.org/) to find your home IP address.
- Create a new rule with your IP as the source and allow only essential ports (like TCP 22 for SSH).
- Your rules should look something like this (in my case, I'm running a Portainer container in Docker, and need TCP ports 9000, 9443, and 443 open to access the web UI):
![gcp-fw-rules-ex](https://i.imgur.com/xdagFMe.png)

## 9. Connecting to the VM via SSH
- For **PuTTY**, use the generated private key and the external IP of the VM to connect.
- For **terminal**, use the command: `ssh -i /path/to/private_key username@external_ip_of_VM`.

**Important Note**: Always monitor your usage to avoid unexpected charges, especially when your usage exceeds the free tier limits.

## 10. Self-host Some Stuff!
Now that you have your own sever in the cloud, it's time to put it to good use!

See my related guides (left navigation pane) for self-hosting ideas and guides.
- Self-host a Jupyter Lab (great for coding on the go!)
- Self-host a Focalboard (project organizer/team collaboration tool like Trello or Notion)
- Self-host a Minecraft Server
- Self-host a 24-7 Livestream
- Self-host an Email Server
- More how-to self-hosting guides in the pipleline!

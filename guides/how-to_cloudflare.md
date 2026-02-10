#### Cloudflare DDNS Reverse Proxy
- Instead of setting up Tailscale or enduring the ardous process of installing an enterprise-grade load-balancer like Kemp, you can get a DDNS and reverse proxy setup via CloudFlare in 15 minutes.
- [NetworkChuck made a video tutorial](https://www.youtube.com/watch?v=ey4u7OUAF3c) about this, but here's the steps:
- Buy a domain and create a Cloudflare Nameserver (DNS > Records > Nameservers).
- Copy the nameservers and add them to your domain registrar (nameserver updates can take up to 24hrs, but it is usually updated within minutes).
- Using [ZeroTrust](https://one.dash.cloudflare.com/899e8be9fba8f3cc125ebdf9263380e0/home/quick-start) create a new tunnel: [ZeroTrust](https://i.imgur.com/FipaEgQ.png) (left navigation pane) > Cloudflare ZeroTrust (navigation pane) > Access (dropdown) > [Tunnels](https://i.imgur.com/nnONYTE.png) > Create at tunnel (button)
 - Enter the domain name you created...

![zero_trust](https://i.imgur.com/FipaEgQ.png) ![ztunnels](https://i.imgur.com/nnONYTE.png)

# Secure Homelab
- Exposing your homelab to the wide-web can be a major security risk unless you implement cybersecurity measures such as IP blocking, 2FA/MFA, and limiting the exposed ports.
- Using Cloudflare's IP whitelisting, a dedicated IP VPN service, and implementing 2FA/MFA, it is possible to mitigate cybersecuirty attacks.
- Cybersecuirty to-do:
 - Cloudflare/Kemp: Close ports.
 - Cloudflare: Block countries.
 - Cloudflare: Whitelist home IP and VPN IP (requires a dedicated IP address throug a VPN provider).
 - Authelia: Integrate Authelia with Cloudflare.
 - [Dashy](https://dashy.to) serves as a single pane of glass for all your homelab web apps.

#### Cloudflare Limit Access
- You can protect your self-hosted homelab and any other web services configured with Cloudflare Zero Trust. Here's how:
- Navigate to Cloudflare > Zero Trust > Access (dropdown, under "Zero Trust overview" pane) > Applications > Add an application (button)
![zero_trust_add_app](https://i.imgur.com/z3hxtjN.png)
- Selected "Self-hosted"
- Enter an application name
- Set the time-out duration for the access granted (default is 24hrs)
![zero_trust_app_config1](https://i.imgur.com/Q6LOjVe.png)
- (Optional) Set a custom application logo (you cannot change this later, so set it to default or upload your icon now)
- Toggle __off__ the "Accept all available identity providers" to enable the one-time PIN and click Next.
- In the "Add policies" section, enter a policy name (ex. geo, pin, iprange)
- To set a one-time pin, choose: __Login Methods__ (under selector dropdown) > __One-time PIN__ (check the box)
- To set a one-time pin, choose: __Emails__ (under selector dropdown) > __Enter your email__ (inside the _Value_ field)
> Note: You can add more than one approved email to grant access to more users.
- (Recommended) To limit access to a specific country: Click the __"Add require"__ and k
> Dedicated VPN: If you do not wish to use the one-time PIN and email setup, you can always opt for the __IP Ranges__ and enter the dedicated IP address of your VPN. That way, when you wish to gain access, all you need is a VPN connection.
- Continue and leave all the other settings as default and then save the configuration.
- Test the connection by entering the domain in a web browser and you should be prompted to enter your email.
> Note: Cloudflare will only send a PIN to the email(s) you whitelisted.
- Check your email for a PIN; enter it and you're in!

### Authelia
- [Authelia](https://authelia.com) is a SSO (Single Sign-on: requiring one-time signin for wide-range of apps via a session cookie) which supports 2FA/MFa and password reset. Authelia also prevents brute-force login attempts. It's the perfect gateway secuirty solution for homelabs (and businesses).
- There are two options to implementing Authelia in your homelab environment: 
 - [Authelia + Dashy](https://dashy.to/docs/authentication/)
 - Authelia + Cloudflare
- Since we want the ability to access our homelab applications from the public internet, and since we are utlilizing Cloudflare as a reverse proxy and DDNS to make that possible (because most ISPs periodically change tenants public IPs), the Authelia + Cloudflare integration is ideal.
- For integrating Authelia with Cloudflare, see Tamimology's [incredible Authelia + Cloudflare guide](https://github.com/tamimology/cloudflare-authelia)

#### Authelia + Cloudflare
Authelia integration with Cloudflare's free Zero Trust Tunnel service. Both [Authelia](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/generic-oidc/) and [Cloudflare](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/generic-oidc/) have set-up documentation.
- Login to Cloudflare and navitage to: Zero Trust > Settings (under Zero Trust overivew) > > Login Methods > Add new (button) > OpenID Connect > Enter all parameters.

#### IP Blocking
- In Cloudflare's settings, you can create default rules and group polices to block non-whitelisted IP address from accessing your homelab services
- This is especially good if:
 - A) You want to be extra cautious
 - B) Only you and people on your home network need access to your homelab apps
 - C) You (and your friends) have a dedicated VPN IP address you can use to access your homelab when abroad
- Keep in mind that IP blocking requires:
 - A) You have a dedicated VPN IP address
 - B) You only use your homelab when connected to your home network

#### Geo-blocking
- Limit public internet access to your homelab to only your home country
- This is especially good to enable in Cloudflare's settings if you plan to use a VPN service to connect to your homelab.

# Ad Blocking
- DietPi VM running PiHole. Done.

# VNC
- Thanks to [Apache Gauacamole](https://guacamole.apache.org) and HTML5-supported web browsers like Chrome and Firefox, you could run Windows on an iPhone! Or you could You can access an Ubuntu desktop on a Windows laptop. Basically, if any device has an internet connection and a web browser, you can take control of any VM on your Proxmox server.

#### RDP to VM via Cloudflare Tunnel
One great use-case of Cloudflare Tunnel is [Remote Desktop connection](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/use_cases/rdp/).
- iOS RDP options:
 - [Jump Desktop](https://jumpdesktop.com/), supports RD Gateway.
 - [RDP Lite](https://apps.apple.com/us/app/remote-desktop-rdp-lite/id288362576), supports traditional RDP. See the [connection steps](how-to-connect) below.
 - [Microsoft Moble RDP](https://apps.apple.com/us/app/microsoft-remote-desktop/id714464092)
 - [AnyDesk](https://apps.apple.com/us/app/anydesk-remote-desktop/id1176131273?platform=ipad), a client-server VNC.

#### How to Connect via RDP Apps
After you’ve configured a published service on the VM, you can use an iOS app to connect to the VM over RDP. There are a number of RDP apps for iOS. To illustrate how these work, this example uses RDP Lite. RDP Lite contains all the functionality necessary to connect to a VM with standard RDP.

- Launch the RDP Lite app, and tap Add another PC in the left-hand menu. In the Configure tab, tap New to enter settings for this connection:RDPlite configuration
- In PC Address, enter the published services URL (such as “services-uswest.skytap.com”).
- In PC Port, use the port listed at the end of the public address generated by the VM published service (so if the public address was `[UUID].[yourdomain]:12345` you’d enter 12345).
- Enter the PC User name and PC Password for guest OS account you’re logging into.
- Tap Connect on the left-hand side and select your new connection.
- An RDP window opens and prompts you to login to the virtual machine guest OS. You’re now connected to the VM.

# Access an SMB drive through Cloudflare Tunnel
The ability to set up a [secure, public SMB drive](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/use_cases/smb/) is a powerful file sharing tool. Usually, firewalls and ISPs block SMB file shares, but Cloudflare fixes that problem! With Cloudflare Tunnel, you can provide secure and simple SMB access to users outside of your network. The [cloudflared client](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/) to both the server and any machine you wish to access the SMB file share.

#### Connect SMB Server to Cloudflare
> Note: Guest access to [SMB2 and SMB3 are disabled by default on Windows](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/guest-access-in-smb2-is-disabled-by-default) machines, but since Cloudflare requires a sign-on to access the SMB share, this should not be an issue. 
- Create a Cloudflared Tunnel by following [this Cloudflare doc](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/remote/)
- In the Public Hostnames tab, choose a domain from the drop-down menu and specify any subdomain (for example, smb.example.com).
- For Service, select _TCP_ and enter the SMB listening port (for example, localhost:445). SMB drives listen on port `139` or `445` by default.
- Select Save hostname.

#### Connect to SMB Server
- Install [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/) on the client machine.
- (Recommended) Add a self-hosted application to Cloudflare Access in order to manage access to your server.
- Run the following command to open an SMB listening port. You can specify any available port on the client machine. `cloudflared access tcp --hostname smb.example.com --url localhost:8445`
- This command can be wrapped as a desktop shortcut so that end users do not need to use the command line.
- [Open your SMB client](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/use_cases/smb/#3-connect-as-a-user) and configure the client to point to `smb://localhost:8445/sambashare`. Do not input the hostname.
- Sign in with the username and password created while setting up the server.
- (Recommended) Add a [self-hosted application](https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-apps/) to Cloudflare Access in order to manage access to your server.

##### Windows-specific requirements
If you are using a Windows machine and cannot specify the port for SMB, you might need to disable the local server. The local server on a client machine uses the same default port `445` for CIFS/SMB. By listening on that port, the local server can block the `cloudflare access` connection.

> The Windows Server service supports share actions over a network like file, print, and named-pipe. Disabling this service can cause those actions to fail to start.
To disable the local server on a Windows machine:

- Select Win+R to open the Run window.
- Type `services.msc` and select Enter.
- Locate the local server process, likely called `Server`.
- Stop the service and set Startup type to _Disabled_.
- Repeat steps 3 and 4 for `TCP/IP NetBIOS Helper`.

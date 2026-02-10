# Create a VM for PfSense (Optional)
> For a more robus guide no pfSense, see [how-to_pfsense](how-to_pfsense.md)
1. Download/upload an .iso of PfSense to the local [pve] disk of the node (click on the node > local [pve]> ISO > search for download under templates or upload the .iso).
1. Click on the node (i.e. "pve" or whatever you named it when first installing ProxMox).
1. Click on Network > Create > Linux Bridge.
1. Enter "vmbr1" in the name field.
1. Create a new VM for PfSense.
1. Name it PfSense and check "Start at boot" and set the "Start/Shutdown order:" to "1".
1. OS select the pfsense .iso (be sure to download/upload it to the node prior).
1. Disk: 10GB is sufficient.
1. CPU: 1
1. Mem: 2GB
1. Netowrk: Select "vmbr0" and uncheck the "Firewall" box since PfSense will be the new firewall/
1. Click on Finish and click on the new "PfSense" node that was created/
1. PfSense Node > Hardware > Add > Network Device > Bridge "vmbr1" > Uncheck Firewall box (you should now have two netowrk devices listed in Hardware; one is for WAN and one is for LAN)/
1. Start the VM > Console > Start > Wait for install and cycle through the prompts and set everything as default (select "no" at the end for opening shell)/
1. Now map the WAN interface to "vtnet0" and LAN to "vtnet1" and confirm
1. Change the LAN IP to a different subnet (i.e. 192.168.2.1 or 10.0.0.1) by entering "2" (or whatever # for that indicates "Set interfaces IP address")/
1. Enter the new preferred subnet IP and enter "24" for the "bit count."
1. Hit ENTER when prompted to proivde an "upstream gateway address" and this will set it to none; also hit ENTER when prompted for ipv6.
1. Enter "y" when prompted to enable DHCP server on LAN (because we want PfSense to assign IP addresses for us automatically).
1. Enter the start range for the DHCP server to assign IP addresses (i.e. 192.168.2.101 or 10.0.0.101).
1. Also enter the end range for the DHCP server (i.e. 192.168.2.200 or 10.0.0.200).
1. Depending on if you want to utlize SSL encrypted connection, you can either select y/n when prompted to answer if you wish to use HTTP as the webConfigurator protocol (you probably want to enter "n").
1. PfSense should now echo what the LAN address is (ex. https://192.168.2.1/ or http://10.0.0.1/).
1. From you current subnet, you will not be able to reach your PfSense VM; therefore, you must temporarily disable the firewall to allow Web UI access for this address.
1. From the ProxMox interface, enter "8" (or whichever # which correlates with "Shell") and enter the following command:

`pfctl -d` (this will temporarily disable the firewall to allow access to the Web UI)

1. Login with the default creds ("admin" and "pfsense" which you will need to change)
1. You should now be a the the Web UI screen (after reattempting to enter the IP address you orginally set). Here go to: Interfaces > WAN > Reserved Networks > Uncheck "Block private netowrks and loopback addresses" and also "blok bogon networks" > Click Save (but do NOT click Apply Changes because the packets filterning will be applied immediately).
1. Firewall > Rules > WAN > Add (a new rule) > Set the "Action" to "Pass" > Destination "WAN Address" (from dropdown menu) > Destination Port Range > "HTTPS 443" (unless you said yes to HTTP ealier, then you want "HTTP 80").
1. Enter a description (ex. PfSense Web UI on WAN Interface) > Save > Apply Changes (this applies the packet filtering; and this new configuration will ensure Web UI access without any issues.)
1. Re-enable the firewall by entering Shell again and enter the following command:

`pfctl -e` (if this doesn't work try -h and find the command string to enable the firewall again)

> For reference `pfctl -sr`will show current firewall rules; `pftctl -sn` shows NAT rules; `pfctl -sa` shows all

> Firewall rules can be found in /etc/inc/filter.inc

> Additional PfSense documentation can be found here: https://docs.netgate.com/pfsense/en/latest/services/dyndns/client.html

# Create Cumulus VM template

Click the create VM button and set it as follows:

1. General: Name set as "cumulusTemplate".
1. OS: The image to be Ubuntu 20.04 Server.
1. Disk:
i. 230GB disk space.
ii. Check "Discard" box.
iii. Under the "Bandwidth" tab, enter 250MB/s Write limit and 300Mb/s burst limit.
1. Choose: 2 physical cores, 1 socket, 4 threads (ref. https://runonflux.io/nodes)

> Note: __Socket__ is the physical slot for a CPU. __Core__ - is the physical core a CPU has. __Threads__ - the logical or vCPU cores. Here it gets a bit confusing - within Proxmox *the number of vCPUs equals the number of threads*, so if your CPU supports hyper-threading, *the core count is double the physical cores* (i.e. 8 physical cores = 16 threads/vCPUs). Proxmox does not have a GUI option to create VMs with multiple threads per vCPU like other KVM hypervisors. However, several vCPUs can use the same physical CPU core because Proxmox will hypervise and spread multiple threads across all the physical CPU cores/threads. Both Intel and AMD hyperthreading provides 2x per core, but you don't get the performance of 2 CPUs for that. If you're looking for guaranteed performance, ignore vCores (the logical cores resulting from hyperthreading) and count just actual cores.

1. Memory/RAM: 8192
1. Finish & create the VM.
1. Right-click the new VM/node.
1. Click "Convert to template" and click "Yes" (you should see the icon change).
1. Click on the template > Options > Start on boot (check) > OK.
1. Right-click on the template > Clone (clone as much as needed).
1. Clone and start the VM & cycle through the menu prompts.
1. Take note of the IP address (192.168.1.16/24)
1. Uncheck "Set upthis disk as LVM group" > Done.
1. Input the name of the server (i.e. cumulus01 or same as what you named it in ProxMox setup).
1. Create a username and password for this server.
1. Check "Install OpenSSH server".
1. Wait for install and "reboot now".
1. If you try to reboot direclty without "removing the installation media" you will get an unmouting error that prevents the VM from rebooting. Therefore, you need to go to New VM > Hardware > Click on CD/DVD Drive > Remove. Now, restart the VM and enter the console again.
1. Log in as root (use the password you created).
1. Install the Cockpit GUI by entering the following command: 

`sudo apt install cockpit` > ENTER > `y`

1. Enter [yourVM_IP_address]:9090 of this VM in a web browser and open Terminal from the navigation menu.
1. Enable UPnP or manually forward the following ports for this same IP (minus the :9090): 16124 - 16128 (TCP/UDP) and 30000 - 39999 (TCP/UDP)
1. Enter the following command to change to root user:

`sudo su`

1. Run the following Multi-toolbox Installation Script from the RunOnFlux.io website:

`bash -i <(curl -s https://raw.githubusercontent.com/RunOnFlux/fluxnode-multitool/master/multitoolbox.sh)`

> Optional: If you decided to intall Cockpit earlier, you won't need to use SSH. But if you skipped that step, you can use SSH (i.e. PuTTY) to access the server to copy and paste commands. Log in using the username and password you created. Then type `sudo su` to change to root user.

1. After running the command, the Multi-toolbox prompts you for input; type "1" and then enter your username (the same user you set when creating the VM).
1. Enter "y" to change back to previous user.
1. Copy and paste the same Multi-toolbox command and hit ENTER.

`bash -i <(curl -s https://raw.githubusercontent.com/RunOnFlux/fluxnode-multitool/master/multitoolbox.sh)`

1. This time, enter "2" to install the FluxNode in a Docker container.
1. The Multitool will ask you for some FluxNode information which can all be found in the ZelCore app:

i. All the FluxNode info is found in ZelCore > Portfolio > Wallet (select the wallet you sent yourself Flux to before; ex. "Mining") > click in the Flux asset > Details > FluxNodes > (assuming you sent yourself Flux before and you have over 100 confirmations) under "My FluxNodes," click the arrow > Edit > Copy the "Identity Key" and paste it.
ii. Copy the ""Collateral TX ID" and paste it.
iii. Note the "Output Index" number (should be a single digit like 0 or 1) and enter it.
iv. Apps > ZelCore ID > click to copy the string of letters and numbers you see under the QR code and paste it
v. If prompted to add a KDA address, you need to make one by clicking on your Portfolio > Wallet (i.e. "Mining") > Add Asset > Search for "KDA" > Select "KDA" (not FLUX-KDA) > Exit back to the Wallet view > Click "Show Zero Sum" > Click on the Kadena asset > Receive > Copy the wallet address (starts with a "k:0") > Paste it

1. After entering everything, hit OK.
1. Download the bootstrap or "download from source" (you can start a 2nd FluxNode at this time if perferred). You must wat for the file to download and for the bootstrap to unpack fully before proceeding. Be patient and ensure your router settings are set correctly as you wait (but do not interrupt your interent connection as the VM is actively downloading a 18+GiB file).
1. After the WatchDog installs, you will be asked if you wished to be notified of any downtime of your FluxNode (either via Telegram or Discord which requires a webhook). You can find your webhook in your Discord account settings, but you can also skip this step.
1. Once FluxOS has been installed fully, a benchmark should commence (echos "restarting benchmark"); however, you need to cancel it and enable UPnP first for the benchmark to properly communicate with the servers. So, cancel the benchmark (i.e. CTRL + C), and go into your router settings to enable UPnP (or if using PfSense enable UPnP for the vmbr1 bridge).
1. After configuring your router, paste the Multitoolbox command once again, and type "14" to "Configure multiple nodes with UPnP).

`bash -i <(curl -s https://raw.githubusercontent.com/RunOnFlux/fluxnode-multitool/master/multitoolbox.sh)`

1. Hit OK to enable UPnP mode, and enter the highest port "16197" and ENTER.
1. Confirm that your router local IP is correct, and hit YES. This will automatically restart the FluxOS benchmark. Wait for it to complete.
1. Once the FluxNode is fully up and running, your public IP address to your new FluxNode will be listed. Copy this and paste it in: ZelCore > Portfolio > Wallet > Flux > Details > FluxNodes > Dropdown arrow > Edit > IP (paste it in this field).

1. In your ZelCore wallet, you now need start/enable your FluxNode: ZelCore > Portfolio > Wallet > Flux > Details > FluxNodes > Dropdown arrow > Start.
1. Lastly, if you wish to access your FluxNode via Cockpit while you are away from you local network, you must enable port `9090` through your firewall (you will also need to allow traffic by port forwarding on your router) . To add a `ufw` allow, enter:

`sudo ufw status` (you should not see port 9090 listed)

`sudo ufw allow 9090` (this will add port 9090 to the list and allow you to reach the FluxNode)

FIN

# Lock Linux Root Login
- create new user and disable root ssh and ftp login:

`adduser [username]`

`adduser [username] sudo`

`reboot`

`apt install vim`

`vim /etc/passwd`

- change the first line to to read "/sbin/nologin" instead of "bin/..." and save the file

- change permission to access root altoghther:

`vim /etc/ssh/sshd_config`

- change the line 34 entry that reads "PermitRootLogin yes" to ""PermitRootLogin no"

- save the changes (ESC > : > wq), then restart the ssh services:

`systemctl restart sshd`

### Update the default IP interface 

```
auto vmbr0
iface vmbr0 inet static
	address [your_public_ip]
	boradcast [local_ip]
	gateway [router_gateway]
	netmask 255.255.255.0
	bridge-ports [nic_name]
	bridge-stp off
	birdge-fd 0

```

- Install iptables

`apt-get install iptables-persistent`

`systemctl stop firewalld`

- Add the following to `/etc/network/interfaces` (at the bottom):

```
auto vmbr2
iface vmbr2 inet static
    address 10.21.21.254
    netmask 255.255.255.0
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up echo 1 > /proc/sys/net/ipv4/conf/vmbr2/proxy_arp
    post-up iptables -t nat -A POSTROUTING -s 10.21.21.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 10.21.21.0/24 -o vmbr0 -j MASQUERADE
    post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 2222 -j DNAT --to 10.21.21.1:22
    post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 2222 -j DNAT --to 10.22.21.1:22

```

- `cd /etc/iptables/`
- rename the `rules.v4` file `mv rules.v4 rules.v4.old` Use FTP to Download and Edit the rules.v4 file
- You can find the file here: /etc/iptables/rules.v4
- Once downloaded, open with text editor and overwrite contents with the following (date/time not needed):

```
# Generated by iptables-save v1.8.7 on Thu Jan 26 22:55:53 2023
*nat
:PREROUTING ACCEPT [18:1843]
:INPUT ACCEPT [3:132]
:OUTPUT ACCEPT [1:76]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o vmbr0 -j MASQUERADE
-A POSTROUTING -s 33.22.11.0/24 -o vmbr0 -j MASQUERADE
-D POSTROUTING -s 33.22.11.0/24 -o vmbr0 -j MASQUERADE
-A PREROUTING -i vmbr0 -p tcp --dport 1111 -j DNAT --to 33.22.11.101:11
-D PREROUTING -i vmbr0 -p tcp --dport 1111 -j DNAT --to 33.22.11.101:11
-A PREROUTING -i vmbr0 -p tcp --dport 3333 -j DNAT --to 33.22.11.103:33
-D PREROUTING -i vmbr0 -p tcp --dport 3333 -j DNAT --to 33.22.11.103:33
COMMIT
# Completed on Thu Jan 26 22:55:53 2023
# Generated by iptables-save v1.8.7 on Thu Jan 26 22:55:53 2023
*filter
:INPUT ACCEPT [4650:787604]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [3622:779408]
-A FORWARD -o vmbr0 -j ACCEPT
-A FORWARD -i vmbr0 -j ACCEPT
COMMIT
# Completed on Thu Jan 26 22:55:53 2023
# Generated by iptables-save v1.8.7 on Thu Jan 26 22:55:53 2023
*raw
:PREROUTING ACCEPT [17539:10503562]
:OUTPUT ACCEPT [13194:2583017]
COMMIT
# Completed on Thu Jan 26 22:55:53 2023
```


- Reboot the server

- When creating a VM, select vmbr1 under the network tab
- Once the VM is created, set the static ip as follows (for Ubuntu):

`vim /etc/netplan/01-netcfg.yaml`

____

- Restart the network `/etc/init.d/networking restart`

```
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
     dhcp4: no
     addresses: [33.22.11.101/24]
     gateway4: 192.168.1.1
     nameservers:
       addresses: [8.8.8.8,8.8.4.4]
```
___

DDNS Setup

- configure your router to forward all 80 and 443 connections to your server (set the IP to static also)

- go to: dynu.com/en-US

- create a ddns server address

`[sudo] crontab -e`

- edit the file to included a new lind at the end, such as:

*/15 * * * * wget -O dynulog -4 "https://api.dynu.com/nic/update?hostname=bmurr.freeddns.org&myip=10.0.0.0&myipv6=no&username=bmurr1228&password=5a557cb8a81129db6ab23740354e34de"

*/15 * * * * wget -O dynulog -4 "https://api.dynu.com/nic/update?hostname=hypermurr.freeddns.org&myip=10.0.0.0&myipv6=no&username=bmurr1228&password=5a557cb8a81129db6ab23740354e34de"

> security tip: make a hash out of your password to cipher your password from pying eyes by going to dynu.com/en-US/NetworkTools/Hash (or website > resorches > hash) and paste your password and click the "MD5 Hash" button to get your hash)

- `cd /etc/apache2/sites-available/`

- `vim 000-default.conf`

- edit the file to include all your reverse proxies (see below and consult Google your application "apache reverse proxy")

```

ServerName | [subdomain.name of your DDNS server.tls]

ProxyPass / http://localhost:[port # assigned]/
ProxyPassReverse / http://localhost:[port # assigned]/
ProxyPreserveHost on

<Proxy *>
	Options FollowSymLinks MultiVers
	AllowOveride All
	Order allow, deny
	allow from all
</Proxy>


	ErrorLog /var/log/apache2/error.log
	CustomLog /var/log/apache2/access log example
</VirtualHost>

```

-enable the reverse proxy `[sudo] a2enmod proxy proxy_http`

-reload apache2 `[sudo] service apache2 restart`

-no output means everything is configured correctly; if not, then read the report and troubleshoot

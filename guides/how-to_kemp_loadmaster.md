### Kemp LoadMaster
- An Enterprise Load-balancer Setup on ProxMox
> Note: [Cloudflare's Zero Trust automatically load-balances](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/routing-to-tunnel/) internet traffic. Kemp is not required, but is compatible with Cloudflare. 
- If you opt-out of using Cloudflare's Zero Trust loadbalancer, you can integrate Cloudflare's DNS records with Kemp to get the same load-balancing benefits. 
- First-off, why use a load-balancer?
  - **Industry-standard Epic-ness**: If you want to fit in with the cool kids (NASA, Harvard University, Apple, EA, Sony, US Army, JPMorgan, and more!) then you want the Kemp LoadMaster for your homelab.
  - **Custom Domain URL Access**: Access your Plex/Jellyfin server by entering a custom URL (ex. https://<your_custom_domain_name.com>). So, if you want to  access your homelab services (i.e. NAS files, Plex/Jellyfin media server, Prologue audiobooks, VMs, etc.) remotely (when you are not connected to your home network), you will want a load balancer.
  - **Security**: More ports = more network vulnerabilities! Hackers love ports. These digital pirates will growl, "Ahoy! I see me an open port" and then they sail right into your network with their malicious intent. So, if you self-host a website, watch Plex when away from home or at a friend's house, or you just want to access your NAS files outside your house, you must open up multiple ports which, in turn, exposes you to hackers. A load-balancer solves this problem. A load-balancer only requires *one* open port (443), greatly reducing your network vulnerability.
  - **Hide Your Public IP Address**: You *never* should share your public IP address! So, how can you hide it from attackers, and still want to share those amazing homelab apps you built and are so proud of without risking revealing your public IP? Two-words: "load balancer."
- Get a [*multi-compatible* domain name](https://www.a2hosting.com/domains?aid=presearchnode&bid=75dbf1c0) or use one you already have
- Get an enterprise-grade load-balancer called Kemp [get this 100% free version](https://freeloadbalancer.com/)
  - You will first need to create an account with Kemp and then verify your email to get to the download page.
  - You will notice that ProxMox is not listed among other Hypervisors, but that's not a problem. Kemp will still work! Here's how:
  - Select "VMware (OVF)" to download and agree to the terms (there's no difference in functionality, it is just packaged differently)
  - Next, unpack the downloaded zip file that contains the LoadMaster VM image. You can use a free tool like [WinRar](https://www.win-rar.com/start.html?&L=0) or [7-zip](https://www.7-zip.org/). You'll notice some *zip-insception* or *folder-inception* going on because there's another folder within the original folder, so just open both. After unzipping everything and getting to *Limbo-level-inception* you will find Mal--I mean--the files you really looking for.<br> ![alt_text](https://media.giphy.com/media/Ajf5GjjVwUYI8/giphy.gif)
  - Like Leonardo DiCaprio, you want to find something down in Limbo. Look for the `.ovf` and the `.vmdk` files. Got 'em? Good, you'll need to know the directory and files names so you can copy them into ProxMox using `ssh` and a SCP client.

  #### Copy Files with SCP
- Linux and macOS systems have a SCP client built in, but you will need to download [Git bash for Windows](https://git-scm.com/download/win). Or just run the following command in Windows Powershell and approve the install when prompted:
  
```sh
winget install --id Git.Git -e --source winget
```
  
<br>![alt_text](./images/gitbash-install.jpg)
  
- Next, using terminal or Windows Powershell, you want to `scp` the .ovf file to your ProxMox home folder. Type the following:
  
```sh
scp C:\Users\[user]\[directory]\Free-VLM-VMware-OVF-64bit\Free-VLM-VMware-OVF-64bit\[filename].ovf roo@[your_proxmox_ip]:/root/`
```
  
- Next, you need to run and `scp` copy command. We want to copy **2** files (the .ovf and the .vmdk files) from the PC with those files to the ProxMox home directory. First, let's get the `.ovf` file uploaded.
  
```sh
scp C:\Users\[user]\[directory]\Free-VLM-VMware-OVF-64bit\Free-VLM-VMware-OVF-64bit\[filename].ovf roo@[your_proxmox_ip]:/root/`
```

> Tip: Once you have spelled out (or copy & pasted it in the terminal window), you can start the first few letters of the file name and press `TAB` to auto-complete the file you want.

- This `scp` command will securely copy & transfer that file into the `/root/` dir of ProxMox. Now, lets send the other one:
  
```sh
scp C:\Users\[user]\[directory]\Free-VLM-VMware-OVF-64bit\Free-VLM-VMware-OVF-64bit\[filename].vmdk roo@[your_proxmox_ip]:/root/`
```
  
> If you fail to copy/transfer both files, you will get an error message saying the file could not be parsed. So make sure you upload both files.
  
> You can check if the file made it by `ssh` & `ls` into your ProxMox environment. <br> 
  
#### Deploying Kemp via `importovf` CLI

- Now we are ready to import Kemp into the ProxMox environment. You will need to use the `importovf` feature to delpoy Kemp.Use the following command:
  
  ```sh
  qm importovf [ID] LoadMaster-VLM-[VERSION].RELEASE-VMware-VBox-OVF-FREE.ovf [SERVER]
  ```
  
  > The `ID` number will be whatever the next ID for your VM is available (i.e. if you only made 1 VM then "101" is the next available ID, just check it in the `Server View` and `Datacenter` dropdown menu). The `SERVER` is name of the local storage listed in the `Data center`. It is probably just `local`.

> Note to self: Complete Cloudflare DDNS setup process.

#### Cloudflare Kemp Config
- After successfully setting up the Cloudflare DDNS reverse proxy, you should be able to access your Proxmox machine remotely using the custom domain you set up. If so, continue below:
-  Navigate to your [new domain settings pane](https://i.imgur.com/D8tQ69l.png) > SSL/TLS > Overview > "Full (__strict__)" (radio button)
-  Now, create a Certificate: Your domain settings pane > SSL/TLS > Origin Server > [Create Certificate](https://i.imgur.com/R1iIaQt.png) (button)
-  On the SSL/TLS > Origin Server screen > ["Use my private key and CSR"](https://i.imgur.com/3pz8lpI.png) (radio button) > Copy and paste your Kemp CSR into the text field > Create (button at the bottom)
-  Now, copy the "Origin Certiciate" that pops up and paste it to a text file (i.e. Notepad).
-  Save the text file type as follows: `[your_domain_name].pem`
-  Copy the RSA Private key from Kemp and paste it into another text file.
-  Save that text file type as follows: `[your_domain_name]priv.key`
-  Navigate to Kemp > Certificates & Security > SSL Certificates > Import Certificate (button on the top right)
-  Select and upload the `.pem` file you saved for the "Certificate File"
-  Select and upload the `.key` file you save for the "Key File"
-  Enter `Cloudflare_Origin_[domain]` in the "Certificate Identifer" field and save. You should get a message saying that the certificate was successfully saved.
-  [Download the Cloudflare Origin ECC PEM file](https://developers.cloudflare.com/ssl/static/origin_ca_ecc_root.pem), which should look look something like this: `origin_ca_ecc_root.pem`
-  Back on the Kemp loadmaster page >  Certificates & Security > SSL Certificates > "Add Intermediate" (button) > select and upload that `origin_ca_ecc_root.pem` file.
-  Enter `cloudflare_root_[domain]` in the Certificate Name field and hit the Add Certificate button. Now we have to add the newly created Cloudflare cert to the Kemp vitrual services.
-  Kemp > Virtual Services > Vew/Modify Services > Modify (button under the "Operation" column)
-  On the Properties screen, drop down the "SSL Properties" menu and check the "SSL Accelartion Enabled" box. This will propogate the Self Signed Certificate config.
-  Check the "Reencrypt" box. This will encrypt the traffic to and from your Proxmox server.
-  Click the arrows to add the `Cloudflare_Origin_[domain]` certificate and click the "Set Certificates" button.
- In __your router settings__ , you need to port-forward your [Kemp VIP](https://i.imgur.com/NjbzhgL.png). Enter the Kemp VIP and forward port `443`.

#### Kemp Content Rules
> The following content filter rules will enable the Kemp loadmaster to route traffic from 443 to the individual, specific ports of each web app/server/service you have running on Proxmox (i.e. port 32400 for a Plex server).
> You must mannually add the new A records for each subdomain and subequent IP address and port number that you wish Kemp to load balance (i.e. plex.[yourdomain].com IPV4 address + the required port of the server).
- To enalbe Kemp subdomain routing and filtering, navigate to Kemp > Rules & Checking > Content Rules > Create New Rule (button, top right).
- On the Create Rule screen:
 - Add a rule name (i.e. "Plex")
 - Enter `host` in the "Header Field"
 - Enter `^[subdomain_name].[your_domain.com]`
 - Check the "Ignore Case" box (to ignore case sensitivity).
 - Click "Create rule" (button)
- Now we need to add this new rule to the vitrual services. Navigate to:
 - Vitrual Services > View/Modify Services > Advance Properties (dropdown menu) > click on "Enable" (text) next to the "Content Switching" row. The fields should refresh and you should see: "Content Switching Enabled" now.
 - Now, scroll down to the bottom of this page to the "SubVSs" and open that dropdown menu. You should see the new rule(s) that you added here (if not, return to the Create Rule section).
  - Click on the "None" (grey button highlited in red) under the "Rules" column.
  - Change the Rule from "default" to the rule name you set (i.e. Plex), and click on the "Add" (button). Done.
 - Test the connection by entering `[subdomain_name].[your_domain.com]` in your browser.

> You could always get a free domain from Freenom, but the major drawback is that many free domains available (ending in `.tk`, `.ml`, `.cf`, `.gq`) **will not work** with some remote access applications like Apache Guacamole.
  
#### Modifying the Kemp Config
- When you first boot the "LoadMasterVLM" you will have problems. It will throw errors and reboot. The problem has to do with the SCSI Controller. By default, ProxMox runs it as LSI, so we need to change it to VMware PVSCSI. We can change that directly from the terminal:
  
```sh
nano etc/pve/qemu-server/[ID].conf
```

- Once you are in the .conf file, use the down arrow to toggle to the bottom line and add the following entry `scsihw: pvscsi` then press `CTRL + X` then `y` then `ENTER` to save this new configuration.
  
<br>![alt_text](./images/vmware-pvscsi-1.jpg)
  
- If that worked, you will see the change on the hardware screen.
  
<br>![alt_text](./images/vmware-pvscsi-2.jpg)
  
- Also, you wan to give Kemp LoadMaster an internet connection, so go ahead and add it while you are on this screen. Just click `Add` and add your `Network Device`.
- I also recommend adding additional CPU cores and RAM (at least 4GB) to help with running Kemp without a problem as some users mentioned issues when the RAM was below 2 cores and 4GB of RAM (by default, it will give Kemp only 2GB).
  
<br>![alt_text](./images/loadmaster-working.jpg)

 > I want to five credit to Lusk.blog for the helpful insights on setting up Kemp with ProxMox. You can [check out his blog here](https://lusk.blog/how-to/running-free-load-balancer-on-proxmox-or-preventing-a-kemp-loadmaster-boot-loop/). And I thought to leave his helpful last remarks here:
>> "While the free version of Kemp’s LoadMaster does limit the bandwidth to 20mbps, it’s quite sufficient for a lab environment. If you need something without the limitations and can’t afford (or don’t need) the LoadMaster Commercial version, or if you would just prefer to go with an open-source solution, [HAProxy](https://www.haproxy.org/) would be the tool of choice."

# Overivew 
This guide will show you how create the __ultimate__ Proxmox hypervisor with:
- ZFS read/write cache
- Ubuntu 20.04 LTS cloud inint, cloud image template
- Cloudflare remote server access
- Ansible playbooks
- high-availability K3S cluster
- and more...

# Table of Contents
- [ProxMox Hypervisor Installation](#proxmox-install)
- [Creating a ZFS Pool](#zfs-configuration)
- [Create Cloud Init Cloud Image Template](#cloud-init-template)
- [Access Your Lab Anywhere](#remote-access)
- [Setup GPU / PCI Card Passthrough](#pcie-gpu-passthrough)
- [Create Windows VM](#windows-proxmox-install)
- [Pihole Proxmox Setup](#pihole-proxmox-install)
- [How to Transfer Files to Linux Server](#filezilla)
- [TrueNAS Scale](#truenas-scale)
- [Portainer Setup](#portainer)
- [Plex Media Server](#plex)
- [Ansible Automation Setup](#ansible)
- [Create a Kubernetes Cluster](#kubernetes)
- [Use Rancher to Manage K3S Cluster](#rancher)

# ProxMox Install 
- Download the latest "ProxMox ISO [version#] ISO installer" from the [official website](https://www.proxmox.com/en/downloads/category/iso-images-pve)
- Flash the ISO image to a USB drive (at least 8GB in size) using BalenaEtcher or Rufus (free Windows programs)
- Plug the flashed USB drive into the PC you wish to use as your hypervisor
> Note: Ensure that the device has a conenction to your local network so it can auto-poulate the IP settings.
- Press `F12` or `DEL` or the other BIOS key to enter your boot disk selection or BIOS.
- Force the PC to boot from the flash drive you created by selecting the flashdrive from the BIOS menu (google your PC BIOS for how to find the boot drive settings)
 - The installer page should popup. Proceed with "Install Proxmox VE"
 - Agree to the EULA
 - Select the target disk and continue (if you wish to create a ZFS pool with a second cached drive, see [below](creating-zfs-pool-and-cache) to modify the target drive.
> Note: This action will erase the drive. If you have files you don't want to lose, first back them up before proceeding.
 - Select your country and timezone.
 - Enter a password that you wish to use to access the Proxmox web UI (remember this).
 - Select your managment interface (if you have more than one NIC).
 - Enter your preferred hostname (FQDN is not required, "pve.lan" or "pve0.lan" will work).
 - Enter the static IP address you wish to use to connect to the Proxmox UI (ex. 192.168.1.100).
 - The DNS server and gateway should already be auto-populated. Typically, the default gateway for most routers is 192.168.1.1.
 - The final screen is the install screen (again, take note of the IP address, you will need this to access Proxmox.) Hit the install button and wait.
 - Remove the installer media after your computer finishes the install and successfully rebootsv (there's a confirmation screen at the end).
 - If everything was successfull, you should see a mostly black login screen (if you don't see this screen, skip to [Installation Issues](Installation-issues) below).
 - After ProxMox has finished installing, it will automatically reboot (reboot manually if it did not).
 - Now, enter the `https://[IP_address_you_set]:8006` in a web browser on another machine connected to the same router and network.
 - Enter the IP address you set to access the Proxmox UI (ex. https://192.168.1.100:8006).

 > Don't forget to include "https://" and add ":8006" at the end of the IP address.

 - You will get a warning screen from your web browser telling you the URL address you went to is unsafe, but that's just because you don't have SSL for your ProxMox. It's a false alarm. Just click on whatever options you have to continue to the site.
 - Enter `root` for the username and enter the password you created at setup to access. Done!
- Next, you will be prompted to login to ProxMox. Input `root` for the username and enter the password you created at setup to gain access.

> Before deploying and VMs, you can consolidate and expand your storage. Do this *before* creating VMs. See [ZFS below](#zfs-configuration).

### Change Web UI IP Address
- If another device on the network is using the IP address that you assgined to your new Proxmox server at install, there will be a conflict and you won't be able to access the web UI.
- I suggest running an [Advance IP Scan](https://www.advanced-ip-scanner.com/) on your network to see what IP ranges are available. Alternatively, you can check your router for current IPs that are taken/available, and once you find an open IP, assign a static IP it to your Proxmox server.
- But here's how to change the Proxmox web UI IP address:
  - Login to the terminal of the Proxmox server using your creds.
  - Next, change the IP address in the network config files to match the IP you want:
 
 ```
 # change the address line, 6th line down
 nano /etc/network/interfaces
 ```
 
 ![interface1](https://i.imgur.com/r6hOhE6.png)
 
 - This is sufficient to regain access to the web UI, however, there is another important step: editing the host file with the hard-coded IP to the new IP.
 
 ```
 # change the second line to the desired IP address
 nano /etc/hosts
 ```
 
  ![interface2](https://i.imgur.com/Y1OWYWD.png)

### Installation Issues
- If an install goes ary, you can always use the PrxoMox debug mode built into the bootable .iso installer.
- Try rebooting with the .iso installer plugged in, but this time select "Advance Options" (underneath "Install Proxmox VE") and choose the "Install Proxmox VE (Debug mode)" option.
- This will boot up in a Linux Debian CLI mode that allows you access to powerful CLI commands (i.e. wipe the drives and try reinstalling ProxMox). Type `exit` after it loads and the prompt is ready.
- You want to find the drive names. Drive names usually end in "1n1" or "0n1" depending on how many drives you have mounted.
- The drives are listed in the `/dev` folder path. Type `cd /dev` then type `ls` to list the contents of the folder to get the names of the disks (ex. `/dev/nvme0n1`). Take note of this as you will need it for the next drive wipe command.
- To wipe a corrupted install, type `wipefs -a /dev/[drive_name] [path_to_second_drive_if_applicable]`. After that, `exit` and `reboot` the endpoint and try the install again.
- Type `exit` again, wait a second, then type `reboot`. (Make sure the bootable drive is still attached.)
- The EULA should popup, and you can now attempt to reinstall Proxmox.
- You can also access BusyBox in dev/debug mode to fix a ZFS error, see below for the error message:

### Boot fails and goes into busybox
If booting fails with something like:

```
No pool imported. Manually import the root pool
at the command prompt and then exit.
Hint: try: zpool import -R /rpool -N rpool
```
- This is because zfs is invoked too soon (it has happen sometime when connecting a SSD for future ZIL configuration).
- To prevent it, boot into debug mode, run Busybox (type `busybox` and hit `ENTER`), then try __ONE__ of the following:
 - a) edit /etc/default/grub and add "rootdelay=10" at GRUB_CMDLINE_LINUX_DEFAULT (i.e. GRUB_CMDLINE_LINUX_DEFAULT="rootdelay=10 quiet") and then issue a # update-grub
 - b) edit /etc/default/zfs, set ZFS_INITRD_PRE_MOUNTROOT_SLEEP='4', and then issue a "update-initramfs -k 4.2.6-1-pve -u"

# ZFS Configuration
See the [ZFS Proxmox Wiki](https://pve.proxmox.com/wiki/ZFS_on_Linux) for more details and commands. 

### Creating a ZFS Pool and Cache
> Note:  RAID0 forces stripped drives to the _smallest_ drive size (i.e. 2TB + 118GB = 118GB storage pool size).
> Note: RAID-Z or mirrored (RAID1) ZFS configurations will _not_ work with cache drive setups. 
- When selecting a disk, choose the primary (largest) disk and then click the options button.
- Change the file system type to the ZFS RAID0 configuration and max out the disk space allotted (should be maxed by default).
- Exclude the cache disk from the ZFS pool at this time (we will add it later).
- Choose the l4x compression, and finish out the disk wizard prompts.
- Finish the Proxmox installation, login, and open a shell to enter the following command `zpool add rpool cache [name_of_cache_drive]` and hit enter to add the cache drive to the ZFS pool created at install.

> You can get the disk name by typing `fdisk -l` in the Proxmox `Shell`.

- You can check the status of the pool by typing `zpool status [name_of_pool]` (the default pool name is `rpool`). Or, you can check it in the UI. Navigate to Node (pve) > Disks > ZFS. You should see the cache drive in the pool.

### Adding a Cache Drive
- Using SSH or the console, type the following: `zpool create rpool /dev/[primary_drive_name] cache /dev/[cache_drive_name]
- Type `zpool status [pool_name]` for an overivew of your new ZFS pool with cache.

### Create ZFS Datasets
- You can view your current ZFS pool via `zpool list` and `zfs list`. Take note of the `mountpoint` name (if you created a ZFS pool at installation, this will be called `rpool` by default).
- To create datasets for storing `ISOs` and VM storage and more, type the following:

```
zfs create rpool/backups

zfs create rpool/iso

zfs create rpool/vm
```

> If `rpool` is _not_ the default, then you would type out: `zfs create [mountpoint]/backups` for example.

- These dataset will share the total pool size. It dynamically allocates disk space as needed.
- Now we need to mount/add these datasets at the `Datacenter` level:
 - Navigate to > [Datacenter (node, left-most pane) > Storage (subset) > Add > Directory](https://i.imgur.com/5QuSsWl.png) > Enter the name of the dataset (i.e. `backups`, `iso`, `vm`), and add them one at a time.
  - ID: `iso` | Directory: `/rpool/iso` | Content: `ISO image` and `Container templates`
  - ID: `vm` | Directory: `/rpool/vm` | Content: `Disk image` and `Container`
  - ID: `backups` | Directory: `/rpool/backups` | Disk Image: `VZDump backup file` and `Snippets`
 - See an [example configuration here](https://i.imgur.com/T9JzxXK.png).
 - Once the new ZFS Datasets have been successfully mapped to your Datacenter, you should [see them listed in the left navigation pane](https://i.imgur.com/1eOFcHR.png).

#### Change VM ZFS Disk Size
- If the disk type is `QEMU` or `qcow2`, you can change the disk size on the fly.
- To add disk space, navigate to the VM > Hardware > Hard Disk > Disk Action (dropdown button) > Resize. Then add more GB by increments of 1.
- To decrease the disk size, it is trickier because you have to use the Proxmox terminal and commands.
  - First, check your ZFZ pool supports trimming.

```
zfs status [pool_name] -t
```
  - You should see some indication i.e. "untrimmed" or "trim unsupported". If you see "unsupported" then you likely have a RAID controller instead of an HBA and you cannot resize the pool.
  - Next, find the VM disk name from the storage pool: Datacenter > Node > Where you store VMs drives > VM Disks > Locate the VM disk name.
  - Next, open the console for the Proxmox server and enter the following command to resize:

```
zfs set volsize=[number_in_GBs]G [pool_name]/[dataset_name]/[VM_disk_name]
# example environment command
zfs set volsize=5G rpool/vm/base-8000-disk-0
# get command
zfs get volsize | refreservation | used <pool>/vm-<vmid>-disk-X
```
> Error: These commands do not seem to work currenlty. Bug? The command produces a __"cannot open...dataset does not exist__ error message.

#### Move the Root Disk of VMs
- Navigate to > Datacenter > PVE Node > [VM] > Resources > Click on Root Disk > Click on Volume Action (button) > Move Storage > Target Storage (dropdown) > Select the `VM` dataset > Check the Delete source (box) > Move Volume (button).

#### Creating a Backup and Restore
- Now that you have created a place to store your backups, you can schedule and restore your VM or containers

> Restoring from a backup is also another way to change the number of the VM/Container.

- To create a backup repository, navigate to: Datacenter (left-most pane) > Backup (menu option) > Add (button) > Schedule: Everyday [3AM] > Selection mode: All > Storage: Backups > Create (button).
- See [an example backup configuration here](https://i.imgur.com/qAxMYoc.png). 
- To restore a backup, navigate to: Datacenter > [proxmox_node_name] > Click on Backups (ZFS dataset) > Backups (menu option on right) > Click on the backup file (ending in `.tar.zst`) > Click Restore (button, top) > Storage: VM (_not_ local) > CT: Enter the desired number (100-999) > Check the "Start after restore" box (if desired) > Do not change the default priviledge settings > Click Restore (button)
- Now, wait for the backup to be restored and you should eventually see it populate under the Datacenter > Proxmox Node > [VM/Container_Name]

# Cloud Init Template

> Cloud images and cloud init work together to make lightweight, optimized, distributions for super-fast deployment possible. Cloud services such AWS, Azure, GCP, etc use cloud init to provision Linux machines and more. To tap into that power, we can create the perfect Proxmox template for launching these cloud images for all subsequent VMs we may want to spin up. There's [reference documentation](https://pve.proxmox.com/pve-docs/qm.1.html), but here's how:

- Find a focal (current) cloud distro you want. I went with [Ubuntu 20.04](https://cloud-images.ubuntu.com/daily/server/focal/current/).
- Inside this focal cloud folder, you scroll until you find the [focal-server-cloudimg.amd64.img](https://i.imgur.com/XKVAyIP.png) file and then __copy the URL__ and __paste__ it in a note for later (this image will be used as the hardrive of our vitrual machines).
- Open up the shell or SSH into your Proxmox server, and type `wget` followed by a space and then the that URL link to the cloud `.img` file. Here is a sample of that command:

### Ubuntu __18.04__ LTS
```
wget https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
```

- Wait for the image to download to your Proxmox server. Next, we need to run the following command to create a virtual machine and attach that image to this VM:

```
qm create 8000 --memory 2048 --name 18.04-bionic-server --net0 virtio,bridge=vmbr0
```
> You can always change the name in the GUI, but you can't change the template ID: `8000` is the ID of the template. This can be whatever you wish, but I set mine to a high number to distinguish it as a template.

- If you ran the command successfully, you should now see that VM listed under your Proxmox node, but we aren't finished yet. Next, we to set the disk storage:

```
qm importdisk 8000 bionic-server-cloudimg-amd64.img vm --format qcow2
```

> Note: You can also upload this ISO to a different storage dataset (i.e. local-lvm). Also, any misspellings or deviations from the precise `img` file name will produce errors. Make sure you type in the right `<source>` name.

- I had issues trying to run the `qm set <vmid> --scsi0 <your_vm_storage_ID>:<desired_disk_size_in_GB>` (for example: `qm set 8000 --scsi0 vm:10`) wherein it leaves an "Unused Disk 0", so I suggest using the GUI to assign the Cloud drive to the VM.
![gui_scsi](https://i.imgur.com/o4eyart.png)

- To do this, navitagte to: Datacenter > Node > VM ("8000") > Hardware > click on Unused Disk > Edit (button) and select "SCSI" and "0" from the dropdown menus. Do not change any other settings here, and click the _Add_ button. You should now see the unused disk disappear and the [Hard Disk appear in the VM](https://i.imgur.com/p1D3l8l.png).

- Now, we need to create a virtual CD-ROM and attach it to the VM template we created:
```
qm set 8000 -ide2 vm:cloudinit
```
- The following command enables our VM to boot from the cloud drive. As an added bonus, it will speed up boot times.
```
qm set 8000 --boot c --bootdisk scsi0
```
- Next, let's create a serial console for the added ability of the web VNC capability to see the terminal.
```
qm set 8000 --serial0 socket --vga serial0
```

### Ubuntu __20.04__ LTS
```
wget https://cloud-images.ubuntu.com/daily/server/focal/current/focal-server-cloudimg-amd64.img
qm create 8001 --memory 2048 --name 20.04-focal-server --net0 virtio,bridge=vmbr0
qm importdisk 8001 focal-server-cloudimg-amd64.img vm --format qcow2
# Nav to: Template VM > Hardware > Unused Disk > Set to scsi0
# [WIP] qm set 8001 --scsi0 vm:10G
qm set 8001 -ide2 vm:cloudinit
qm set 8001 --boot c --bootdisk scsi0
qm set 8001 --serial0 socket --vga serial0
# Change SCSI Controller to "VirtIO SCSI"
# Modify Cloud-Init login and set ipconfig IPv4 to DHCP from Proxmox UI settings now
qm template 8001
```

### Ubuntu __22.04__ LTS
```
wget https://cloud-images.ubuntu.com/daily/server/jammy/current/jammy-server-cloudimg-amd64.img
qm create 8002 --memory 2048 --name 22.04-jammy-server --net0 virtio,bridge=vmbr0
qm importdisk 8002 jammy-server-cloudimg-amd64.img vm --format qcow2
# Nav to: Template VM > Hardware > Unused Disk > Set to scsi0
# [WIP] qm set 8001 --scsi0 vm:10G
qm set 8002 -ide2 vm:cloudinit
qm set 8002 --boot c --bootdisk scsi0
qm set 8002 --serial0 socket --vga serial0
# Change SCSI Controller to "VirtIO SCSI"
# Modify Cloud-Init login and set ipconfig IPv4 to DHCP from Proxmox UI settings now
qm template 8002
```

![cloud_init_settings](https://i.imgur.com/lukuLXY.png)

### Cloud Init Login Settings
- Return to the Proxmox GUI > Datacenter > Node > ubuntu-cloud VM > Cloud-init (menu), and you should now see a the cloud icon for this VM.
- Edit the Cloud-init settings as follows:
  - _User_: `<your_username>`
  - _Password_: `<your_password>` (you can modify this later in VM > Cloud-init > Password and then reboot the VM)
  - _Host_: Leave as default or customize to your preference
  - _SSH Public Key_: `ssh-rsa[insert_your_public_SSH_key]`. You can readily find documentation on [how to generate a SSH Public key using PuTTYgen](https://docs.digitalocean.com/products/droplets/how-to/add-ssh-keys/create-with-putty/).

> Proxmox SSH Key ZFS Bug: When attempting to add a public key, I got the following error: _SSH public key validation error (500)_ . As it turns out, [this is a known bug](https://bugzilla.proxmox.com/show_bug.cgi?id=1188), but it does appear to be fixed. _Make sure to select_ Key > __SSH-2 RSA__ > RSA (radio button) when generating your SSH keys _or else it will not work._ Your public key should start with `ssh-rsa`. See example PuTTYGen screenshot below, and don't forget to password protect and save your private key.
![ssh_2_RSA](https://i.imgur.com/xbsItrt.png)
  - _IP Config: IPv4_ `DHCP` (radio selector). Note: The default IP value is nothing, so will not get any network access at all by default. Therefore, __you must set it to DHCP__ at or edit the values manually.

![ip_dhcp](https://i.imgur.com/lS3IC7d.png)

- Change the SCSI Controller from the default setting to VirtIO SCSI from the Proxmox GUI.
![VirtIO_SCSI](https://i.imgur.com/Exs2OAE.png)
> CAUTION: Do __not__ start the VM. If started, it will be boostrap the machine ID and UUID.

- In the end, you should have a hardware configuration that looks similar to this:
 
![cloud-hardware](https://i.imgur.com/JAX8z1Q.png).
- Of course, you can play with the default CPU, RAM, and disk space settings, but if anything else looks off, modify the VM to match or delete the VM and start from scratch (it's not that hard).
- When you are 100% satisfied with the results, right-click the ubuntu-cloud VM and click "Convert to template" or:

```
qm template [vm_id]
```

- You should see the icon change to a paper icon with a monitor, indicating that it has become a template.

### Troubleshooting WGET Fail

If you get any of the following errors: "failed: No route to host" or "connect: Network is unreachable", then _you have a network problem_.  First thing to try is a simple ping test to google: `ping google.com`. If the return is "destinaion host unreachable" then your Proxmox hypervisor is unable to reach the internet for some reason. Here's a few things you can do/check:
- Check that your nameserver is set to the IP gateway of your router (this varies depending on your router, but you can check the label on the routher to see if it lists a default gateway IP address.) Open a shell and type:

```
nano /etc/resolv.conf
```

- If the `nameserver` is _not_ the same as your gateway IP of your router, then change it to match.
- You can also check if your network is configured correctly from the GUI.

![gateway_check](https://i.imgur.com/ccacEYn.png)

- After making the appropriate changes, run the following:

```
service networking restart
```

#### Cloning Cloud Template
- Proxmox has [documentation on the process here](https://pve.proxmox.com/wiki/Cloud-Init_Support).
- Either clone via the GUI:
![clone_GUI_mode](https://i.imgur.com/RBwBLCy.png)
- Or via CLI:
```
qm clone [server_template_id] [new_vm_id] --name [vm_name]
```
> Note: Disk must be formatted to __QEMU__/__qcow2__ to be able to resize. VMDK format will not work.
- By default, the VM will not have much hard drive space unless you changed the settings prior to saving this template.
- Therefore, you must add more storage to the VM. It's not difficult. Navigate to > VM > Hardware > Hard Disk > Disk Action (top, button dropdown) > Resize > Add the desired amount.
> Note: Decreasing the disk space is more difficult than increasing, so don't give it more than necessary, and you can always increase it later if needed.


#### SSH to VM
> Tip: You can always generate or add key pairs to a server via SCP, see [Step 2 of this article](https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server#step-2-copying-an-ssh-public-key-to-your-server)

- If you already know the IP addresses on your network open a Command Prompt (Windows) and type `arp -a` to get a list of IPs on your network.
- If you need more intel, run [Advance IP Scanner](https://www.advanced-ip-scanner.com/) to locate your new VM by its name to identify the IP address you can use for SSH.
- Once you have your IP address (i.e. 192.168.1.x), download and install (if you haven't already done so) [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).
- Open PuTTY, type in the IP address (Host Name), then navigate to Connection > SSH > Auth > Browse (button) and open the `.ppk` private key that you generated and saved when you made your public key (this is necessary to access your server).
- Enter the user name you created (i.e. `admin`)
- Enter the password you set for the private key (if applicable), and your in!

![puTTY_ssh_IP](https://i.imgur.com/yeq7QN8.png)

[puTTY_ssh_key](https://i.imgur.com/6cygvoL.png)

> Tip: You can save the profile of this server for future use. You can also assign a static IP so the IP address in your router and do the necessary port forwarding you need for any web apps so it doesn't change via DHCP. 

(Optional)
```
qm set [new_vm_id] --sshkey ~/.ssh/id_rsa.pub
```

# FileZilla

See [FileZilla's How-to](https://wiki.filezilla-project.org/Howto) for more details.
- Download FileZilla and run it.
- Navigate to File (top left tab) > Site Manager.
- Enter the IP address and port (i.e. 22).
- Enter the username you made for the VM.
- Browse and add the `.ppk` private key you generated.
- Connect to the server and transfer the files drag-n-drop style.

![sftp_filezilla](https://i.imgur.com/raDY9mj.png)

### Troubleshooting "open for write: permission denied" error

If you get "file transfer failed", then you may not have perms properly configured. If this happens, you need to perform two actions:

- 1) grant sudo perms to the user with folder access. As `root` run the following:
```
usermod -aG sudo <username>
```
- 2) Add perms to allow file transfers
```
sudo chmod 777 </to/the/folder/path>
```
- 3) Now, retry to transfer files to that specified folder path
 
- 4) Lastly, you could get an ownership execution issue (if transferring files by another user). If that's the case, you'll want to change ownership of files with `sudo` user running the following command:

```
chown -R <username>:<repeat_same_username> /path/to/folder/
```
# Remote Access
If you want to securely access and work on your Proxmox hypervisor on-the-go, there's Cloudflare and Tailscale to make this possible. 

#### Cloudflare
Cloudflare acts as a DDNS Reverse Proxy to allow you a domain-joined URL to securely access your Proxmox server from anywhere.

- Instead of enduring the ardous process of installing an enterprise-grade load-balancer like Kemp, you can get a DDNS and reverse proxy setup via CloudFlare in 15 minutes.
  - If you want to know how to set up an entrpirse loadbalancer for Proxmox, [see my how-to setup Kemp guide](how-to_kemp_loadmaster.md)
- See my [Cloudflare documentation](how-to_cloudflare.md) for more details on how to setup a Cloudflare tunnel and securing your homelab.
- [NetworkChuck made a video tutorial](https://www.youtube.com/watch?v=ey4u7OUAF3c) about this, but here's the steps:

> Note: You must buy a domain and create a Cloudflare Nameserver (DNS > Records > Nameservers).

- Copy the nameservers and add them to your domain registrar (nameserver updates can take up to 24hrs, but it is usually updated within minutes).
- Using [ZeroTrust](https://one.dash.cloudflare.com/899e8be9fba8f3cc125ebdf9263380e0/home/quick-start) create a new tunnel: [ZeroTrust](https://i.imgur.com/FipaEgQ.png) (left navigation pane) > Cloudflare ZeroTrust (navigation pane) > Access (dropdown) > [Tunnels](https://i.imgur.com/nnONYTE.png) > Create at tunnel (button)
 - To contine the process, see my [Cloudflare documentation](how-to_cloudflare.md)

#### Apache Guacamole
[placeholder]

#### TailScale
[placeholder]

# PCIE GPU Passthrough

[Mannually Mount SATA Drives w/o HBA/SATA Controller](https://www.youtube.com/watch?v=2mvCaqra6qY)

[How to Passthrough a Disk to VM- YouTube](https://www.youtube.com/watch?v=U-UTMuhmC1U)
[How to Passthrough a Disk to VM- Proxmox Docs](https://pve.proxmox.com/wiki/Passthrough_Physical_Disk_to_Virtual_Machine_(VM))

```
ls -n /dev/disk/by-id/
/sbin/qm set [VM-ID] -virtio2 /dev/disk/by-id/[DISK-ID]
```

> Right-click Hard Disk > Disable Backup (check box)

#### Passthrough PCI to Proxmox
[How to Passthrough a PCI to ProxMox - Reddit Source](https://www.reddit.com/r/homelab/comments/b5xpua/the_ultimate_beginners_guide_to_gpu_passthrough/)

[How to Passthrough a PCI to ProxMox - Proxmox Docs](https://pve.proxmox.com/pve-docs/chapter-qm.html#qm_pci_passthrough)

```
nano /etc/default/grub
```

- Edit the line that contains GRUB_CMDLINE_LINUX_DEFAULT="quiet" to:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"

# Disable OS-Prober
GRUB_DISABLE_OS_PROBER=true
```

- I have also seen this GRUB config work:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction video=efifb:eek:ff"

# Disable OS-Prober
GRUB_DISABLE_OS_PROBER=true
```

> These extra commands allow for the passthrough to work

> Note: Edit the paramerters to your specs (i.e. change "intel" to "amd" if you are using different CPU). Ex. `GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"`

- For Intel CPUs, add `intel_iommu=on` to the kernel command line also (for AMD CPUs it should be enabled automatically):

```
echo "intel_iommu=on" >> /etc/kernel/cmdline
```

- Now, update `grub` with the changes we just made to the `grub` file.

```
update-grub
```

- Now, edit the `modules` files as follows:

```
nano /etc/modules
# add the following  lines at the bottom of the file

vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

- __Save__ and exit.
- You need to refresh your `initramfs` after editign the modules using:

```
update-initramfs -u -k all
```

- After letting that command to run, __reboot the Proxmox server__ and then __test if IMMOU is enabled:__

```
# for Intel
dmesg | grep -e DMAR -e IOMMU -e Intel-Vi

# for AMD
dmesg | grep -e DMAR -e IOMMU -e AMD-Vi
```

- You should __see a reply__ something to the effect of `DMAR: IOMMU enabled`.
- Now, we must __remap/override the IOMMU mappings__ by creating these files using the following cmdlets:

```
# first command
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf

# second command
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf
```

- As we do not want the Proxmox host system using GPU resources, we need to blacklist the drivers by running these commands:

```
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
```

> Progress Note: At this point, the host system is configured to passthrough a PCI card to any VM, but the VFIO does not know what PCI lane _specifically_ to passthrough. 

- Now, let's add the PCIE cards we want the VFIO to passthrough to the VMs:

```
lspci -nn | grep NVIDIA
```

> Note: The shell will output a jargon of text. Look for specific lines that list the card you want to add to the VFIO. See screenshot for example:

![GPU](https://i.imgur.com/b3PgnLC.png)

> ```
> 01:00.0 VGA compatible controller: NVIDIA Corporation GP104 [GeForce GTX 1070] (rev a1) (prog-if 00 [VGA controller])
> 
> 01:00.1 Audio device: NVIDIA Corporation GP104 High Definition Audio Controller (rev a1)
> 
> Make note of the first set of numbers (e.g. 01:00.0 and 01:00.1). We'll need them > for the next step.
> ```

- Run the command below. Replace __01:00__ with whatever number was next to your GPU when you ran the previous command:

```
# my SATA controller
lspci -n -s 01:00.0

# my GPU VGA
lspci -n -s 83:00.0

# my GPU Audio
lspci -n -s 83:00.1

```

- Doing this should output your card's vendor IDs, usually one ID for the GPU and one ID for the Audio bus. See below for example:

```
# my SATA controller
01:00.0 0106: 1b21:1064 (rev 02)

# my GPU VGA
83:00.0 0300: 10de:2484 (rev a1)

# my GPU audio "GA104 High Definition Audio Controller)
83:00.1 0403: 10de:228b (rev a1)
```

- Take special note of these vendor ID codes: `10de:228b` and `10de:2484`.

Now we add the GPU vendor ID's to the VFIO, and __remember to replace the id's with your own!__:

```
echo "options vfio-pci ids=10de:228b,10de:2484 disable_vga=1"> /etc/modprobe.d/vfio.conf
```

> This new config file we just created is telling VFIO what PCIE cards to passthrough to the VMs. So, if you ever add new PCI cards, then you want to add the vendor IDs to this `/etc/modprobe.d/vfio.conf` file. However, it is important that the device(s) you want to pass through are in a __separate__ IOMMU group. This can be checked with: `find /sys/kernel/iommu_groups/ -type l`

- Next, run this command to update the VFIO file:

```
update-initramfs -u -k all
```

- __Wait__ for the terminal to run through the __update until finish__, then, __reboot the Proxmox server again__.
- After the reboot, __check if your changes were successful__:

```
lspci -nnk
```

- If the line __reads, `Kernel driver in use: vfio-pci`__ __then the device is ready__ to be used for passthrough. Note: if you add more GPUs to the hypervisor, you must repeat this process for EACH GPU by adding the unique vendor ID codes to the `/etc/modprobe.d/vfio.conf` file as comma separated values.

- Now, on the VM side and settings, we want to __enable OMVF (UEFI)__. See screenshot below:

![UEFI_edit](https://i.imgur.com/3QFhPe5.png)

- Next, __edit the VM's config file from the Proxmox host node__  as follows:

```
nano /etc/pve/qemu-server/<vmid>.conf

# modify each line as you see or add these lines if you do not see the lines
cpu: host,hidden=1,flags=+pcid
machine: q35
args: -cpu 'host,+kvm_pv_unhalt,+kvm_pv_eoi,hv_vendor_id=NV43FIX,kvm=off'
```

> Where `<vmid>` is the VM ID Number you used during the VM creation (General Tab).
 
 > __BEWARE__: Before you move on to the next step, get the IP address of the VM __before__ you enable the GPU passthrough because the console on the VM will be inaccessible via Proxmox and you must use RDP or SSH to access the terminal on the VM.

- Back in the Hardware settings of the VM, we want to __add a new PCI device__ as follows: __Add (button) > PCI Device > Device (dropdown) > Select the PCI device you want to add (i.e. SATA controller, GPU, etc.)__
- __Check all the boxes__: `All functions`, `ROM Bar`, `Primary GPU`, `PCI-Express`.

![enable__bios_IMMOU](https://i.imgur.com/D9Jp4Xj.png)

> __No IMMOU Error__: You may get the following error if your CPU does not support IMMOU / Passthrough: _"TASK ERROR: cannot prepare PCI pass-through, IOMMU not present."_ If you get this error message, you need to __1) ensure that your CPU supports IOMMU (I/O Memory Management Unit)/Intel Virtualization Technology for Directed I/O (VT-d)__ and __2) that you [enable IOMMU in your BIOS](https://us.informatiweb.net/tutorials/it/bios/enable-iommu-or-vt-d-in-your-bios.html#msi-bios-american-megatrends).__ Navigate through each BIOS screen using the “arrow” keys and find the “IOMMU,” “I/O Memory Management Unit,” or “Intel ® VT-d”setting (usually located under the “Advanced” or “Chipset/Northbridge/Tylersburg IOH/Intel VT for Directed I/O Configuration”settings menu).`VT-d`, `ACS`, `ARI`, `virtualization` on your mother board `BIOS`. __Look under UEFI__ settings and __enable UEFI__ wherever available.  If you try to start the VM and IMMOU is not supported or configured/enabled at the BIOS level, you will also get an error.
>
> > Note to __NVIDIA Users__: If you're still experiencing issues, or the ROM file is causing issues on its own, you might need to patch the ROM file (particularly for NVIDIA cards). There's a great tool for patching GTX 10XX series cards here: https://github.com/sk1080/nvidia-kvm-patcher and here https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher. It only works for 10XX series though. If you have something older, you'll have to patch the ROM file manually using a hex editor, which is beyond the scope of this tutorial guide.

- If you are passing a GPU or any othe PCI that needs drivers, __download the necessary drivers directly__.

> Important for __Linux Users__: You can run a `wget` followed by the official driver download link via terminal.
> Example: `wget https://international.download.nvidia.com/long-name-driver-number-specific-to-your-card.run`
> Also, you will need to install some dependancies on Linux in order to get the NVIDIA driver to compile itself. Run the following to install those dependencies: `sudo apt install build-essential libglvnd-dev pkg-config -y`
> And then, run the NVIDA installer we previously downloaded via `wget` by running the following command: `sudo ./NVIDIA-Linux [TAB out the rest] + ENTER`.
> Run `lspci -v` and you should now see the `Kernal driver in use: nvidia` now updated in the list.
> 
> ![nvidia_linux_driver](https://i.imgur.com/DVtGyeT.png)
> On your Linux VM with the GPU passthrough, test the NVIDIA driver using `nvidia-smi`. If you get an "Unknown Error" then you must edit the `/etc/pve/qemu-server/<vmid>.conf` and ensure that that the following is reflected `cpu: host,hidden=1,flags=+pcid`. This will ensure that the host machine cannot detect that it is a virtual machine, thus permitting the NVIDIA driver to run.

### Troubleshooting "TASK ERROR: start failed: QEMU exited with code 1"
When trying to add the PCI device and booting for the first time, you may incentor this task error and the VM will not start. If this is the case, ensure you do NOT check "Primar GPU" as this will break the VM as pictured below:
![no_all_func](https://i.imgur.com/xlllnp9.png)

### NVIDIA Drivers VM Check
- __SSH to your VM__ and __run the following command to check__ if the GPU / PCI is listed:

```
lspci | grep -i nvidia

# get GPU status
nvidia-smi
```
- If the drivers are loaded, `lsmod` will list them and you can proceed to add the PCI VGA device to the target VM. If not, you'll need to download the NVIDIA drivers to the target VM. See below.

### Download NVIDIA Drivers to Host
- You have a few options for installing NVIDIA drivers:
  - From NVIDIA's Website: Go to the NVIDIA Driver Downloads page to select your GPU model and Linux version to download the correct driver. This method requires switching to a text terminal and stopping the graphical interface to install the driver.
  - Using a Package Manager (Recommended for Proxmox and Debian-based systems): Install the drivers using APT. This method is easier and handles dependencies automatically:
```
apt update
apt install nvidia-driver
```

#### Add Non-Free Repositories:
The NVIDIA drivers might be located in the non-free repositories, which are not enabled by default on Debian-based systems. You can add these by modifying your /etc/apt/sources.list:
- Open the sources file:
```bash
sudo nano /etc/apt/sources.list
```
- Add non-free to your Debian repository lines. For example:
```arduino
deb http://deb.debian.org/debian/ buster main contrib non-free
deb-src http://deb.debian.org/debian/ buster main contrib non-free
```
> Replace buster with your actual Debian version (e.g., bullseye, stretch).

- Save, exit the edior, then run:
```
apt update
```
- Install the Kernel Headers and Build Tools:
   - Sometimes, the NVIDIA drivers require kernel headers and build tools to compile modules:
```
apt install linux-headers-$(uname -r) build-essential
```
- Try Installing the NVIDIA Driver Again. After ensuring that the non-free repository is enabled and your system is updated:
```
apt install nvidia-driver
```
- If the drviers installed, reboot the machine:

```
reboot
```

### Direct NVIDIA Website Install Method
#### Use the NVIDIA Official Installer:
- If the package manager still doesn't work, you can download the official NVIDIA driver from the NVIDIA website:
  - Visit the NVIDIA Driver Downloads page.
  - Select your GPU model and Linux distribution.
  - Download the runfile (*.run).

> Before running the installer, you might need to stop your display manager: `sudo systemctl stop [display-manager].service  # e.g., gdm3, lightdm, sddm`

- Make the downloaded script executable and run it:
```bash
chmod +x NVIDIA-Linux-x86_64-xxx.xx.run
sudo ./NVIDIA-Linux-x86_64-xxx.xx.run
```
Follow the on-screen instructions to install the driver.
- Reboot and Verify:
  - Reboot your system:
```
sudo reboot
```
- After rebooting, check that the NVIDIA driver is correctly installed:
```
nvidia-smi
```

# Windows Proxmox Install

- [TechnoTim's Win10 Proxmox Install](https://www.youtube.com/watch?v=6c-6xBkD2J4)
- Download Windows ISO and _virtIO_.
- Create a VM (set to Windows)
- Add a 2nd CD-ROM drive and attach the _virtIO_ drivers
- Check that your hardware config is the same as below:

![exampleofhardwarewinconfig](https://i.imgur.com/8zqvoxI.png)

- Boot the machine and __select custom install__
- Click __Load Drivers__ and browser for the following files in that _virtIO_ CD-ROM:

```
> vioscsi > w10 > amd64 > ok > next
> netkvm > w10 > amd64 > ok > next
> ballon> w10 > amd64 > ok > next
```

> Note: You may have to _uncheck_ the "hide drivers that aren't compaitble" box to see the drivers.

- Select the unallocated drive and click next to install Windows.
- Set up your Window account.
- Load the following drivers:

```
> WIN + S > Device Manager > Other Devices > Update Driver > Browse my computer > Select the _virtIO_ disk > ok > install
```

- Using the Windows explorer `WIN + E` navigate to:

```
CD Drive > Guest Agent > Double-click `qemu-ga-x86_64` > Install
```

- Reboot the Windows machine.

> You should see an IP address in the VM > Summary tab after you restart it.

# Pihole Proxmox Install
- [Master DNS Block Lists](https://firebog.net/)
- Create a new VM (ideally Ubuntu 20.04 cloudinit)
- Access the VM console and run an update:

```
sudo apt update
```

- Set a static IP address for this new VM in your router settings (PiHole needs to be a static IP because it operates as a DNS server)
- Next, install PiHole

```
curl -sSL https://install.pi-hole.net | bash
```

> Note: If you get a `'curl' not found` message, you can install `curl` by entering: `sudo apt install curl`

- Progress through the prompts, just makes sure to agree to install the `Admin Web Interface` with dependancies.
- Once the PiHole installation completes, take note of the web UI portal IP address (should be the static IP you set before), and __take special note of the unique password generated__ to access the web UI. For example: `http://192.168.1.22/admin`
- [Block List Project](https://github.com/blocklistproject/Lists) has a great starting point for implementing black lists. Simply copy the github link you want and import it through the Pihole GUI:

![pihole_adlist](https://i.imgur.com/4nByJNh.png)

### More Adlists

#### Sus List
```
https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts https://v.firebog.net/hosts/static/w3kbl.txt https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt https://someonewhocares.org/hosts/zero/hosts https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts https://winhelp2002.mvps.org/hosts.txt https://v.firebog.net/hosts/neohostsbasic.txt https://raw.githubusercontent.com/RooneyMcNibNug/pihole-stuff/master/SNAFU.txt https://paulgb.github.io/BarbBlock/blacklists/hosts-file.txt
```

#### Ad List
```
https://adaway.org/hosts.txt https://v.firebog.net/hosts/AdguardDNS.txt https://v.firebog.net/hosts/Admiral.txt https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt https://v.firebog.net/hosts/Easylist.txt https://pgl.yoyo.org/adservers/serverlist.php hostformat=hosts&showintro=0&mimetype=plaintext https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts
```

#### Tracking List
```
https://v.firebog.net/hosts/Easyprivacy.txt https://v.firebog.net/hosts/Prigent-Ads.txt https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/android-tracking.txt https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/AmazonFireTV.txt https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt
```

#### Malicous List
```
https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt https://v.firebog.net/hosts/Prigent-Crypto.txt https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts https://bitbucket.org/ethanr/dns-blacklists/raw/8575c9f96e5b4a1308f2f12394abd86d0927a4a0/bad_lists/Mandiant_APT1_Report_Appendix_D.txt https://phishing.army/download/phishing_army_blocklist_extended.txt https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt https://v.firebog.net/hosts/RPiList-Malware.txt https://v.firebog.net/hosts/RPiList-Phishing.txt https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts https://urlhaus.abuse.ch/downloads/hostfile/ https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt https://v.firebog.net/hosts/Prigent-Malware.txt
```

#### Crypto Block List
```
https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser
```

#### Porn Block List
```
https://raw.githubusercontent.com/chadmayfield/my-pihole-blocklists/master/lists/pi_blocklist_porn_top1m.list https://v.firebog.net/hosts/Prigent-Adult.txt 
```

#### Facebook Block List
```
https://raw.githubusercontent.com/anudeepND/blacklist/master/facebook.txt
```

### Whitelisting Common Services/Domains

#### Quick, Easy, Auto-updated Whitelist Scripts

- For a quick and easy blanket whitelist of most common domains, [run this python script](https://github.com/anudeepND/whitelist).

```
sudo apt install python3

git clone https://github.com/anudeepND/whitelist.git

sudo python3 whitelist/scripts/whitelist.py

git clone https://github.com/anudeepND/whitelist.git

cd whitelist/scripts

sudo ./referral.sh
```

#### Automate Whitelist Updates

- To set your whitelist to automatically update, perform the following commands:

```
cd /opt/
sudo git clone https://github.com/anudeepND/whitelist.git
```

- Make the script to run the script at 1AM on the last day of the week

```
sudo nano /etc/crontab
```

- Add this line at the end of the file:

```
0 1 * * */7     root    /opt/whitelist/scripts/whitelist.py
```

- `CTRL + X` then `Y` and `Enter`. And, to finish, run:

```
sudo python3 whitelist/scripts/whitelist.py
```


- If you ever need to remove the blanket-whitelist, simply enter:

```
sudo python3 uninstall.py
```

#### Set a More Custom Whitelist
- For a more customized, granular control of your whitelisting, see [Commonly Whitelisted Domain List](https://discourse.pi-hole.net/t/commonly-whitelisted-domains/212)

```
pihole -w -spclient.wg.spotify.com apresolve.spotify.com && pihole -w api-tv.spotify.com &&

pihole -w -spclient.wg.spotify.com apresolve.spotify.com api-tv.spotify.com upload.facebook.com creative.ak.fbcdn.net external-lhr0-1.xx.fbcdn.net external-lhr1-1.xx.fbcdn.net external-lhr10-1.xx.fbcdn.net external-lhr2-1.xx.fbcdn.net external-lhr3-1.xx.fbcdn.net external-lhr4-1.xx.fbcdn.net external-lhr5-1.xx.fbcdn.net external-lhr6-1.xx.fbcdn.net external-lhr7-1.xx.fbcdn.net external-lhr8-1.xx.fbcdn.net external-lhr9-1.xx.fbcdn.net fbcdn-creative-a.akamaihd.net scontent-lhr3-1.xx.fbcdn.net scontent.xx.fbcdn.net scontent.fgdl5-1.fna.fbcdn.net graph.facebook.com b-graph.facebook.com connect.facebook.com cdn.fbsbx.com api.facebook.com edge-mqtt.facebook.com mqtt.c10r.facebook.com portal.fb.com star.c10r.facebook.com star-mini.c10r.facebook.com b-api.facebook.com fb.me bigzipfiles.facebook.com l.facebook.com www.facebook.com scontent-atl3-1.xx.fbcdn.net static.xx.fbcdn.net edge-chat.messenger.com video.xx.fbcdn.net external-ort2-1.xx.fbcdn.net scontent-ort2-1.xx.fbcdn.net edge-chat.facebook.com scontent-mia3-1.xx.fbcdn.net web.facebook.com rupload.facebook.com l.messenger.com plex.tv tvdb2.plex.tv pubsub.plex.bz proxy.plex.bz proxy02.pop.ord.plex.bz cpms.spop10.ams.plex.bz meta-db-worker02.pop.ric.plex.bz meta.plex.bz tvthemes.plexapp.com.cdn.cloudflare.net tvthemes.plexapp.com 106c06cd218b007d-b1e8a1331f68446599e96a4b46a050f5.ams.plex.services meta.plex.tv cpms35.spop10.ams.plex.bz proxy.plex.tv metrics.plex.tv pubsub.plex.tv status.plex.tv www.plex.tv node.plexapp.com nine.plugins.plexapp.com staging.plex.tv app.plex.tv o1.email.plex.tv  o2.sg0.plex.tv dashboard.plex.tv gravatar.com thetvdb.com themoviedb.com chtbl.com services.sonarr.tv skyhook.sonarr.tv download.sonarr.tv apt.sonarr.tv forums.sonarr.tv dl.dropboxusercontent.com ns1.dropbox.com ns2.dropbox.com s.marketwatch.com fpdownload.adobe.com entitlement.auth.adobe.com livepassdl.conviva.com gfwsl.geforce.com delivery.vidible.tv img.vidible.tv videos.vidible.tv edge.api.brightcove.com cdn.vidible.tv v.w-x.co appspot-preview.l.google.com tracking.epicgames.com cloudsync-prod.s3.amazonaws.com 79423.analytics.edgekey.net assets.adobedtm.com nexus.ensighten.com telemetry-console.api.playstation.com twitter.com upload.twitter.com api.twitter.com mobile.twitter.com
```

- And also run a `--white-regex` for the following:

```
pihole --white-regex (\.|^)twimg\.com$ (\.|^)reddit\.com$ (\.|^)redd\.it$ [a-z]\.thumbs\.redditmedia\.com
```

### Unbound DNS
- To bypass the Google DNS server resolvers completely and take privacy into your self-hosted control, you need `Unbound`.
- Enter the following to install it:

```
sudo apt install -y unbound dnsutils
```

- Update the `root hints` file (advised to update every 6mos.):

```
sudo wget https://www.internic.net/domain/named.root -qO- | sudo tee /var/lib/unbound/root.hints
```

- Now, we need to properly configure Pihole to accept the Unbound DNS. Start by creating the file:

```
sudo touch /etc/unbound/unbound.conf.d/pihole.conf
```

- You can get this pre-made config contents from [Pihole's documentation](https://docs.pi-hole.net/guides/dns/unbound/). 

```
sudo nano /etc/unbound/unbound.conf.d/pihole.conf
```

- Copy and paste the contents in that new file:

```
server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 0

    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # May be set to yes if you have IPv6 connectivity
    do-ip6: no

    # You want to leave this to no unless you have *native* IPv6. With 6to4 and
    # Terredo tunnels your web browser should favor IPv4 for the same reasons
    prefer-ip6: no

    # Use this only when you downloaded the list of primary root servers!
    # If you use the default dns-root-data package, unbound will find it automatically
    #root-hints: "/var/lib/unbound/root.hints"

    # Trust glue only if it is within the server's authority
    harden-glue: yes

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
    harden-dnssec-stripped: yes

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size.
    # IP fragmentation is unreliable on the Internet today, and can cause
    # transmission failures when large DNS messages are sent via UDP. Even
    # when fragmentation does work, it may not be secure; it is theoretically
    # possible to spoof parts of a fragmented DNS message, without easy
    # detection at the receiving end. Recently, there was an excellent study
    # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
    # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
    # in collaboration with NLnet Labs explored DNS using real world data from the
    # the RIPE Atlas probes and the researchers suggested different values for
    # IPv4 and IPv6 and in different scenarios. They advise that servers should
    # be configured to limit DNS messages sent over UDP to a size that will not
    # trigger fragmentation on typical network links. DNS servers can switch
    # from UDP to TCP when a DNS response is too big to fit in this limited
    # buffer size. This value has also been suggested in DNS Flag Day 2020.
    edns-buffer-size: 1232

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes

    # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
    num-threads: 1

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

    # Ensure privacy of local IP ranges
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
```

- Now that the config file has been set, you can restart the Unbound services and check the status:

```
sudo systemctl restart unbound
sudo systemctl status unbound
sudo systemctl enable unbound
```

- Now that Unbound is installed, we need to tell PiHole to use this Unbound DNS resolver for all it's outbound traffic. Navigate to:

```
> Pihole Web UI > Settings > DNS (tab) > Uncheck current DNS servers
```

- After removing the current upstream DNS servers selected, you need to set your custom Unbound one as follows:
  - In the Upstream DNS Servers `Custom 1 (IPv4)` field __enter `127.0.0.1#5533`, check the box, and hit Save__ (button).

### Pihole Troubleshooting

- Error: __DNS resoluion is currently unavailable__
  - Explaination: After implementing `Unbound` as my DNS resolver, I found that when trying to update the `Gravity` using `pihole -g` I get an error stating __DNS resoluion is currently unavailable__.
  - Solution: __Edit your `/etc/resolv.conf`__ file and __re-run `pihole -g`__. See `reslove.conf` below:

```
nano /etc/resolv.conf
# add/modify the following lines 
nameserver 127.0.0.1
nameserver 9.9.9.9
```

# TrueNAS Scale

### TrueNAS Scale Install in Proxmox

- First, download the TrueNAS Scale ISO file
- Upload it to the Proxmox ISO storage
- Create new VM and select that TrueNAS Scale ISO as the OS
- Leave the System tab defaults (no changes) and click next onto the disks section
- On the Disks tab, click the `Advance` (checkbox) so we get more settings to tweak. Check the following: `SSD emulation`, `Discard`, and change the __Disk size (GiB)__ to `16`. Leave all other settings as-is.

![truenas_disk_settings](https://i.imgur.com/Z94xuGE.png)

- On the CPU tab, start off with more cores than less (you can always upgrade/downgrade vCPUs later, but you cannot give it more vCPUS than the total core limit you initially set at creation). In my case, I'm giving it:
  - 2 sockets and 6 cores for a total of 12 cores.
  - Check `Enable NUMA` (checkbox)
  - In advance settings, turn `md-clear` on (if your device supports it, you'll know if it works or not when you first try to boot it and if any error messages popup)
  - In advance settings, turn on `aes`
  - In advance settings, turn on `pdpe1gb`
  - In the `Type` field, select your CPU's iteration (i.e. IvyBridge)
- In the `Memory` tab, TrueNAS recommends at least __8GB of RAM__ for better performance and fewer issues. (In my case, I need `262144` MiB of RAM for my Chia Farm setup).
  - I also disabled `Balloning Device` by unchecking the box. This avoids complicating things.
- Leave the `Networking` section as-is.
- Finish the VM config and start it up. If you don't get any errors, you're good to go!

### TrueNAS Scale Install DOS Wizard
- Select `Install/Upgrade`
- Toggle to the drive you wish to install TrueNAS on and hit `Spacebar` to select it and then hit `OK` to continue.
- Say `Yes` to overwriting the disk to install TrueNAS.
- Create Admin user (option 1) and set a password for that account.
- Hit `OK` and wait for TrueNAS to install, then shutdown the VM to add PCIe hardware (i.e. adding JBOD drives to TrueNAS).

### Passing Through PCIe Storage Controllers to TrueNAS
- Navigate to __TrueNAS VM > Hardware > Add (button) > and add PCI Device__
  - Sort the `Device` dropdown menu by name to find your PCI device quicker.
  - Disable `ROM-Bar` to avoid booting performance issues.
  - Leave everything else as-is and add it.

> Note: In order for the PCI devices to work, make sure to follow the steps outlined in [the PCI passthrough guide](#pcie-gpu-passthrough) above. Basically, you need to edit the `grub` config to include IOMMU. Ex. `GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"` and `update-grub` then `reboot`.

### Adding Drives to TrueNAS
- Now that PCI devices and IOMMU passthrough are added, start the TrueNAS VM up and get the web UI IP address.
- Open your browser, put in that IP, enter your creds, and you should have reached the TrueNAS interface/dashboard.
- Customize your dashboard views to your liking (configure button, top right).
  - Toggle off: everything in `Network`, `System Information`, `Help`, then `Save` (button)
- Navigate to __Storage (left pane) > Create Pool (top right button) > Assign a name (i.e. dataAA) > Select all the drives you wish to add to that pool__ (12 disks / pool is a good start) __> Select your preferred disk array type (under Data VDevs) > Create the pool.__

> "Stripe" is ideal for performance and size, but not redundancy.

- Set the `Block Size Record` to `1` by navigating to: __Datasets (left pane) > Click on the pool (from list) > Click Dataset (button) > Assign a name (same as pool name) > Disable `Sync` (dropdown) > Turn `Compression` OFF (dropdown) > Turn `Enable Atime` OFF > Turn `ZFS Depreciation` OFF > Set `Case Sensitivity` to `Sensitive` > Open the Advance settings > Change the `Record Size` to `1M` > Leave the rest AS-IS.__
- Navigate to: __> Shares (left pane) > Click the `UNIX (NFS) Shares` Add button > Set the Path to the Pool__ (i.e. `/mnt/dataAA/dataAA`) __> Hit `Save` > Agree to `Enable Service` (prompt)__

> Note: the `/mnt/dataAA/dataAA` is the mountpoint/patg that will be used for mounting your NFS share to other machines on the network.

> If you want Windows to recognize the storage pool, you need to change the Dataset settings in `Share Type` to `SMB`. Also, you want to create a `Windows (SMB)` Share instead of the `UNIX (NFS)` share.

- If you want to access your TrueNAS shares _without_ credentials, then navigate to: __`System Settings` (left pane) > Services > NFS > Check `Enable NFSv4`__. Hit `Save`.
- While in the `General Options` you can modify the `Number of Threads` also.

# Portainer

- Create a new Ubuntu VM and name it Portainer.
- Install Docker and Portainer using the following commands:

### Install Docker

- If you always want to automatically get the latest version of Docker on Ubuntu, you must add its official repository to Ubuntu system. To do that, run the commands below to install prerequisite packages:

```
sudo apt update && sudo apt upgrade

sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
```

- Next, run the commands below to download and install Docker’s official GPG key. The key is used to validate packages installed from Docker’s repository making sure they’re trusted.

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

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
sudo apt-get install docker-ce docker-ce-cli containerd.io
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
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
```

> Note: the `-v /var/run/docker.sock:/var/run/docker.sock` option can be used in Linux environments only.

- At this point, all you need to do is access Portainer portal to manage Docker. To access the Portainer web UI, enter the IP address of the VM (or the public IP of your VPS) you created https://x.x.x.x:9443

```
https://<SERVER_IP>:9443
```
- If you are having issues connecting to the web UI, configure your firewall via `ufw` to access:

```
sudo apt install ufw
sudo ufw allow 9443/tcp
sudo ufw allow 8000/tcp
sudo ufw enable
sudo ufw status
```

- You should get Portainer login page to create an admin password.
- Submit a new password (make it a good one as this is publically accessible if hosted on a VPS).
- Select __Local__ as the type of envirnoment you want to manage.
- Since we installed Docker on the same machine, select to connect and manage Docker locally.

> You can check [Portainer's port configurations doc for Kubernetes](https://docs.portainer.io/start/requirements-and-prerequisites) to double-check.


- Usefull Portainer Commands:

```
# if you get a timeout error, restart Portainer:
sudo docker restart portainer

# check Portainer status
docker ps
```

# Plex

- Assuming you have successfully pass a GPU through to your VMs, you can now take advantage of GPU-accelerated transcoding.

> Note: You must have the Plex server claimed and a lifetime or Plex pass subscription to use GPU-accelerated encoding.

#### Installing a Plex Media Server
- Start by __creating a VM__ that will be your dedicated Plex server.
- __[Visit the repository](https://support.plex.tv/articles/235974187-enable-repository-updating-for-supported-linux-server-distributions/)__ for Plex and __copy and paste the DEB-based distros__ into the terminal of your new Plex VM to enable the Plex Media Server repo on the Ubuntu instance.

```
echo deb https://downloads.plex.tv/repo/deb public main | sudo tee /etc/apt/sources.list.d/plexmediaserver.list
curl https://downloads.plex.tv/plex-keys/PlexSign.key | sudo apt-key add -
sudo apt install plexmediaserver -y
sudo apt-get update
sudo apt upgrade
```

- If Plex installed successfully, __you should be able to access the Plex web UI__ now from the browser.
- Next, will want to enalbe instant connection to any network shares where the actual media files are stored on server boot. __Within the Plex server terminal, type:__

```
sudo nano /etc/fstab
# at the end of the file enter the path to the network file share IP address (i.e. TrueNas, Synology)
//192.168.1.200/PlexTest /PlexMedia cifs username=plextest,password=12345 0 0
```

- Now, we must __create that `PlexMedia` directory__ (same path as set inside the `fstab` config):

```
sudo mkdir /PlexMedia
```

> To test, reboot your VM, and enter the following:
> ```
> cd /PlexMedia/
> ls
> ```
> If you get a return of folders/files, the `fstab` configuration was a success!

- Now that we have mounted the media file server to our Plex VM, we need to __add this directory in the Plex web UI__ via __Manage > Libraries > Add Library (button) > Select the type of media you want to add (i.e. Movies, TV Shows, etc.) > Next (button) > Browse for the /PlexMedia/ folder by clicking on `/` and scroll down to the `PlexMedia` folder > Add (button) > Add Library (button).__ You should now see some media added to Plex.
- To upscale the streaming quality, __navigate to the Plex dashboard under > Plex Web > Quality > Video Quality > Uncheck "Use recommended settings > Set the bitrate you want (i.e. 10Mbps, 1080o) > Save Changes (button)__.
- From the Plex menu, __navigate to Transcoder > Check "Use hardware-accelerated video encoding" > Check "Use hardware accelration when available > Save Changes__
- __Pass the GPU through to that VM__ (don't forget to grab the VM IP before or use Advance IP Scanner to find it). Done.

# Kubernetes
Kubernetes is a Greek word κυβερνήτης, meaning “helmsman” or “pilot”. As the name entails, it is a powerful, serverless orchestration tool for managing multiple nodes in a cluster to provide high-availability, scalable web application services. In this use-case, we are rock'n [K3s](https://docs.k3s.io/). Sound amazing? Why not add it to your homelab? Let's go!

#### Create a K3S Cluster
- Start by __creating five new VMs__ and naming them. See my [cloud init template guide](#cloud-init-template) for a super-fast way to create new lightweight VMs.
- Next, use terminal or PuTTY to __access the newly created VM__ that you wish to make your __master node__.
- Once you're in the master node, __grant your user root priviledges__

```
sudo su -
```

- As a prerequisite, `k3s` needs to have `iptables` to integrate with Rancher. Enter the following to install `iptables`:

```
sudo apt-get install iptables
```

- To install K3S paste the following command:

```
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s
```

- __Give the command a minute to run__ and find and download the K3S installation script (it shouldn't take more than a minute). If successful, you should read a message stating, "__Starting k3s__"
- To test that `k3s` is functional and to check your current node setup, enter the following command:

```
kubectl get nodes
```

- Since we have not yet added additional nodes, __you should only see one master node listed__. That's okay, but let's change that by adding new nodes!
- Remember those other VMs you created, it's time to __add them using the `token` from the master node__.

```
cat /var/lib/rancher/k3s/server/node-token
```

- __Copy the `node token`__ you see (you'll need it when you install `k3s` on the other VMs.
- __SSH__ to the second VM you created to be a __worker node__, and __grant yourself `sudo` root authorization__ as before: `sudo su -`.
- Next, enter the command below to __add this VM as a worker node__.

```
curl -sfL https://get.k3s.io | K3S_TOKEN="[YOURTOKEN]" K3S_URL="https://[YOUR_MASTER_NODE_IP]:6443" K3S_NODE_NAME="[YOUR_WORKER_NAME]" sh -
```

> Check if it worked by running `kubectl get nodes` on the master node. If you see a new node added, then you did it right. Congrats!

- If all went well creating your first worker node, __repeat the steps above__ until all nodes are added to your `k3s` cluster. As a recap, SSH to the VM, grant `sudo` auth, paste the `curl` command, update the worker name, and check if it was added.

# Rancher
Think of Rancher like, well, a rancher herding cattle or a queen bee controlling her worker drone bees. Rancher is a powerful, visual orchestration tool for K3S, and you will want it! Here's how to get it:
- First, start off by __creating another VM__ to run your Rancher controller (_2CPU and 4GB of RAM is sufficient, but don't go less than that or you may encounter problems_).
- Next, SSH into the VM and __create a new directory, `cd` to it, and create a blank file__ as follows:

```
sudo su -
cd /ect
sudo mkdir rancher
cd rancher
sudo mkdir rke2
cd rke2
nano config.yaml
```

- Once you are in the `config.yaml` file, __add the following contents__:

```
token: [passphrase]
tls-san:
  - [IP_of_Rancher_VM]
```

- Once you have saved those conents to the `config.yaml`, __it's time to install Rancher__:

```
curl -sfL https://get.rancher.io | sh -
```

- __Test if Rancher installed via `rancherd --help`__. If you get a `Rancher Kubernetes Engine` as a return, it is working.
- __Set Rancher to enabled and run continuously__ in the background via:

```
systemctl enable rancherd-server.service
systemctl start rancherd-server.service

# provides output of processes and logs
journalctl -eu rancherd-server -f
```

> Note: The Rancher installation automatically creates a second K3S cluster that will run alongside the K3S cluster we just created after we add it to the Rancher cluster.

- __Once the logs inidicate that the processes are completely finished hit `CTRL + C`__ to stop the log updates. Specifically look for __Successfully initialized node rancher with cloud provider__ message. 
- Assuming that Rancher is completely installed, up, and running, it's now time to __reset the default password__ for the Rancher web UI.

```
rancherd reset-admin
```

- This command will spit out the web UI address (you'll need this to login in a moment), and the username and password. __Take note of the URL IP, and username, and copy the password.__

> Note: If you the __FATA[0000] cluster and rancher are not ready. Please try later.: the server could not find the requested resource__ message, then you need to give Rancher more time to finish set up.

- __Enter the IP Rancher__ provided in your web browser, then __enter that username and paste that password__ to access the Rancher UI.

![rancher_login](https://i.imgur.com/ei73SSD.png)

- Next, you need to __input a new password__ (save this for future use).
- __Select the multi-cluster view__ that says something like: "I want to create or manage multiple clusters."
- Once you gained access to the UI, we want to add our existing `k3s` cluster to Rancher. Click on the __Add Cluster__ (button on the top right) > __Other Cluster__ > __Input a Name__ > __Copy the command line starting with `curl`__.
- SSH back into your __master node__ and __paste that command__ and `ENTER`. This will make this cluster join the Rancher UI.

> Note: If you are running your `k3s` cluster on the __ARM architechure__ you need to edit the API: Click on the three dots of the newly added cluster > View in API > Edit > Paste `rancher/rancher-agent:v2.5.8-linux-arm64` into the _agentImageOverride_ field > Show Request (button at bottom) > Send Request (button at bottom) > Exit. You should now see the state/status change to "Active."

# Techno Tim K8S

### Ansible
Ansible is an automation tool that will be needed for running handy playbooks to install a K3S high-availability cluster and run all your self-hosted web applications.

- Thanks to [TechnoTim for his expensive how-to Ansible guide](https://docs.technotim.live/posts/ansible-automation/). I will be referencing it for my guide.
- First, create a new VM to install Ansible on. I suggest you __clone the cloud init template__ that we created earlier. See [Create Cloud Image VM Template](#create-cloud-image-vms) for more info.
- Once inside your Linux environment, run the following commands:

1. Update your Linux
```
sudo apt update
```

2. Install Dependencies
```
sudo apt install software-properties-common
```

3. Add Ansible Repo
```
sudo apt-add-repository --yes --update ppa:ansible/ansible
```

4. Install Ansible
```
sudo apt install ansible -y
```

5. Install `sshpass` (if needed) 
```
sudo apt install sshpass -y
```

- Once Ansible is installed, you can run some staus check commands:
```
ansible --version
```
- Take special note of the Python version. Your server will need Python __3.5__ _at least_ to run Ansible.

> If Ansible or Python is not the version you want, check to see where it is installed:
> ```
> which ansible
> ```
> To remove that version:
> ```
> sudo apt remove ansible
> ```
> Check if it is removed. You should see `ansible not found`:
> ```
> which ansible
> ```
> Install `pip`
> ```
> curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
> ```
> Re-install Ansible
> ```
> python3 -m pip install --user ansible
> ```
> And, confirm your Ansible version:
> ```
> andible --version
> ```
- From here, proceed to the Kubernetes section to use TechnoTim's Ansible setup playbook for your Proxmox server.

#### Custom Ansible Play Books
- If you want to create custom playbooks, you'll need a good text editor to create the `.yml ` files for Ansible configuration. You can use [Visual Sutdio Code | VSCode editor](https://code.visualstudio.com/) or any other editor of your choice.
- See the [official Ansible site for powerful playbook parameters](https://docs.ansible.com/ansible/latest/cli/ansible-playbook.html) you can utilize.
- Also, see [TechnoTim's Anisbile documentation](https://docs.technotim.live/posts/ansible-automation/#installing-the-latest-version-of-ansible) and [his GitHub](https://github.com/techno-tim) on customizing and creating Ansible playbooks.

### Techno Tim's K8S + Ansible Installer Guide (WIP)
- Once the VMs are created, use the Proxmox console (button), login, and __take note of each server IP address__. You will need this later! 
- Remote back into you __Ansible server__ and `cd` to your user directory `cd /home/<user>`.
- Create a subfolder for Techno Tim's Ansible playbook; something like: `mkdir ttansible` will do, then `cd` into that folder.
- Next, want to clone [TechnoTim's Ansible repo](https://github.com/techno-tim/k3s-ansible) to this directory. Give it a star! He earned it! Here's the command to clone it to your Ansible VM:
```
git clone https://github.com/techno-tim/k3s-ansible
```
- After the repo clones to your machine, check the directory with an `ls` command and then `cd` into that repo folder you just cloned.
- Once inside the reop clone folder, `ls` again and you should now see `ansible.example.cfg`.
- Let's create a local copy of this `.cfg` file on your machine:
- 
```
cp ansible.example.cfg ansible.cfg
```
- Once you successfully made a copy of the `.cfg`, now you must customize/adapt the file to your personal environment. `nano` or `vim` that `ansible.cfg` file copy you just made to get started.
```
cat ansible.cfg
```
- The file should read: __`inventory = inventory/my-cluster/hosts.ini`__. If this is the case, do __NOT__ change anything. If `cat` prints something else, modify the file to read as __`inventory = inventory/my-cluster/hosts.ini`__. Otherwise, leave this default setting as we will modify the directory to match.
- Exit the `.cfg` file, and create the following directories:
```
cd inventory
mv ./sample ./my-cluster
```
> Note: The `rename` command may not be available on your Linux distro. If that is the case, you can either A) use `mv` instead. B) Install `rename` via `sudo apt install rename`, and try again.
- Now, customize the `hosts.ini` file using `nano` or `vim`.
```
vim hosts.ini
```
- Inside this file, you must modify the default IP address as to match the actual IP address of the VMs to match.

__Example:__
```ini
[master]
192.168.30.38
192.168.30.39
192.168.30.40
[node]
192.168.30.41
192.168.30.42
[k3s_cluster:children]
master
node
```
> Cluster Config File Note: You will need to enter the IP addresses of the VMs you wish to use as the masters and the IP addresses of the VMs you wish to use as nodes. This will be different for every Proxmox environment, and it may be helpful to set these as static IP addresses inside your router settings for future use.

- With the `hosts.ini` customized to your network environment, you are now ready to configure and customize your Ansible `.yml` file which is inside the `./my-cluster/group_vars` folder.

```
cd group_vars
vim all.yml
```

- Once inside the `.yml` file, you will be greeted by a wall of text that needs to be customized. At this point, it is helpful to reference the Ansible `.yml` file [creator's video](https://youtu.be/CbkEWcUZ7zM?t=395) for better insight, but here are the steps to take:
- The `falnnel_iface` is responisible for layer 3 communications between the VMs in the cluster. This should be the same ethernet intervace as the VMs.
- __Set your timezone__ (i.e `America/Chicago` or `America/New_York`).
- __Set the public IP address__ you wish to use as your virtual IP address that will be created for the k3s cluster: `apiserver_endpoint: "<your_IP>"`
- Generate and set a `k3s_token`. This is essentially an alpha-numeric (no special characters) string/password. For example: `K108a732b7cfb59036f2362848d61823733359bbdf152192f7ebc6ad4b3078fd659`. Do __NOT__ use this password or you could get hacked.
- - Now, it's time to __add the arguments__. According to TechnoTim, only three arguments are necessary, but the following args are nice additions (staring under the `--disable traefik` line):

> Note: These args will make the clusters more responsive. Because if a node is not ready, it will not schedule new pods until it becomes ready. The timeout is typically 5 minutes. For smaller installations (like our homelab), our service will be down 5 minutes. You may need to tweak these settings depending on your hardware.

```
  --kube-apiserver-arg default-not-ready-toleration-seconds=30
  --kube-apiserver-arg default-unreachable-toleration-seconds=30
  --kube-controller-arg node-monitor-period=20s
  --kube-controller-arg node-monitor-grace-period=20s
  --kubelet-arg node-status-update-frequency=5s"
```
> Tip: I would advise to comment out the following line: `extra_agent_args: "--kubelet-arg node-status-update-frequency=5s"` becuase I had repeat error messages caused by this argument.

- After modifying the ards, you should get a config that looks like this:


![extra_k3s_args](https://i.imgur.com/9ngdzTc.png)


- Leave the `kub-vip`, `metallb`, etc. version tags as-is.
- __Configure the range of IPs__ you wish to reserve for your `metallb` loadbalancer to utilize (this will need to be updated if you have more webservices for your reverse proxy). In my case, reserved `"192.168.1.80-192.168.1.90"`
- That should complete the `all.yml` configuration. __Write and save it__ if you are satisifed with the results.
- Now, we need to __start provisioning the cluster__ by using the following command:

```
ansible-playbook ./site.yml -i ./inventory/my-cluster/hosts.ini
```

> Note: Add the additional strings `-k --ask-pass --ask-become-pass` at the end of the above command if you are using password SSH login. Use `--private-key [path_to_PRIVATE_KEY], --key-file [path_to_PRIVATE_KEY]` to use the file to authenticate the connection.

- After deployment, the control plane will be accessible via virtual ip address which is defined in `inventory/my-cluster/group_vars/all.yml` as `apiserver_endpoint`. This is the same public IP address that you set earlier.

__[WIP]__

- Change the `<proxmox_name>` to your liking.


```
ansible-<proxmox_name> install -r ./collections/requirements.yml
```

- Now, you'll need to `cd` into the repo you cloned and `cp` the `sample` directory within the `inventory` directory.


```
cp -R inventory/sample inventory/my-cluster
```

- Once copied, you must edit the `inventory/my-cluster/hosts.ini` to match your network environment. This file supports DNS also. So, if you are using Pi-hole and Unbound, add the DNS address in this file.
![k3s_embedded_database](https://i.imgur.com/CrErJsy.png)
This [diagram](https://docs.k3s.io/architecture) shows an example of a cluster that has a single-node K3s server with an embedded SQLite database.


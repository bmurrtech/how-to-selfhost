License: MIT (see [LICENSE.md](LICENSE.md)).

# Acknowledgements
- Ben Heater's OG pfSense VLAN guide was immensley helpful. Go check out [Ben's other great guides](https://benheater.com/) no his website! 
- BobCares website to [force a DHCP release](https://bobcares.com/blog/force-dhcp-client-to-renew-ip-address/) came in handy! I guess Bob really does care.

# Table of Contents
- [Provisioning pfSense VM](#provisioning-pfsense)
- [Setup VLANs in Proxmox](#configure-proxmox-nics)
- [Deploy pfSense](#deploy-pfsense)
- [Configure pfSense](#configure-vlans)
- [How to add additional VLANs to pfSense](#how-to-add-additional-vlanss-to-pfsense)
- [Guide to pfSense Rules](#pfsense-firewall-rules)
- [pfSense CE 2.7.0: “Unable to retrieve package information”](#pfSense-CE-2-7-0)
- [HAProxy for multiple domains on one public IP](#HAProxy)

# How-to Guide about the PfSense firewall
Why you want a pfSense firewall:
- Protect your network.
- Limit vulnerbilities.
- Separate VMs from other devices on the network.
- Create a guest or IOT network separate from your home.
- Create a sandbox environment.
- Create a malware test lab.

This guide will teach you how to seperate (VLAN) your VMs from your home/prodcution network so you can stop attackers/guests/gaming-buddies from moving laterally in your network and viewing/accessing/infecting/compromising other machines on the same network.

### Provisioning pfSense

> For reference, see [pfSense's install guide](https://docs.netgate.com/pfsense/en/latest/install/download-installer-image.html).
- Download a pfSense ```.iso``` from the official site: https://www.pfsense.org/download/

> Note: This guide assumes you are deploying the pfSense to a VM in Proxmox; however, if you wish to deploy to a dedicated machine you may wish to download the USB version or burn the ```.iso``` file to a bootable USB instead.
 
> At the time of writing this guide, pfSense does _not_ have a ```ARM``` compatible (i.e. RaspberryPi or ```ARM```-based cloud solutions won't work).

![pfsense_download_page](https://i.imgur.com/BYEXu0X.png)

- Upload the ```.iso``` to your Proxmox hypervisor.

![ISO_upload](https://i.imgur.com/mYBIRX7.png)

- Once you have uploaded the ```.iso```, click ```Create VM``` (button on the top right of Proxmox UI).

> Provision the VM to have the reccomended specs that PfSense advises. Check the [PfSense Min Hardware Reqs](https://docs.netgate.com/pfsense/en/latest/hardware/minimum-requirements.html), but here's what I found:
> - 64-bit amd64 (x86-64) compatible CPU
> - __1GB__ RAM or more
> - __8GB__ disk drive disk drive (SSD, HDD, etc) or larger
> - One or more compatible network interface cards. We will circle back NICs after the install, but see [Configure NICs](###configure-proxmox-nics) for to skip ahead to setting up VLANs on Proxmox.

## Configure Proxmox NICs
To leverage pfSense VLANs we need to configure Proxmox NICs and assign VLAN tags which will be passed through to the pfSense firewall VM.

### Install network dependencies on the Proxmox node: 

- Select Proxmox node > Shell (button) > copy and paste the following:

```pash
apt clean && apt update
apt install ifupdown2 openvswitch-switch -y
```

### Backup your network interface (in case something goes wrong).

- Open a shell to your Proxmox node and run the following:

```bash
cp /etc/network/interfaces /etc/network/interfaces.bak
```

![interfaces_bak](https://i.imgur.com/hIOktIa.png)

> Backup Note: You can always restore the original configuration by overwritting the ```interfaces``` file with your backup ```interfaces.bak``` file.
- Click on your __Proxmox Node > Network__. Select ```vmbr0``` and choose __Remove__.

![remove_linux_bridge](https://i.imgur.com/pDyX8PE.png)

### Create open vSwtiches:

> __Important__: Use a second physical NIC if available for your pfSense web UI/production network because on reboot, Proxmox hijacks the web IP of the pfSense and changes the Proxmox web UI URL access to the pfSense IP. Perhpas this is a bug, but physically attach a different, secondary ehternet cable to a secondary physical NIC on the Proxmox machine and create a third OVS Bridge and assign it to the secondary physical NIC to avoid this issue.

- __Create > OVS Bridge > Bridge ports__: ```<your physical eth interface>```

![ovsbridge1](https://i.imgur.com/3hfa4to.png)

- Fill in the fields as seen in the screenshot below and click __Create__.

![ovsbridge_vmbr2](https://i.imgur.com/wjrvMWY.png)

>  __Note__: Your physical interface will likely be different than mine. Therefore you MUST enter YOUR physical interface name instead. To get your interface name, open a shell to the Proxmox node and enter `ip addr` and it will list the interface(s). Again, it's important to __use a secondary physical NIC__ for the pfSense web UI __to avoid a Proxmox IP conflict__.

### Create the management interface for the Proxmox UI:

- __Create > OVS IntPort__

![ovs_int_port](https://i.imgur.com/AHeuNdq.png)

### Create a pfSense internal switch:

- __Create > OVS Bridge__ > Name: ```vmbr1``` > Comment: ```<pfSense int>```

![pfsense_int_bridge](https://i.imgur.com/OQIwhiY.png)

### Create a VLAN for publically accessible (internet-facing), _non-isloated_ and _unsecure_ VMs:

> The following VLANs are ideal for cybersecurity and malware analysis lab setups. If that's not your jam, then create VLANs to your desired outcome and skip all the SEC_EGRESS and SEC_ISOLATED firewall rules and simply create an RFC1918 alias for all the subnets (i.e. 10.0.0.0/24, 192.168.0.0/24, etc.) and add some basic firewall rules to VLAN'd networks instead. If you just want to set up simple firewall rules that prevent VLAN'd networks from communicating to each other, then see the end of this guide [here on basic pfSense firewall rules](#pfsense-firewall-rules).

- __Create > OVS IntPort__ > Name: "vmbr1_```<VLAN tag>```" > VLAN Tag: ```<number you choose>``` > Comment: `<pfsense egress>`

![pfsense_egress](https://i.imgur.com/FOJ1qHq.png)

### Create VLAN for publically acessible (internet-facing), _isolated_ and _unsecure_ VMs:

- __Create > OVS IntPort__ > Name: "vmbr1_```<VLAN tag>```" > VLAN Tag: ```<number you choose>``` > Comment: ```<pfsense isloated egress>```

![pfsense_egress_isolated](https://i.imgur.com/YTOEiNg.png)

### Apply the New NIC Settings

![apply_proxmox_nic_config](https://i.imgur.com/I0FpMmQ.png)

### Summary of VLANs on Proxmox
You should have a configuration that is similar to the following:

![px_vlan_config_summary](https://i.imgur.com/l5kw4j1.png)

### Troublehooting Connectivity

If you encountered connectivity issues to the ProxMox UI _after_ applying the NIC config changes (i.e. OVS Bridge and VLAN), then you can restore your known working session by logging into your Proxmox server _locally_ (i.e. physically connect a keyboard and monitor to the Proxmox machine) and run the following command from the shell:

```bash
cp /etc/network/interfaces.bak /etc/network/interfaces
ifreload -a
```

This will restore the original, functional network configurations to that you _should_ be able to access your Proxmox web UI again from another computer on the network just as before.

## Deploy pfSense

### pfSense Proxmox Conigurations
- Select the pfSense VM > __Options > OS Type > Edit (button) > Select "other"__
![pfsensexproxmox_opt_config](https://i.imgur.com/eJiiC92.png)

### Ensure your pfSense VM has a staticly assigned IP address from your router:
If the IP address of the DHCP server (usually assigned by your router) changes, you will have issues. To mitigate this problem:
- access your router settings to change the DHCP server settings (usually in LAN > DHCP Server > Mannual IP Assignment)
- identify your pfSense VM's __WAN__ IP/MAC address (usually assigned by DHCP dynamically),
- change it to a static IP,
- then apply the settings in your router.

![pfsense_mac_address](https://i.imgur.com/vdWeoFA.png)

### Add the vmbr1 NIC to the pfSense VM
The following action adds the pfSense internal switch NIC created earlier to the pfSense VM. Once the VM is stopped, you can add the secondary NIC we made before.
- Proxmox Node > pfSense VM > __Hardware > Add (button) > Network Device__ > Bridge: `vmbr1`

![vmbr1_NIC_add](https://i.imgur.com/XixvZFz.png)

> Note: If you get the following error, then reboot your Proxmox machine and try to launch the pfSense VM again.
> ![VM_start_error](https://i.imgur.com/WF782h0.png)

### Start the pfSense VM to begin the setup:

- Click on the VM > __Start__ (button, top right) 
- Open a console or `ssh` session to the pfSense
- Wait for the intiial load screen
- Hit `Enter` to accept the terms

![accept_pfsense_terms](https://i.imgur.com/WlM8hBh.png)

- Progress through the GUI installer

![install_pfsense_GUI](https://i.imgur.com/QfYn7bs.png)

> Note: You may need to enter the advance disk settings to create a mount point if the auto installer method fails. Format as `MBR`, create a partition, then use the auto installer thereafter.

### Interface Setup

- When prompted to setup VLANs, enter `n` for now.
- Enter the __WAN interface__ name (enter what is provided in the prompt;for me it was `vtnet0`), and do not use the auto-detection `a` as it will fail.
- When prompted to enter a 2nd NIC for the __LAN interface__ type: `vtnet1`
- Type `y` to proceed.

![pfsense_install_wizard1](https://i.imgur.com/yfncxX3.png)

- After the installer runs, you should come to an end screen, you should see the WAN and LAN and an IP address to the web UI for pfSense.

![pfsense_end_install_screen](https://i.imgur.com/jLj9gQH.png)

- Take note of the IP that was assigned (or statically set) by the DHCP Server. _This IP is how you will access the pfSense web UI later._ Does it match what you assigned? If not, you may need to renew the IP.

> Note: You may need to manually __invoke a ```dhclient -r <interface>```__ command from the shell of the VM __and reboot the VM__ in order to get the static IP to apply. If you don't know what the interface is on your VM, simply run ```nmcli con``` to get the name of the interface.

### Configure VLANs

- Start the pfSense VM
- Select option `1` to assing the new NIC and setup VLANs
![](https://i.imgur.com/bt1eFtr.png)

1. __Should VLANs be setup now [y|n]__
  - Enter `Y`
2. __Enter the parent interface name for the new VLAN__
  - Enter `vtnet1` (vtnet1 is the LAN interface)
    - Enter tag `666`
- Enter `vtnet1` (again)
    - Enter `999`
3. Press `Enter` to complete the VLAN setup

> You should come this screen in the VLAN setup stage:
> ![progressofvlan](https://i.imgur.com/3ja9EMq.png)

4. __Enter the parent interface for the new VLAN__
  - Enter the __WAN__ interface name which is: `vtnet0`
5. Enter the __LAN__ interface
  - Enter `vtnet1`
6. Enter the __Optional 1 interface__
  - Enter `vtnet1.666`
7. Enter the __Optional 2 interface__
  - Enter `vtnet1.999`.
> If configured corretly, you should see a screen like this:
>![progressofvlan2](https://i.imgur.com/r76oCgo.png)
6. Do you want to proceed?
  - Enter `Y`
- Wait for additional setup steps to complete

> Special thanks to Ben Heater for these excellently defined steps in [his guide](https://benheater.com/proxmox-lab-pfsense-firewall/). Thanks, Ben!

### Configure LAN IP Range 10.0.0.1
- Enter `2` at the pfSense config screen to change the LAN IP range from the default.
![lanipconfig](https://i.imgur.com/bT0Vo81.png)
- Select the interface you wish to configure the IP range.
- Configure IPv4 address LAN interface via DHCP? (y/n)
    - Enter `n`
- Enter the new IPv4 address as: `10.0.0.1`
    - Enter `24`
    - Press `Enter` (for LAN)
- Configure IPv6 address LAN interface via DHCP6? (y/n)
    - Enter `n`
- Enter the new LAN IPv6 address. Press `Enter` for none.
- Do you want to enable the DHCP server on LAN? (y/n)
    - Enter `y`
    - Start of range: 10.0.0.11
    - End of range: 10.0.0.244
- Do you want to revert to HTTP?
    - Enter `n`
    - Press `Enter` to complete
- You should see an output that reflects the changes made that looks similar to this:
![iprangeconfigured](https://i.imgur.com/zDRamzn.png)

 ### Configure LAN IP Range 10.6.6.1
- Enter `2` at the pfSense config screen to change the LAN IP range from the default.
![lanipconfig](https://i.imgur.com/bT0Vo81.png)
- Select the interface you wish to configure the IP range.
- Configure IPv4 address LAN interface via DHCP? (y/n)
    - Enter `n`
- Enter the new IPv4 address as: `10.6.6.1`
    - Enter `24`
    - Press `Enter` (for LAN)
- Configure IPv6 address LAN interface via DHCP6? (y/n)
    - Enter `n`
- Enter the new LAN IPv6 address. Press `Enter` for none.
- Do you want to enable the DHCP server on LAN? (y/n)
    - Enter `y`
    - Start of range: 10.0.0.11
    - End of range: 10.0.0.244
- Do you want to revert to HTTP?
    - Enter `n`
    - Press `Enter` to complete

 ### Configure LAN IP Range 10.9.9.1
- Enter `2` at the pfSense config screen to change the LAN IP range from the default.
![lanipconfig](https://i.imgur.com/bT0Vo81.png)
- Select the interface you wish to configure the IP range.
- Configure IPv4 address LAN interface via DHCP? (y/n)
    - Enter `n`
- Enter the new IPv4 address as: `10.9.9.1`
    - Enter `24`
    - Press `Enter` (for LAN)
- Configure IPv6 address LAN interface via DHCP6? (y/n)
    - Enter `n`
- Enter the new LAN IPv6 address. Press `Enter` for none.
- Do you want to enable the DHCP server on LAN? (y/n)
    - Enter `y`
    - Start of range: 10.0.0.11
    - End of range: 10.0.0.244
- Do you want to revert to HTTP?
    - Enter `n`
    - Press `Enter` to complete

### pfSense Config Summary
After completing the intial pfSense configuration via CLI, you should see a result as shown in the screenshot below: 
![pfsenseconfigsummary](https://i.imgur.com/LUisItB.png)

### Troubleshooting pfSense CLI Config
If something goes wrong or the prompts do not match this guide, simply select option `4` at the main prompt screen to restore factory defaults and start over.

![troubleshootingpfsensecliconfig](https://i.imgur.com/bt1eFtr.png)

### Add Other VLANs

- Repeat the steps to create a new NIC (i.e `vmbr1`, VLAN tag `300`, VLAN tag `400`, etc.) in Proxmox
-  Repeat the Configure LAN IP Range for the new VLAN (i.e. "OPT3 > 10.3.3.11, OPT4 10.4.4.11, etc.)

### Enable web UI access to pfSense
- From the pfSense UI, enter `8` and type in `pfctl -d` to enable the pfSense web UI access needed to change other settings using the GUI instead of CLI.
![pfsensewebuienable](https://i.imgur.com/i68Kbtu.png)

> Note: A reboot will cause the web UI to revert to defaults and you'll have to repeat this step after a reboot to regain access to the web GUI again. Ben Heater explains on [his website](https://benheater.com/proxmox-lab-pfsense-firewall/): "pfSense is blocking WAN access to the web console. This is a good thing if your pfSense router is sitting at the edge of your network. You wouldn't want any body to be able to reach the login page of your home router from the internet. In reality, the IP address on the WAN port is a private IP address – which is not accessible from the Internet without some workarounds. So, _in this case, it's perfectly safe to open the WAN port inside our home network_."

### Access the web GUI
- Enter the IP address you assigned in the DHCP Server in the URL address (ex. http://192.168.1.24).
- If you encounter a screen in your browser that warns you about your connection not being private, ignore it and proceed (to unsafe), it's safe because it's your pfSense router on your network.
- Enter the default credentials: `admin` (username) and `pfsense` (password)
- Enter a host name: `<name>-<name>` (ex. pfsense-fw)
- Enter a domain name: `<name>.<name> (ex. pf.range)

![hostnamedomainname](https://i.imgur.com/7It6Wiz.png)

- If you use a DNS resolver you wish pfSense to use, check the `Override DNS`, if not, enter a DNS resolver of your choice. 
- NPT Server: set the __timezone__ and click next to accept the default. 
- Set the DHCP Hostname to the name you assigned and uncheck the `Block RFC1918 Private Networks` since we want to allow private IPs through the WAN, not block them.

![](https://i.imgur.com/WespfwB.png)

- Skip the LAN interfance config since we already configured it prior.
- __Important__: Change the default admin password!
- Click `Reload` and then `Finish` to complete the wizard.

> Note: You'll lose connection to the web GUI and you'll need to run `pfctl -d` in the VM console to access again.

### Enable web GUI access permantely - add WAN rule 
- Navigate to: __Firewall > Rules > WAN__
![wanruleedit1](https://i.imgur.com/7AIAM5h.png)

- Add the following firewall settings:

![wanruleedit2](https://i.imgur.com/uwcLZpt.png)

- __Save__ and __Apply Changes__

### Rename OP1 and OPT2
What you rename these to is up to you and depends on your purposes, but the goal of this guide is to A) create a separate network from prodcution/home (completed via `vmbr1`) and B) create two VLANs for security sandbox tools that is segragated from 10.0.0.1/24. Therefore, we will name the OPTs accordingly. See below:

- In the pfSense web GUI, navitage to: __Interfaces > Assignments__
- Click on the cooresponding interface and change the description as follows:
- Rename `OPT1` to `SEC_EGRESS`
- Rename `OPT2` to `SEC_ISOLATED`

> If you have other VLAN goals, then change or add new VLAN tags by creating a new `OVS IntPort`in the Proxmox network node. Revisit [NIC Settings](#apply-the-new-nic-settings) to extrapolate.

- `Save` each change and click `Apply Changes` after to submit the changes.

### Create an Alias for `RFC1918`
The alias serves as an alternate name for all private IPv4 addresses.
- __Firewall > Aliases > Add__
- Fill in the fields and add networks as follows:

![rfc1918networks](https://i.imgur.com/lUIkBeH.png)

> If you change the `Type` to `Host(s)` you can assign an static IP in  __Firewall > Aliases > Add__ for the DHCP server to assign.

### Create WAN firewall fules for security lab
> To allow the home network to reach the internal LAN, we need to set a `Pass` action for all addresses and protocols. This is necessary if we wish to `ssh` or create an `RDP` session to the Kali Linux VM on the `SEC_EGRESS` VLAN.

-  __Firewall > Rules > WAN > Add (down arrow)__
- Add the following configuration to your WAN rules:

![wanruleforlantalk](https://i.imgur.com/6kh0N0K.png)

- Click `Save`

### Allow WAN net to ping WAN address
-  __Firewall > Rules > WAN > Add (down arrow)__
![wanping](https://i.imgur.com/VO0Ed0d.png)

### Block ALL WAN access to `SEC_EGRESS` LAN
> It's paramount that we do not allow any packets to reach the LAN from the WAN. We only want egress, no ingress.

- Click `Save`

- __Firewall > Rules > WAN > Add (down arrow)__

![blockWANingressonSECegress](https://i.imgur.com/uaaLkis.png)

- And `Save`

### Block ALL WAN ingress to `SEC_ISOLATED`
> The same impiteous applies to `SEC_ISOLATED` -- we don't want the isolated VLAN to have internet ingress access.

__Firewall > Rules > WAN > Add (down arrow)__
- Add the following configuration to your WAN rules:

![blockWANingressonSECisolated](https://i.imgur.com/myC8lPG.png)

- Click `Save` on this new rule.

### WAN outcome summary
> The outcome of the rules shouel read as follows:

![idealWANruleoutcome](https://i.imgur.com/9F0H5NP.png)

> Leave the LAN firewall rules alone. It is good as-is.

### `SEC_EGRESS` rules - allow traffic to local gateway
> Because `RFC1918` will be blocked in future rules, we can allow the default gateway access to the Internet.

- __Firewall > Rules > `SEC_EGRESS` > Add (up arrow)__

![secegress1](https://i.imgur.com/cXq0Pb8.png)

- Add the following rules:

![](https://i.imgur.com/lZ80dKh.png)

- `Save`

### Create `Kali1` alias host
- Navitgate to __Firewall > Aliases > IP > Add__
- Enter the following details to create the `Kali1` alias:

![](https://i.imgur.com/60ylsXZ.png)

- `Save` the alias.
- `Apply Changes`

![applykali1changes](https://i.imgur.com/uGgrZio.png)

### Allow packets to Kali malware lab analysis

- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Create the following rules for for the `Kali1` VM to access the `SEC_EGRESS` VLAN:

![rulesforsecegresstoakali](https://i.imgur.com/tbZpJTz.png)

- `Save` the rules.
- If you get an error, check the name you created the for the Kali VM matches what you enterd.

![kalivmnotfound](https://i.imgur.com/b3u41WT.png)

### Allow packets to Internet (for non-private IPs)

- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Add the following rules (make sure to check the "invert match" box):

![invertmatchsecegresshost](https://i.imgur.com/BwNEBsN.png)

### Block everything else for `SEC_EGRESS`

- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Create the following rules:

![blockallthethingsnow](https://i.imgur.com/DHAqjAx.png)

### Check `SEC_EGRESS` final rule state
- Do your rules match the following?

![finalSECegressstate](https://i.imgur.com/WesC5Bh.png)

- If the rules match, click `Apply Changes`

### `SEC_ISOLATED` rule setup - allow to Kali1

- Navigate to the `SEC_ISOLATED` rules __Firewall > Rules > `SEC_ISOLATED`__

![SEC_ISOLATEDfirewallrules](https://i.imgur.com/m4SDiDH.png)

- Click __Add (UP arrow)__ and input the following rules:

![allowpacketstokali1](https://i.imgur.com/5d8vGDE.png)

- Click `Save`

### Block everything else on `SEC_ISOLATED`
- __Firewall > Rules > `SEC_EGRESS` > Add (DOWN arrow)__
- Now to block everything other than `Kali1`

![blockallthethingsnow2](https://i.imgur.com/w17b7bq.png)

> Rules have an order or execution based upon position. If a rule is above, it ignores all other rules BELOW it. In this case, because the block all rule is last, anything before it is allowed. But if I moved the `Kali1` allow rule BELOW the block all rule, `Kali1` couldn't communicate with the `SEC_ISOLATED` hosts.

### Check `SEC_ISOLATED` final rule state

![finalstateofSECisolatedrules](https://i.imgur.com/Q4buCSq.png)

> No "Block Bogon" found? That's becuase you have to check the box at the bottom of the page on __Interfaces > <Inteface Name> > Block Bogon Networks (checkbox)__

![blockthebogonnetwork](https://i.imgur.com/i4wRt4A.png)

- If the rules match, click `Apply Changes`

### Configure DNS Resolver Settings
- Nav to __Services > DNS Resolver__
- Check these two boxes for __DHCP Registration__ and __Static DHCP__

![dhcpregandstaticdhcp](https://i.imgur.com/2NibZ6d.png)

- Now, nav to __Advanced Settings__ and ensure that your settings match the following configuration:

![matchadvconfigopts](https://i.imgur.com/MKiW2Jw.png)

### How to add additional VLANs to pfSense
- Nav to: __Proxmox Node > Network__
- Add a new VLAN tag to `vmbr1` by: __Create > OVS IntPort__ and select `vmbr1` and enter a new VLAN tag and comment.
- Apply the by clicking `Apply Configuration` (button)
- Add the new VLAN to pfSense by accessing the pfSense web GUI (i.e. URL)
- Nav to: __Interfaces > Assignments > VLANs > Add__
- Fill in the VLAN Configuration with:
  - Parent Interface: `vtnet1`
  - VLAN Tag: `<your VLAN tag number>`
  - Descritpion (optional)" `<designation comment for your own organizational sanity>`
- Nav to: __Interface Assignments > Add__ (next to the newly added interface)
- Click `Save` and you should now see an `OPT#` interfance populate.

### Configure new VLAN interface
- Click on the new `OPT#` name to conifigure.
- Enter a description if you like.
- Set the IPv4 Configuration Type to `Static IPv4` (no need for IPv6, so leave as "none")
- For the Static IPv4 Configuration, enter the desired IP range youw want (i.e. 10.1.1.1/24 not 10.1.1.0/24).
- At the bottom of the __Interfaces > <Inteface Name>__ be sure to check the __Block Bogon Networks__ (checkbox).

### Configure DHCP server over new interface
- Nav to: __Services > DHCP Server > <interface_name> > Enable__
- Set the desire IP range (i.e. 10.1.1.11 - 10.1.1.244)
- Hit `Save` and `Apply Changes` if you are happy with it.

### pfSense Firewall Rules
- Nav to: __Firewall > Rules > <interface_name>__ to add new rules.

> There are not going to be any rules by default (except if you’re blocking bogon nets). Therefore, it's your call on how you configure the firewall rules. For assistance, check out:
> - [pfSense Firewall Rules That Make Sense](https://www.youtube.com/watch?v=3lJR67AMb9A)
> - [RaidOwl's YouTube video about configuring various firewall rules](https://youtu.be/rHE6MCL4Gz8?si=GSpluLibUKUrewvL&t=545)
> - [Speed Proxmox x pfSense VLAN Run Setup](https://www.youtube.com/watch?v=t7qt1wlS9uA)

Example Firewall Configs:
- The Basic VLAN
> This setup prevent VLANs from reaching anything outside of the subnet (i.e. block 192.168.1.48 from reaching 10.0.4.158), but still allows internet access. In order for this config to work, you must have already assigned the aliases for `RFC1918`; see [how to create  `RFC1918` alias here](#create-a-alias-for-RFC1918)

Fireway Rule Config Screenshots
![thebasicVLAN](https://i.imgur.com/0Ql2gOa.png)
![gamesinternetaccess](https://i.imgur.com/PECRy5O.png)
![RFC1918blockrule](https://i.imgur.com/XpFKiiJ.png)

- The WAN to VLAN
> This is the same as above EXCEPT, an additiona rule has been added to allow traffic __from__ WAN net __to__ a VLAN, but prevent VLAN traffic from reaching the WAN net. 
![thebasicVLAN](TBD)

- Add the same rules as above.
- Create from WAN to VLAN rule [WIP]
  - All WAN net to VLAN rules fail
  - VLAN to WAN net is sucessful, but it's not a two-way street (only the VLAN can ping the WAN net)
  - Perhaps a jump machine from LAN net to VLAN net is required for this config?

# pfSense CE 2.7.0
**“Unable to retrieve package information” or “Up to date” but not updating**

If you’re on **pfSense CE 2.7.0** and the **System > Update** page says *“Up to date”* (or fails with *“Unable to retrieve package information”*) even though a newer release (e.g., **2.7.2**) exists, the issue is often caused by **stale or mismatched certificate trust** between your firewall and the pfSense package servers.

This is a known quirk in 2.7.0 and can be fixed by **rehashing the certificates** so pkg can re-establish a trusted TLS connection to the update repository.

---

## **Quick Fix**

### **1. Open the pfSense console**
You can use:
- Physical/serial console
- SSH to the firewall
- **Diagnostics > Command Prompt** in the GUI

From the console menu, choose:
```text
Option 8) Shell
```

---

### **2. Refresh the certificate trust store**
Run:
```sh
certctl rehash
```

This re-reads all CA certificates on the system and updates the trust hash that `pkg` uses for secure repository connections.

---

### **3. Go back to the GUI**
Navigate to:
```text
System > Update
```
- Click **Update Settings**.
- Ensure the **Branch** is set to the latest (e.g., `Latest stable version (2.7.2-RELEASE)`).
- Click **Save**.

---

### **4. Re-check for updates**
After saving:
- Return to the **Update** tab.
- Click **Check for updates**.
- The correct latest version (e.g., 2.7.2) should now appear.

---

## **Why This Happens**
In pfSense CE 2.7.0, the local pkg client can silently fail TLS validation against the update repository if its CA trust hashes are stale. The GUI then incorrectly reports “up to date” or cannot retrieve package info. Running `certctl rehash` forces a refresh of the trust store so pkg can verify the repo server’s certificate chain.

---

## **Tip**
If you see this again:
1. Run:
   ```sh
   certctl rehash
   ```
2. Save your update branch in:
   ```text
   System > Update > Update Settings
   ```
3. Check for updates again.

This takes less than a minute and usually resolves the problem without touching DNS, repo configs, or reinstalling packages.

# HAProxy
**For multiple domains on one public IP**
**Goal:** Terminate **:80/:443** on pfSense with **HAProxy**, route by **hostname (SNI/Host header)** to different backends on internal VLANs, and automate **DNS + TLS** with **Cloudflare (DNS-01)**. Works for any number of FQDNs on a single WAN IPv4.

---

## Recommended architecture

- **Firewall/Router:** pfSense (single WAN IPv4)
- **Packages on pfSense:** `haproxy` (or `haproxy-devel`) and `acme`
- **Reverse proxy:** HAProxy listens on **80/443** and routes by **Host/SNI** to backends (e.g., `192.168.10.10`, `192.168.20.10`)
- **DNS & TLS:** Cloudflare DNS. Use **ACME DNS-01** with a **Cloudflare API Token** to issue/renew certs

**Example domains/backends**
- `cloudronA.domainA.com` → backend **A** at `192.168.10.10`
- `cloudronB.domainB.com` → backend **B** at `192.168.20.10`

---

## Prerequisites

1. **Move pfSense GUI off WAN:**
   - Ensure pfSense WebGUI is **not** exposed on WAN 443. If needed:
   ```text
   System > Advanced > Admin Access
   ```
   Set GUI to **LAN only** and/or change its port (e.g., 8443).

2. **Disable any old NAT port-forwards for 80/443** to internal servers (they’ll conflict with HAProxy binding to WAN).

3. **Cloudflare API token (per zone or multi-zone):**
   - Create a token with **Zone:DNS:Edit** (and **Zone:Zone:Read** recommended) for each domain.

---

## Step 1 — Install required packages

```text
System > Package Manager > Available Packages
```
- Install **haproxy** (or **haproxy-devel** if you want newer features).
- Install **acme**.

---

## Step 2 — ACME (Let’s Encrypt) via Cloudflare DNS-01

```text
Services > Acme Certificates
```

1. **Accounts**: Create an ACME account (start with **Let’s Encrypt Staging**, switch to **Production** once validated).
2. **Add Certificate** for each domain:
   - **Common Name / SANs**: e.g.
     - `cloudronA.domainA.com`
     - `cloudronB.domainB.com` (you can create two separate cert entries, one per domain; or one cert per FQDN)
   - **Challenge Type**: `DNS-01`
   - **DNS Service**: `Cloudflare`
   - **API Token**: Paste your Cloudflare token
3. **Actions list** (important):
   - Check **“Install certificate”** (so pfSense stores it locally)
   - Add action: **Restart HAProxy** after renewal
4. Click **Issue/Renew**. Confirm certs are issued and stored.

**Why DNS-01?** Works even when Cloudflare proxy (orange-cloud) is enabled; no need to open HTTP-01 paths to the origin.

---

## Step 3 — Define HAProxy Backends

```text
Services > HAProxy > Backends
```

Create a backend **per internal app**.

**Backend A (be_cloudronA)**
- **Name:** `be_cloudronA`
- **Mode:** `http` (if terminating TLS at HAProxy) or `tcp` (if you prefer TLS passthrough)
- **Servers:**
  - `server cloudronA 192.168.10.10:443 ssl verify none` *(if end-to-end TLS)*
  - or `server cloudronA 192.168.10.10:80` *(if HAProxy terminates TLS and forwards HTTP)*
- **Health Check:**
  - **Check type:** `HTTP` (if http mode)
  - **HTTP check method:** `GET /`
  - **Host header** (optional): `cloudronA.domainA.com`

**Backend B (be_cloudronB)**
- Same as above but with `192.168.20.10` and host `cloudronB.domainB.com`.

> If you terminate TLS at HAProxy, prefer **http mode** for L7 features (headers, redirects). If you need pure passthrough TLS (no offload), use **tcp mode** and SNI ACLs.

---

## Step 4 — Create HAProxy Frontends

```text
Services > HAProxy > Frontends
```

### A) HTTP Frontend (port 80)
- **Name:** `fe_http_80`
- **Listen address:** `WAN address` or `0.0.0.0`
- **Port:** `80`
- **Type/Mode:** `http`
- **Rules:** Add a rule to **redirect all HTTP to HTTPS**
  - **Action:** `http-request redirect scheme https code 301 if !{ ssl_fc }`

### B) HTTPS Frontend (port 443)
- **Name:** `fe_https_443`
- **Listen address:** `WAN address` or `0.0.0.0`
- **Port:** `443`
- **Type/Mode:** `http` (TLS termination)
- **SSL offloading:** **Enabled**
- **Certificates:** Attach both certs issued by ACME:
  - `cloudronA.domainA.com` cert
  - `cloudronB.domainB.com` cert  
  *(HAProxy will select the right one via SNI)*

**ACLs (Host-based)**
- `host_cloudronA` → **Condition:** `hdr(host) -i cloudronA.domainA.com`
- `host_cloudronB` → **Condition:** `hdr(host) -i cloudronB.domainB.com`

**Actions (Use backends)**
- `use_backend be_cloudronA if host_cloudronA`
- `use_backend be_cloudronB if host_cloudronB`

**Forward real client info to backends**
- Enable **X-Forwarded-For**:
  - Check **“Add X-Forwarded-For header”** (or add pass-thru below)
- **Advanced pass-thru** (optional, but recommended):
  - Add:
    ```text
    http-request set-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Real-IP %[src]
    # If behind Cloudflare proxy: prefer CF-Connecting-IP as client IP if present
    http-request set-header X-Forwarded-For %[req.hdr(CF-Connecting-IP)] if { req.hdr(CF-Connecting-IP) -m found }
    ```

> If you **prefer TLS passthrough** instead of offload, make the HTTPS frontend **tcp mode**, enable SNI ACLs, and use **“use_backend … if { req.ssl_sni -i cloudronA.domainA.com }”**. You won’t be able to add HTTP headers in tcp mode.

---

## Step 5 — Firewall cleanup & bindings

1. **Disable any NAT port forwards for 80/443** to internal servers.
2. HAProxy will bind directly to WAN on :80 and :443 — no extra firewall rule is needed for local services on pfSense, but verify:
   ```text
   Firewall > Rules > WAN
   ```
   Ensure **pass** to the firewall on ports 80/443 is not blocked by an overly strict policy.  
3. (Optional but recommended if using Cloudflare proxy) **Restrict WAN 80/443 to Cloudflare IPs only**:
   - Create `Cloudflare_IPv4/IPv6` aliases (URL Table or Network list).
   - Add **WAN** rules allowing **TCP 80/443** **only** from those aliases, **block** others.

---

## Step 6 — Cloudflare DNS

**A records**
- Create A records:
  - `cloudronA.domainA.com` → **your WAN IPv4**
  - `cloudronB.domainB.com` → **your WAN IPv4**
- **Proxy status (orange-cloud):**
  - With **DNS-01** ACME, you may leave them **proxied**.
  - Ensure HAProxy ciphers/TLS settings are compatible; Cloudflare will connect to your origin.

**API-driven (optional)**
- If you automate deployments, use the same API token to **upsert** A records via Cloudflare’s DNS API.

---

## Step 7 — Test

From a client on the internet (or using a Host header locally):

**HTTP → HTTPS redirect**
```bash
curl -I http://cloudronA.domainA.com
```
Expect: `301` redirect to `https://cloudronA.domainA.com/...`

**SNI/cert selection**
```bash
echo | openssl s_client -connect your.WAN.IP:443 -servername cloudronB.domainB.com 2>/dev/null | openssl x509 -noout -subject -issuer
```
Verify certificate CN/SAN matches `cloudronB.domainB.com`.

**Host routing**
```bash
curl -I -H "Host: cloudronB.domainB.com" http://your.WAN.IP
```
Expect a `301` to `https://cloudronB.domainB.com/...`

**Health checks**
- In pfSense:
  ```text
  Services > HAProxy > Stats / Real Time
  ```
  Confirm both backends are **UP**.

---

## Optional: TLS passthrough (no offload)

If you must keep TLS end-to-end and let backends present their own certs:

- **HTTPS Frontend:** `tcp` mode, **no SSL offloading**
- **SNI ACLs**:
  - ACL A: `{ req.ssl_sni -i cloudronA.domainA.com }`
  - ACL B: `{ req.ssl_sni -i cloudronB.domainB.com }`
- **use_backend**:
  - `use_backend be_cloudronA if { req.ssl_sni -i cloudronA.domainA.com }`
  - `use_backend be_cloudronB if { req.ssl_sni -i cloudronB.domainB.com }`
- **Backends:** likely `tcp` mode to :443 on each server
- **Note:** You cannot inject HTTP headers (XFF) in tcp mode. Apps must rely on `proxy_protocol` (if you enable it end-to-end) or accept Cloudflare/edge IPs.

---

## Hardening checklist

- **HTTP→HTTPS** redirect on :80
- Strong TLS ciphers on HAProxy (if terminating)
- **X-Forwarded-For/Proto** headers set (or CF-Connecting-IP pass-through)
- **WAN 80/443** restricted to **Cloudflare IPs** (optional, recommended when proxied)
- **No direct NAT** to backends for 80/443
- **HAProxy restart** tied to ACME renewals

---

## Troubleshooting

**Port conflict on 443**
- Move pfSense GUI off 443 (LAN-only or different port).

**“Site always hits the same backend”**
- Check **ACLs** (exact FQDN match, case-insensitive `-i`).
- Ensure **frontend mode** matches your plan (http vs tcp).

**ACME fails**
- Staging works but Production fails? Re-check Cloudflare token scopes and DNS-01 logs in ACME.
- If switching from HTTP-01, ensure no port 80 NAT conflicts.

**Real client IP missing**
- Behind Cloudflare, use `CF-Connecting-IP` header. Update HAProxy pass-thru to set `X-Forwarded-For` from it if present, and configure backends to trust forwarded headers.

---

## Minimal configuration summary

- **Packages:** HAProxy (+devel), ACME
- **ACME:** DNS-01 via Cloudflare API token; install certs; restart HAProxy on renew
- **HAProxy:**
  - **Frontend :80** → 301 redirect to HTTPS
  - **Frontend :443 (http mode)** with **SSL offload**, multiple certs attached
  - **ACLs by Host** → **use_backend** per FQDN
  - **Backends** to VLAN IPs with health checks
  - **X-Forwarded** headers enabled
- **DNS:** A records for each FQDN → same WAN IP (proxy optional)
- **Firewall:** No 80/443 NAT to backends; optional **Cloudflare IP** restriction on WAN

---

That’s it! You now have pfSense+HAProxy serving multiple domains over a single public IP with proper SNI routing, automated Cloudflare DNS and ACME certificates, and a clean path to scale additional hostnames/backends.




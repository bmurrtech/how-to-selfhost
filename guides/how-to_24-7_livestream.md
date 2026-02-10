> Note: WIP (untested)

![TICKR_example](./screenshots/TICKR_example.png)

### How to Create a Scrolling RSS Feed for Livestream Lower-third via RTSP
1. Create an Ubuntu Desktop container
2. [Install TICKR](https://open-tickr.net/help.php#building_from_source_howto)

> Tip: You can skip all the following steps by just installing TICKR on you desktop and creating an OBS screen-capture of just the TICKR scrolling headlines. But if you want to have a dedicated URL and use the OBS browser window video source feature, then continue.

4. Add desired RSS feeds to TICKR
5. [Install v4l2loopback](https://github.com/umlaeute/v4l2loopback/)
6. Setup VNC screencapture of TICKR
7. [Self-host a RTSP Stream](https://www.youtube.com/watch?v=0scjy6Zxzwc)
8. Stream VNC feed via RTSP to YouTube
9. Copy YouTube stream and paste the URL into OBS as a [Browser Source](https://i.imgur.com/Qze1D54.png) [how-to 2](https://medium.com/@khan_honney/webrtc-replay-from-obs-hosted-rtmp-stream-b995d168497); [how-to 3](https://resources.antmedia.io/docs/simulcasting-to-social-media-channels)

### Create a Live VNC Terminal Stock Ticker, Watcher for Livestream
1. Create an Ubuntu Server
2. Install Docker
3. [Install Ticker by achannarasappa](https://github.com/achannarasappa/ticker)
4. Setup VNC video feed
5. [Self-host a RTSP Stream](https://www.youtube.com/watch?v=0scjy6Zxzwc)
6. Stream terminal ticker from desktop to [YouTube using Ant Media Server](https://resources.antmedia.io/docs/simulcasting-to-social-media-channels)
7. Copy YouTube stream and paste the URL into OBS as a [Browser Source](https://i.imgur.com/Qze1D54.png)

### Ant Media Server

#### About Ant Media Server
> Only works with Ubuntu LTS (server). Will not install on Ubuntu Desktop.

- Ant Media Server is a streaming engine software that provides adaptive, ultra low latency streaming by using WebRTC technology.
- The community edition is free, but has [limited features](https://github.com/ant-media/Ant-Media-Server/wiki/Introduction), such as:
  - 8-12 second latency
  - No Kubernetes scaling
  - No secure streaming (no https)
  - No adaptive bitrate
- This will not be a problem for the simple purpose of a scrolling RSS feed and stock ticker watcher. Besides, who has $100/m for the enterprise services? 

#### Ant Media Docker Install
- See [Ant Media's Docker documentation here](https://resources.antmedia.io/docs/docker-and-docker-compose-installation) for more details.

#### Ant Media Install (No Docker)

> Note: Ant Media Server is officially supported on Ubuntu 18.04, but auxilary scripts are provided for Ubuntu 20.04 and CentOS 8. If you are running Ubuntu 18.04, you can [download the latest, stable community edition](https://github.com/ant-media/Ant-Media-Server/releases) zip file (or get the enterprise ver. if you got cash to burn). Otherwise, check the versions to see if it supports other Linux distros.

- First, SSH into your server and `cd` to your user root folder such as:

```
cd \home\admin
```

- You an type `wget` and the URL to the download you want to download it to the server. For Ubuntu 20.04, you need a supported Ant Media Release (ver. 2.3.3.1 / 2.4.2 / 2.5.3 tested):

__Ver. 2.5.3__ (Tested) 
```
wget https://github.com/ant-media/Ant-Media-Server/releases/download/ams-v2.5.3/ant-media-server-community-2.5.3.zip
```

- Next, download the Ant Media Script installer from the official website, give the bash script permission to execute while you are at it:

```
wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh && chmod 755 install_ant-media-server.sh
```

> Note: You can check the directory with the `ls` command to see if the installer and zip file are there before continuing.

- And now, you can run the installer bash file, and you should see the terminal run through the installation process. If not, you may need to increase the disk size (if it is a VM) to accomodate the installer file expansion.

```
sudo ./install_ant-media-server.sh -i [ANT_MEDIA_SERVER_INSTALLATION_FILE]
```

> Tip: `TAB` will auto-complete the name of the file in the directory. So, you could type, `sudo ./install_ant-media-server.sh -i ant-media[TAB]` and Linux will auto-fill the rest.

- Check if the Ant Media Server is running via:

```
sudo service antmedia status
```
- If you see a green __active (running)__ indicator, then the server is working. If not, check the version you downloaded and your Ubuntu version to ensure they are compatible.
- We are not finished yet, we still need to configure the firewall. Run the following:

Tip: To exit this status check hit: `CTRL + C` twice.

```
sudo systemctl status antmedia.service
```

- Hit: `CTRL + C` twice again, then enter the following:

```
sudo ufw allow 1935
sudo ufw allow 5080
sudo ufw allow 5443
sudo ufw allow 5554
```

- You can stop and start the service anytime:

```
sudo service antmedia stop
sudo service antmedia start
```

#### Install SSL for Ant Media Server
- Please make sure that your server instance has __Public IP__ address and a __domain__ is assigned to its Public IP address. Then go to the folder where Ant Media Server is installed.

Default directory is `/usr/local/antmedia `

```
cd /usr/local/antmedia
```

To enable SSL, please run the command

```
sudo ./enable_ssl.sh -d {DOMAIN_NAME}
```

Please don't forget to replace {DOMAIN_NAME} with your domain name. e.g., abc.shopping.com

For detailed information about SSL, follow SSL Setup

#### Accessing Ant Media Server Web Panel
- Once all has been configured, you can access the Ant Media web UI using `https://your-ip-adddress:5080`
- If you enabled SSL, open your browser and type the server URL https://Domain_Name:5443 to go to the web panel.
- If SSL is not enabled, the web panel can be accessed through http://Server_IP_Address:5080
- If you're having difficulty in accessing the web panel, there maybe some firewall that blocks accessing the port 5080/5443

#### Reset Username Password

- Go to the installation directory of Ant Media Server.

```
cd /usr/local/antmedia
```

- Stop the Ant Media Service:

```
sudo service antmedia stop
```

- Remove "server.db" file.

```
sudo rm server.db
```

- Restart Ant Media Server.

```
sudo service antmedia restart
```

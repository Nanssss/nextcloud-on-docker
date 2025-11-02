# nextcloud-on-docker

You can use this guide to setup a Nextcloud install on a Docker container, using Nginx, Certbot, Redis. This was done on my home server, running Ubuntu Server (22.04.4 LTS - Jammy Jellyfish).

- You first have to follow the [Setup](#setup-and-docker-installation) step to install everything required.
- Then, you can blindly follow the [Configuration](#configuration) step to set everything up. Here, you will only **have to replace `to_fill` fields with your actual data**, you can then use `<CTRL>+F` to find all of these fields.

    All these `to_fill` fields are listed below:
    - `nextcloud/db.env`: 2 fields; your **db root password** and **password**
    - `nextcloud/nextcloud.env`: 1 field; your **domain name** 
    - `nextcloud/redis.env`: 2 fields; your **redis host password** and **host port**
    - `nginx_conf/certbot_base.conf`: 1 field; your **domain name**
    - `nginx_conf/nextcloud.conf`: 5 fields; your **server name** (domain name), your **path to _nextcloud-on-docker/nextcloud/html directory_**, your **ssl certificate** and **key**, your **domain name**
    - `docker-compose.yml`: 2 fields; your **redis password** and **port**

**IMPORTANT NOTE: After you filled all required fields, your local repo will include sensitive informations (db password, redis password...), so make sure to keep your repo private.**

- You can finish the install with [Docker-compose file and commands](#docker-compose-file-and-commands) and [Nextcloud start-up](#nextcloud-start-up)
- Some important security topics are discussed in [Security](#security), don't understimate this section!


# Table of Contents
- [nextcloud-on-docker](#nextcloud-on-docker)
- [Table of Contents](#table-of-contents)
- [Setup and Docker installation](#setup-and-docker-installation)
  - [Set up a static IP address](#set-up-a-static-ip-address)
  - [Network configuration](#network-configuration)
  - [Docker installation](#docker-installation)
  - [Docker-compose installation](#docker-compose-installation)
  - [Mount an external drive to your server](#mount-an-external-drive-to-your-server)
- [Configuration](#configuration)
  - [Docker environment configuration](#docker-environment-configuration)
  - [Nginx configuration](#nginx-configuration)
  - [Redis configuration](#redis-configuration)
  - [Nextcloud configuration](#nextcloud-configuration)
- [Docker-compose file and commands](#docker-compose-file-and-commands)
- [Nextcloud start-up](#nextcloud-start-up)
- [Automatic Sync](#automatic-sync)
- [Security](#security)
  - [sshd configuration](#sshd-configuration)
  - [Fail2ban](#fail2ban)
  - [Set-up UFW (Uncomplicated FireWall)](#set-up-ufw-uncomplicated-firewall)
  - [Set-up 2FA](#set-up-2fa)

----

# Setup and Docker installation

These are the preliminary steps before cloning this repository in step [Configuration](#configuration).

## Set up a static IP address

1. Identify network interface:
```bash
ip addr
```
Look for your active network interface (e.g., eth0, enp0s3, or wlan0). Note its name.

2. Edit the Network Configuration File
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

3. Configure Static IP Address
```yaml
network:
  ethernets:
    enp1s0:
      dhcp4: no
      dhcp6: no
      addresses:
        - your_ip_address/24 # Fill here with your IP address
      nameservers:
        addresses: [192.168.1.1] # Your nameserver address, it is usually 192.168.1.1
      routes:
        - to: default
          via: 192.168.1.1 # Your nameserver address, it is usually 192.168.1.1
  version: 2
```

## Network configuration

You have to enable DMZ for your server in your livebox administration panel.
After that, set up the linux firewall with:
```bash
sudo ufw allow http
sudo ufw allow https
sudo ufw allow ssh
sudo ufw enable
```

## Docker installation

1. Update existing packages:
```bash
sudo apt update
```

2. Install dependencies to allow apt to use a repository over HTTPS:
```bash
sudo apt install apt-transport-https ca-certificates curl software-properties-common

```

3. Add the official Docker GPG key:
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

```

4. Configure the Docker stable repository:
```bash
echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

```

5. Update packages again and install Docker:
```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io
```

6. Add your user to the docker group to run Docker commands without sudo:
```bash
sudo usermod -aG docker $USER
```

## Docker-compose installation

1. Download the current stable version of Docker Compose:
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

2. Give execution permissions to the Docker Compose binary:
```bash
sudo chmod +x /usr/local/bin/docker-compose
```

3. Verify the installation:
```bash
docker-compose --version
```

## Mount an external drive to your server

First, install ntfs-3g to be able to work with ntfs partition:
```bash
sudo apt install ntfs-3g
```

Next, get your drive partition name with `sudo fdisk -l`.

Create a folder where the disk will be mounted:
```bash
mkdir /mnt/EXT_HDD
```

You can now mount the ntfs partition by doing:
```bash
sudo mount -t ntfs-3g -o uid=33,gid=33,umask=0007 /dev/sdb1 /mnt/EXT_HDD/
```

To get your disk UUID, do:
```bash
sudo fdisk -l
```
followed by:
```bash
ls -l /dev/disk/by-uuid/
```

If you want, you can automate the mounting at startup by editing the **/etc/fstab** file:
```bash
UUID=your_disk_UUID   /mnt/EXT_HDD    ntfs-3g auto,uid=33,gid=33,umask=0007     0       0
```

(the umask is substracted to the normal chmod rights, so here with 0007 we get 770 rights)

You can now test by running `sudo mount -a` and trying to create and read a file to ensure that you have the right permissions.

Once it is ok, create a folder for your data, here `/nextcloud/data`:
```bash
mkdir /mnt/EXT_HDD/nextcloud/data
```

----

# Configuration

Now you can pull this repository.

## Docker environment configuration

**IMPORTANT: Replace `to_fill` fields in `nextcloud/*.env`, `nginx_conf/certbot_base.conf`, `nginx_conf/certbot_base.conf`, and `docker-compose.yml` (redis part at the bottom) with the right informations.**

Note: The environment file is only used at first run of the image, so if you want to do latter modifications, you need to directly edit the config.php file (mounted on the host).

## Nginx configuration

Firstly, install and enable nginx on your host with:
```bash
sudo apt install nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

Secondly, install certbot for nginx:
```bash
sudo apt install certbot python3-certbot-nginx
```

Now, you have to enable ssl, to do it, first put the certbot_base.conf file in nginx by doing:
```bash
cd /etc/nginx/conf.d
sudo ln -s /path/to/nextcloud-on-docker/nginx_conf/certbot.conf ./ # Fill with the right path
sudo nginx -s reload
```

Next, set up ssl certificates by running the command 
```bash
sudo certbot --nginx -d your.domain.com # Replace with your domain
sudo rm /etc/nginx/conf.d/certbot.conf
```

Now, edit the  `/etc/nginx/nginx.conf` file to comment the lines added by server about the servers for you domain.

Now, it's time to add the nextcloud nginx configuration file to `/etc/nginx/conf.d`.
```bash
sudo ln -s /path/to/nextcloud-on-docker/nginx_conf/nextcloud.conf /etc/nginx/conf.d/
```

Nginx is set up, run:
```bash
sudo nginx -s reload
```

To set up automatic certificate renewal: 
```bash
sudo certbot renew --dry-run
```

## Redis configuration

You need to enable memory overcommit for redis, to do so:
```bash
echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf
```

Also, in the `redis.env` file, the **REDIS_HOST** has to be the **container's name**.

## Nextcloud configuration

Be aware that OVERWRITEPROTOCOL and NEXTCLOUD_TRUSTED_DOMAINS have been set correctly. Otherwise you have to directly modify them in the config.php file mounted on the host. You can also verify "overwrite.cli.url".

Same, be aware that redis have been set like this in the config.php file:
```php
'memcache.local' => '\\OC\\Memcache\\ACPu',
  'filelocking.enabled' => true,
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'password' => 'your_password',
  'redis' => [
      'host' => 'redis',
      'port' => your_port_without_quotes,
      'timeout' => 0,
  ],
```

----

# Docker-compose file and commands

docker-compose syntax:

- **ports**: "local (host, after passing through reverse proxy):docker (container)"
- **volumes**: host_path:container_path
If you put a local host_path with **./**, it will directly mount the container path into this path, otherwise it will be in a docker volume.

----

You can **run** your container with 
```bash
docker-compose up -d
```
and **stop** it with
```bash
docker-compose down
```

You can **see the running containers** with the command 
```bash
docker ps
```

You can **see the logs** with the command
```bash
docker logs <container_name>
```

You can **execute a command** by running
```bash
docker exec <container_name> <command>
```

You can **open a bash terminal** by running
```bash
docker exec -it <container_name> /bin/bash
```

You can **recreate** and **rebuild** an image by running
```bash
docker-compose up -d --force-recreate --build
```

You can **delete containers, networks, images, and volumes** by doing
```bash
docker system prune -a
```

You can see the volumes and networks with ```docker volume ls``` and ```docker network ls```, and remove them with ```docker volume rm <id>``` and ```docker network rm <id>```

You can see the final docker config generated with
```bash
docker-compose config
```

----

# Nextcloud start-up

Now your nextcloud should be accessible from the url *your.domain.com*.

You can install it by creating an admin account, with the database data from the nextcloud/db.env file. The database host should be the name of your database container, ie. mariadb.

You can define a default phone region, here France, by doing:
```bash
docker exec --user www-data -it <nextcloud_container> php occ config:system:set default_phone_region --value=FR
```
If missing, you can add the php-bz2 module by doing:
```bash
docker exec -it <nextcloud_container> /bin/bash
apt-get update && apt-get install -y libbz2-dev && docker-php-ext-install bz2
```

----

# Automatic Sync

After start-up, you can install the smartphone app and .exe on Windows. Whis them, it is possible to set-up automatic folder sync!

----

# Security

The server security is a very important point, setting-up fail2ban protected my server against a bruteforce attack. So never underestimate your security.

## sshd configuration

Some parameters in the sshd configuration can easily increase your server security.

In `/etc/ssh/sshdc_config`:
- Modify the default ssh port: `Port ******`, *you can then connect by using the command `ssh -p <port> user@server` and by modifying the sshconfig in VSCode
- Allow Pubkey authentication: `PubkeyAuthentication yes`
- Disable password authentication: `PasswordAuthentication no`
- Allow only specific users: `AllowUsers user1 user2`
- Forbid users: `DenyUsers root`

## Fail2ban

For security purposes, it's recommended to use fail2ban. If you configured ssh and nginx normally, it will automatically monitor the logs.
 To do so:
```bash
sudo apt update
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

Search for the **sshd** part and configure it:
```bash
[sshd]

enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 5
bantime = 86400 # one day
findtime = 600 # 10 minutes between 2 failed retries
```

Search for the **nginx-http-auth** part and simply add 
```bash
[nginx-http-auth]

enabled = true
port    = http,https
logpath = %(nginx_error_log)s
maxretry = 5
```

Next, you just need to enable fail2ban, restart the service and check the jails:
```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status
```

You can check the status of each jail with ```sudo fail2ban status <jail>```

The logs are placed here: `/var/log/fail2ban.log`

## Set-up UFW (Uncomplicated FireWall)

Default rules apply to all ports. Don't use it for specific ports.

```bash
sudo ufw enable
sudo ufw allow 80/tcp # allow http port
sudo ufw allow 443/tcp # allow https port
sudo ufw allow <ssh_port>/tcp # allow ssh port
sudo ufw default deny incoming # deny all other incoming traffic
sudo ufw default allow outgoing # allow all outgoing traffic
sudo systemctl restart ufw
```

- Check the rules: `sudo ufw status numbered`
- Delete a rule: `sudo ufw delete <rule_number>`
- Block specific ports: `sudo ufw deny 22`

- Allow only specific IP to access to port 22, and block other ones only on port 22:
```bash
sudo ufw allow from <trusted_IP> to any port 22
sudo ufw deny 22
```

- Allow only specific IP to access to every port:
```bash
sudo ufw allow from <trusted_IP>
sudo ufw default deny incoming
```

- Reset to a clean configuration: `sudo ufw reset`

## Set-up 2FA

If you want even more security, you can set-up 2FA with Google Authenticator for example.

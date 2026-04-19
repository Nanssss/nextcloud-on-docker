# nextcloud-on-docker

You can use this guide to setup Nextcloud on a Docker container, using Nginx, Certbot, Redis and MariaDB. This was done on my home server, running Ubuntu Server.

- You first have to follow the [Setup](#setup-and-docker-installation) step to install everything required.
- Then, you can blindly follow the [Configuration](#configuration) step to set everything up. Here, you will only **have to replace `to_fill` fields with your actual data**, you can then use `<CTRL>+F` to find all of these fields.

> [!IMPORTANT]
> **Don't use `$` character in your `.env` files**, as it is interpreted (you can escape it with `$$` but it's safer just not to use them).

    All these `to_fill` fields are listed below:
    - `nextcloud/db.env`: 2 fields; your **db root password** and **password**
    - `nextcloud/nextcloud.env`: 1 field; your **domain name** 
    - `nextcloud/redis.env`: 2 fields; your **redis host password** and **host port**
    - `nginx_conf/certbot_base.conf`: 1 field; your **domain name**
    - `nginx_conf/nextcloud.conf`: 5 fields; your **server name** (domain name), your **path to _nextcloud-on-docker/nextcloud/html directory_**, your **ssl certificate** and **key**, your **domain name**
    - `docker-compose.yml`: 2 fields; your **redis password** and **port**

> [!IMPORTANT]
> **After you filled all required fields, your local repo will include sensitive informations (db password, redis password...), so make sure to keep your repo private.**

- You can finish the install with [Docker-compose file and commands](#docker-compose-file-and-commands) and [Nextcloud start-up](#nextcloud-start-up)
- Some important security topics are discussed in [Security](#security), don't understimate this section!


# Table of Contents
- [Improvements](#improvements)
- [Setup and Docker installation](#setup-and-docker-installation)
  - [Set up a static IP address](#set-up-a-static-ip-address)
  - [Network configuration](#network-configuration)
  - [Docker \& Docker Compose installation](#docker--docker-compose-installation)
  - [Mount an external drive to your server](#mount-an-external-drive-to-your-server)
    - [Recommended format: ext4](#recommended-format-ext4)
    - [Finish your drive setup](#finish-your-drive-setup)
- [Configuration](#configuration)
  - [Docker environment configuration](#docker-environment-configuration)
  - [Nginx configuration](#nginx-configuration)
  - [Redis configuration](#redis-configuration)
- [Docker-compose file and commands](#docker-compose-file-and-commands)
- [Nextcloud start-up](#nextcloud-start-up)
  - [Nextcloud configuration](#nextcloud-configuration)
  - [Nextcloud backup service](#nextcloud-backup-service)
  - [How to restore a backup](#how-to-restore-a-backup)
- [Automatic Sync](#automatic-sync)
- [Security](#security)
  - [sshd configuration](#sshd-configuration)
  - [Fail2ban](#fail2ban)
  - [Set-up UFW (Uncomplicated FireWall)](#set-up-ufw-uncomplicated-firewall)
  - [Set-up 2FA](#set-up-2fa)
    - [On Nextcloud](#on-nextcloud)
    - [On your server](#on-your-server)

----

# Improvements

*Before starting, here is a little section about what could be improved in this guide.*

- Remove redis password from `docker-compose.yml`. Maybe use redis.conf file to pass it.
- Add a `./res/inputs` file and parse it with a script (that also add inputs to gitignore) to create `.env` files, and replace beacons in corresponding files.
Add inputs and .env files to gitignore to not push them on git.

----

# Setup and Docker installation

These are the preliminary steps before cloning this repository in step [Configuration](#configuration).

## Set up a static IP address

The best way to do that is usually on your **Internet Provider administration panel**. Look for something like **DHCP**, and make your local ip address static.

> Otherwise, you can also use network configuration tools, such as *NetworkManager*, *Netplan*, *dhcpcd*... If you prefer this option, I let you do your own researches according to the tool you're using.

## Network configuration

On your Internet Provider administration panel, **open ports 80 (http) and 443 (https)** and route them to your server local IP address.
After that, set up the linux firewall with:
```bash
sudo ufw allow http
sudo ufw allow https
sudo ufw allow ssh
sudo ufw enable
```

From here, ufw will be enabled at boot.

## Docker & Docker Compose installation

The Docker installation procedure changes according to the distribution you are running.

Also, you can choose to either:
- [Install Docker Desktop](https://docs.docker.com/desktop/) which embeds Docker Engine and Docker Compose.
- [Install Docker Engine](https://docs.docker.com/engine/install) and then [install the Docker Compose Linux Plugin](https://docs.docker.com/compose/install/linux/#install-using-the-repository). I personally chose this method.

After that, you can add your user to the docker group to be able to run Docker commands without sudo:
```bash
sudo usermod -aG docker $USER
```

You can verify everything was correctly installed with:
```bash
docker --version
docker-compose --version
```

## Mount an external drive to your server

### Recommended format: ext4

> [!NOTE]
> <details>
> <summary><em>If you prefer to use NTFS for Windows Compatibility of your drive</em></summary>
> 
> First, install ntfs-3g to be able to work with ntfs partition:
> ```bash
> sudo apt install ntfs-3g
> ```
> 
> Next, get your drive partition name with `sudo fdisk -l`.
> 
> Create a folder where the disk will be mounted:
> ```bash
> mkdir /mnt/my_drive
> ```
> 
> You can now mount the ntfs partition by doing:
> ```bash
> sudo mount -t ntfs-3g -o uid=33,gid=33,umask=0007 /dev/sdb1 /mnt/my_drive/
> ```
> 
> To get your disk UUID, do:
> ```bash
> ls -l /dev/disk/by-uuid/
> ```
> 
> If you want, you can automate the mounting at startup by editing the **/etc/fstab** file:
> ```bash
> UUID=your_disk_UUID   /mnt/my_drive    ntfs-3g auto,uid=33,gid=33,umask=0007     0       0
> ```
> 
> (the umask is substracted to the normal chmod rights, so here with 0007 we get 770 rights)
> 
> You can now test by running `sudo mount -a` and trying to create and read a file to ensure that you have the right permissions.
> 
> --> If you followed this method, you can jump to [Finish your drive setup](#finish-your-drive-setup).
> 
> ----
> </details>

Get your drive partition name with `sudo fdisk -l` (in my case it was `/dev/sdb1`).

Create a folder where the disk will be mounted:
```bash
mkdir /mnt/my_drive
```

You can now mount the ext4 partition by doing:
```bash
sudo mount -t ext4 /dev/sdb1 /mnt/my_drive/
```

To get your disk UUID, do:
```bash
ls -l /dev/disk/by-uuid/
```

If you want, you can automate the mounting at startup by editing the **/etc/fstab** file:
```bash
UUID=your_disk_UUID   /mnt/my_drive    ext4     defaults     0       2
```

You can now test by running `sudo mount -a` and trying to create and read a file to ensure that you have the right permissions.


### Finish your drive setup

Once it is ok, create a folder for your data:
```bash
mkdir /mnt/my_drive/nextcloud/data
```

----

# Configuration

Now you can pull this repository.

## Docker environment configuration

> [!IMPORTANT]
> **Replace `to_fill` fields in `nextcloud/*.env`, `nginx_conf/certbot_base.conf`, `nginx_conf/certbot_base.conf`, and `docker-compose.yml` (redis part at the bottom) with the right informations (see [introduction](#nextcloud-on-docker)).**

> [!IMPORTANT]
> Before the first boot of your containers, please **check the [*mariadb* version compatibility](https://docs.nextcloud.com/server/stable/admin_manual/installation/system_requirements.html) with the Nextcloud version you are using**, and specify it in the `docker-compose.yml` file.

> [!NOTE]
> The environment file is only used at first run of the image, so if you want to do latter modifications, you need to directly edit the config.php file (mounted on the host).

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
sudo ln -s /path/to/nextcloud-on-docker/res/certbot.conf ./ # Fill with the right path
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
sudo ln -s /path/to/nextcloud-on-docker/res/nextcloud.conf /etc/nginx/conf.d/
```

Modify `nextcloud.conf` to put the **real ssl keys** (you can see them in the nginx.conf file) and **your domain**.

Nginx is set up, run:
```bash
sudo nginx -s reload
```

> [!IMPORTANT]
> If you're playing with NGINX and it does not work, remind yourself to delete your navigator cache when requesting your server. Sometimes everything is fine and it's just your phone that is not really requesting the server!

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

----

# Docker-compose file and commands

`docker-compose.yml` syntax:

- **ports**: "local*(host, after passing through reverse proxy)*:docker*(container)*"
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

## Nextcloud configuration

**After your first boot of the containers**, be aware that OVERWRITEPROTOCOL and NEXTCLOUD_TRUSTED_DOMAINS have been set correctly. Otherwise you have to directly modify them in the config.php file mounted on the host. You can also verify "overwrite.cli.url".

Also, be aware that redis have been set like this in the config.php file (you may not see `filelocker.enabled`, but that's fine):
```php
'memcache.local' => '\\OC\\Memcache\\ACPu',
  'filelocking.enabled' => true,
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'password' => 'your_password',
  'redis' => [
      'host' => 'redis',
      'port' => 6379,
      'timeout' => 0,
  ],
```

I advise you to add you email to Nextcloud, so that it can inform you of important events. To do so, connect with your admin account and go in *Administration -> Base Parameters -> Email Server*.

Here is the config you can use for GMAIL:
```
Sending mode: SMTP
Encryption: None/STARTTLS
E-mail: <your_mail>    (@domain keep empty)
Host: smtp.gmail.com    Port: 587
Request authentication: Yes
Login: <your_mail>
Password: <your_application_password(see next)>
```

> [!IMPORTANT]
> The password you must use just above is **NOT** your GMAIL password. It's an application password you must generate by following this procedure:
> - Go to *Manage my Google Account -> Security and Connexion -> Two-factor authentication (must be enabled) -> Application password*, and add a new one here. Don't forget to note this password as you won't be able to see it again. This is the password you must input in the above password field.

If you have a warning about "AppAPI", you can simply disable the corresponding Nextcloud app.

To finish, you can add your custom php config file to fix some warnings:
```bash
sudo cp ./res/custom.config.php ./nextcloud/html/config/
# The pointed file
sudo chown 33:33 /home/nans/docker/nextcloud/nextcloud/html/config/custom.config.php
# The symlink itself
sudo chown -h 33:33 /home/nans/docker/nextcloud/nextcloud/html/config/custom.config.php
```

> [!NOTE]
> *This is now already done with the custom php script, letting it here just in case.*
> You can define a default phone region by doing:
> ```bash
> docker exec --user www-data -it <nextcloud_container> php occ config:system:set default_phone_region --value=FR
> ```

If missing, you can add the php-bz2 module by doing:
```bash
docker exec -it <nextcloud_container> /bin/bash
apt-get update && apt-get install -y libbz2-dev && docker-php-ext-install bz2
```

## Nextcloud backup service

> [!NOTE]
> In these scripts, I am using RTC to setup server maintenance.
> Your pc should support RTC alarm, you can first verify you have such an option in your BIOS setup and enable id.
> Next, on software side, you can check if you have rtcwake by doing `which rtcwake`. If not, install il.

A backup script is provided in this repo, to use it:
1. Fill `scripts/setup_backup.env` file with the correct data.
2. Run this to create and enable the service.
```bash
cd ./scripts
./setup_backup.sh
```

From now on, the Nextcloud maintenance service runs automatically on RTC wakeup, performs backup and maintenance, then shuts down the server.

## How to restore a backup

1. Enabled maintenance mode
```
docker exec -u www-data nextcloud-nextcloud-1 php occ maintenance:mode --on
```

2. Restore database
```
docker exec -i nextcloud-mariadb-1 mariadb -u root -p"$(docker exec nextcloud-mariadb-1 printenv MYSQL_ROOT_PASSWORD)" < /mnt/toshiba-hdd/backups/20260418/db.sql
```

3. Restore files
```
rsync -av /mnt/toshiba-hdd/backups/20260418/data/ /mnt/toshiba-hdd/nextcloud/data/
```

4. Fix permissions
```
sudo chown -R 33:33 /mnt/toshiba-hdd/nextcloud/data/
```

5. Scan files
```
docker exec -u www-data nextcloud-nextcloud-1 php occ files:scan --all
```

6. Disable maintenance mode
```
docker exec -u www-data nextcloud-nextcloud-1 php occ maintenance:mode --off
```

# Automatic Sync

After start-up, you can install the smartphone app and .exe on Windows. Whis them, it is possible to set-up automatic folder sync!

# Security

The server security is a very important point, setting-up fail2ban protected my server against a bruteforce attack. So never underestimate your security.

## sshd configuration

Some parameters in the sshd configuration can easily increase your server security.

In `/etc/ssh/sshdc_config`:
- Modify the default ssh port: `Port ******`, *you can then connect by using the command `ssh -p <port> user@server` and by modifying the sshconfig in VSCode.
- Allow Pubkey authentication.
- Disable password authentication.
- Allow only specific users.
- Disable root authentication.
- Some other stuff.

```
Port 2222
PubkeyAuthentication yes
PasswordAuthentication no
AllowUsers user1 user2
PermitRootLogin no
ChallengeResponseAuthentication no
UsePAM no
```

Restart ssh service by doing `sudo service ssh restart` or `sudo service sshd restart`.

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

### On Nextcloud

You can easily add 2FA on your nextcloud-server. To do this, connect with your admin account, go in Applications, and look for "two-factor". You'll see several ways of adding 2FA, I personnaly prefer to use authenticator methods such as Google Authenticator, and thus used "Two-Factor TOTP Provider" application.

Then, you can force 2FA for every user by going to *Administration -> Security -> Impose 2FA*.

You can also use the following commands:
```bash
# Enable 2FA
docker exec -u www-data nextcloud-nextcloud-1 php occ twofactorauth:enforce --on

# Disable 2FA
docker exec -u www-data nextcloud-nextcloud-1 php occ twofactorauth:disable --all <username>
```

### On your server

If you want even more security, you can set-up 2FA with Google Authenticator for example.

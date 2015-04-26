# seafile-opensource-all-in-one-installer
This script installs the Seafile Open Source Server on a Debian Wheezy (64bit). It's meant to run on a system with minimal pre-installation. No desktop environment or other weird stuff like hosting panels (Plesk, ISPConfig, etc.)...

Never run the script on a production server. It's more or less a one trick pony and can seriously damage productions systems. So run it only one time and delete it afterwards. 

You will have to handle Seafile updates/upgrades manually after the initial installation. Consult http://manual.seafile.com/deploy/upgrade.html on how to upgrade Seafile. 

## How to run
<pre>
cd /tmp
wget https://raw.githubusercontent.com/alexanderjackson/seafile-opensource-all-in-one-installer/master/aio_seafile-server_4.1.2_x86-64.sh
bash aio_seafile-server_4.1.2_x86-64.sh
</pre>


## The installer does
1. Update and upgrade Debian
2. Install NGINX from http://nginx.org/packages/mainline/debian/ 
3. Install MariaDB from http://mirror.netcologne.de/mariadb/repo/10.0/debian
4. Create Seafile init skript and add it to system start-up
5. Create unprivilieged system user "Seafile" with home directory "/opt/seafile"
6. Create "seafile" database user and actual Seafile databases (DB-Credentials in ~/.my.cnf)
7. Create various Seafile files
8. Enable SeafDAV, Memcached and MySQL/MariaDB
9. Setup Seafile to listen to IP (hostname -i) instead of DNS (Switch this to DNS before live deployment)
10. Create Seafile admin with individual password
11. Display setup infos and what to do next.


## After running the installer

1. Delete installer script. You wont need it anymore and might even seriously damage your system if ran again.
2. Follow the suggested steps at the end of the installation to finalize your Seafile server installation. As a bare minimum you most definitely will want to change the listening IP to a valid DNS name...


## Bugs, suggestions, you name it...
Please contact me at alexander.jackson@seafile.com.de

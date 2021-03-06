#!/bin/bash
#set -x
# -------------------------------------------
# All-In-One Seafile Server 4.1.2 installer for Debian Wheezy (64bit)
# -------------------------------------------
clear
cat <<EOF

  All-In-One Seafile Server 4.1.2 installer for Debian Wheezy (64bit)
  - Seafile, MariaDB, Memcached, NGINX -
  -----------------------------------------------------------------

  This installer is meant to run on a freshly installed machine
  only. If you run it on a production server things can and
  probably will go terrible wrong and you will loose valuable
  data!

  For questions or suggestions please contact me at
  alexander.jackson@seafile.com.de

  -----------------------------------------------------------------

  Hit return to proceed or CTRL-C to abort.

EOF
read dummy
clear


# -------------------------------------------
# Update System
# -------------------------------------------
aptitude update && aptitude upgrade -y


# -------------------------------------------
# NGINX
# -------------------------------------------
cat > /etc/apt/sources.list.d/nginx.list <<EOF
deb http://nginx.org/packages/mainline/debian/ wheezy nginx
deb-src http://nginx.org/packages/mainline/debian/ wheezy nginx
EOF
wget -O - http://nginx.org/packages/keys/nginx_signing.key | apt-key add -

aptitude update && aptitude upgrade -y
aptitude install nginx -y

rm /etc/nginx/conf.d/*

cat > /etc/nginx/conf.d/seafile.conf <<'EOF'
server {
      listen       80;
      server_name  "";
      return 301 https://$http_host$request_uri?;
}

server {
      listen 443 spdy;
      server_name  "";

      ssl on;
      ssl_certificate /etc/nginx/ssl/seafile.crt;
      ssl_certificate_key /etc/nginx/ssl/seafile.key;

      location / {
          fastcgi_pass    127.0.0.1:8000;
          fastcgi_param   SCRIPT_FILENAME     $document_root$fastcgi_script_name;
          fastcgi_param   PATH_INFO           $fastcgi_script_name;

          fastcgi_param   SERVER_PROTOCOL     $server_protocol;
          fastcgi_param   QUERY_STRING        $query_string;
          fastcgi_param   REQUEST_METHOD      $request_method;
          fastcgi_param   CONTENT_TYPE        $content_type;
          fastcgi_param   CONTENT_LENGTH      $content_length;
          fastcgi_param   SERVER_ADDR         $server_addr;
          fastcgi_param   SERVER_PORT         $server_port;
          fastcgi_param   SERVER_NAME         $server_name;

          fastcgi_param   HTTPS               on;
          fastcgi_param   HTTP_SCHEME         https;

          access_log      /var/log/nginx/seahub.access.log;
          error_log       /var/log/nginx/seahub.error.log;

      }
      location /seafhttp {
          rewrite ^/seafhttp(.*)$ $1 break;
          proxy_pass http://127.0.0.1:8082;
          client_max_body_size 0;
          proxy_connect_timeout  36000s;
          proxy_read_timeout  36000s;
      }
      location /media {
          root /opt/seafile/haiwen/seafile-server-latest/seahub;
      }
     location /seafdav {
        fastcgi_pass    127.0.0.1:8080;
        fastcgi_param   SCRIPT_FILENAME     $document_root$fastcgi_script_name;
        fastcgi_param   PATH_INFO           $fastcgi_script_name;

        fastcgi_param   SERVER_PROTOCOL     $server_protocol;
        fastcgi_param   QUERY_STRING        $query_string;
        fastcgi_param   REQUEST_METHOD      $request_method;
        fastcgi_param   CONTENT_TYPE        $content_type;
        fastcgi_param   CONTENT_LENGTH      $content_length;
        fastcgi_param   SERVER_ADDR         $server_addr;
        fastcgi_param   SERVER_PORT         $server_port;
        fastcgi_param   SERVER_NAME         $server_name;

        fastcgi_param   HTTPS               on;
        
        client_max_body_size 0;

        access_log      /var/log/nginx/seafdav.access.log;
        error_log       /var/log/nginx/seafdav.error.log;
    }
  }
EOF

mkdir /etc/nginx/ssl

openssl genrsa -out /etc/nginx/ssl/seafile.key 4096
openssl req -new -x509 -key /etc/nginx/ssl/seafile.key -out /etc/nginx/ssl/seafile.crt -days 10950 -batch

service nginx restart


# -------------------------------------------
# Additional requirements
# -------------------------------------------
aptitude install sudo python-setuptools python-simplejson python-imaging python-mysqldb \
openjdk-7-jre memcached python-memcache pwgen -y


# -------------------------------------------
# MariaDB
# -------------------------------------------
cat > /etc/apt/sources.list.d/mariadb.list <<EOF
# MariaDB Repository
deb http://mirror.netcologne.de/mariadb/repo/10.0/debian wheezy main
deb-src http://mirror.netcologne.de/mariadb/repo/10.0/debian wheezy main
EOF

apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db

aptitude update && aptitude upgrade -y

sync && sleep 5

DEBIAN_FRONTEND=noninteractive aptitude install mariadb-server -y

SQLROOTPW=$(pwgen)

mysqladmin -u root password $SQLROOTPW

cat > /root/.my.cnf <<EOF
[client]
user=root
password=$SQLROOTPW
EOF

chmod 600 /root/.my.cnf

# -------------------------------------------
# Seafile init script
# -------------------------------------------
cat > /etc/init.d/seafile-server <<'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          seafile-server
# Required-Start:    $remote_fs $syslog mysql
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Seafile server
# Description:       Start Seafile server
### END INIT INFO

# Author: Alexander Jackson <alexander.jackson@seafile.com.de>
#

# Change the value of "user" to your linux user name
user=seafile

# Change the value of "seafile_dir" to your path of seafile installation
seafile_dir=/opt/seafile/haiwen
script_path=${seafile_dir}/seafile-server-latest
seafile_init_log=${seafile_dir}/logs/seafile.init.log
seahub_init_log=${seafile_dir}/logs/seahub.init.log

# Change the value of fastcgi to true if fastcgi is to be used
fastcgi=true
# Set the port of fastcgi, default is 8000. Change it if you need different.
fastcgi_port=8000

case "$1" in
        start)
                sudo -u ${user} ${script_path}/seafile.sh start >> ${seafile_init_log}
                if [  $fastcgi = true ];
                then
                        sudo -u ${user} ${script_path}/seahub.sh start-fastcgi ${fastcgi_port} >> ${seahub_init_log}
                else
                        sudo -u ${user} ${script_path}/seahub.sh start >> ${seahub_init_log}
                fi
        ;;
        restart)
                sudo -u ${user} ${script_path}/seafile.sh restart >> ${seafile_init_log}
                if [  $fastcgi = true ];
                then
                        sudo -u ${user} ${script_path}/seahub.sh restart-fastcgi ${fastcgi_port} >> ${seahub_init_log}
                else
                        sudo -u ${user} ${script_path}/seahub.sh restart >> ${seahub_init_log}
                fi
        ;;
        stop)
                sudo -u ${user} ${script_path}/seafile.sh $1 >> ${seafile_init_log}
                sudo -u ${user} ${script_path}/seahub.sh $1 >> ${seahub_init_log}
        ;;
        *)
                echo "Usage: /etc/init.d/seafile-server {start|stop|restart}"
                exit 1
        ;;
esac
EOF

chmod +x /etc/init.d/seafile-server
update-rc.d seafile-server defaults


# -------------------------------------------
# Seafile
# -------------------------------------------
adduser --system --gecos "seafile" seafile --home /opt/seafile
mkdir -p /opt/seafile/haiwen/installed
cd /opt/seafile/haiwen/
wget https://bitbucket.org/haiwen/seafile/downloads/seafile-server_4.1.2_x86-64.tar.gz
tar xzf seafile-server_4.1.2_x86-64.tar.gz
mv seafile-server_4.1.2_x86-64.tar.gz installed


# -------------------------------------------
# Seafile DB
# -------------------------------------------
SQLSEAFILEPW=$(pwgen)

cat > /opt/seafile/.my.cnf <<EOF
[client]
user=seafile
password=$SQLSEAFILEPW
EOF

chmod 600 /opt/seafile/.my.cnf
chown -R seafile.nogroup /opt/seafile/

mysql -e "CREATE DATABASE IF NOT EXISTS \`ccnet-db\` character set = 'utf8';"
mysql -e "CREATE DATABASE IF NOT EXISTS \`seafile-db\` character set = 'utf8';"
mysql -e "CREATE DATABASE IF NOT EXISTS \`seahub-db\` character set = 'utf8';"
mysql -e "create user 'seafile'@'localhost' identified by '$SQLSEAFILEPW';"
mysql -e "GRANT ALL PRIVILEGES ON \`ccnet-db\`.* to \`seafile\`;"
mysql -e "GRANT ALL PRIVILEGES ON \`seafile-db\`.* to \`seafile\`;"
mysql -e "GRANT ALL PRIVILEGES ON \`seahub-db\`.* to \`seafile\`;"
mysql seahub-db < /opt/seafile/haiwen/seafile-server-4.1.2/seahub/sql/mysql.sql


# -------------------------------------------
# Go to /opt/seafile/haiwen/seafile-server-4.1.2
# -------------------------------------------
cd /opt/seafile/haiwen/seafile-server-4.1.2/


# -------------------------------------------
# Define Seafile admin credentials.
# -------------------------------------------
SEAFILE_ADMIN=admin@seafile.local
SEAFILE_ADMIN_PW=$(pwgen)


# -------------------------------------------
# Vars - Don't touch these unless you really know what you are doing!
# -------------------------------------------
SCRIPT=$(readlink -f "$0")
#INSTALLPATH=$(dirname "${SCRIPT}")
INSTALLPATH=/opt/seafile/haiwen/seafile-server-4.1.2/
TOPDIR=$(dirname "${INSTALLPATH}")
DEFAULT_CCNET_CONF_DIR=${TOPDIR}/ccnet
DEFAULT_SEAFILE_DATA_DIR=${TOPDIR}/seafile-data
DEFAULT_SEAHUB_DB=${TOPDIR}/seahub.db
DEFAULT_CONF_DIR=${TOPDIR}/conf
SERVER_NAME=$(hostname -s)
IP_OR_DOMAIN=$(hostname -i)
HOSTNAME=$(hostname -i)
SERVER_PORT=10001
SEAFILE_DATA_DIR=${TOPDIR}/seafile-data
LIBRARY_TEMPLATE_DIR=${SEAFILE_DATA_DIR}/library-template
SRC_DOCS_DIR=${INSTALLPATH}/seafile/docs/
SEAFILE_SERVER_PORT=12001
FILESERVER_PORT=8082
SEAFILESQLPW=$(grep password /opt/seafile/.my.cnf | awk -F'=' {'print $2'})
export SEAFILE_LD_LIBRARY_PATH=${INSTALLPATH}/seafile/lib/:${INSTALLPATH}/seafile/lib64:${LD_LIBRARY_PATH}
DEST_SETTINGS_PY=${TOPDIR}/seahub_settings.py
SEAHUB_SECRET_KEYGEN=${INSTALLPATH}/seahub/tools/secret_key_generator.py
key=$(python "${SEAHUB_SECRET_KEYGEN}")
CCNET_INIT=${INSTALLPATH}/seafile/bin/ccnet-init
SEAF_SERVER_INIT=${INSTALLPATH}/seafile/bin/seaf-server-init
MEDIA_DIR=${INSTALLPATH}/seahub/media
ORIG_AVATAR_DIR=${INSTALLPATH}/seahub/media/avatars
DEST_AVATAR_DIR=${TOPDIR}/seahub-data/avatars
SEAFILE_SERVER_SYMLINK=${TOPDIR}/seafile-server-latest


# -------------------------------------------
# Create ccnet conf
# -------------------------------------------
LD_LIBRARY_PATH=$SEAFILE_LD_LIBRARY_PATH "${CCNET_INIT}" -c "${DEFAULT_CCNET_CONF_DIR}" \
  --name "${SERVER_NAME}" --port "${SERVER_PORT}" --host "${IP_OR_DOMAIN}"

# Fix service url
eval "sed -i 's/^SERVICE_URL.*/SERVICE_URL = https:\/\/${IP_OR_DOMAIN}/' ${DEFAULT_CCNET_CONF_DIR}/ccnet.conf"


# -------------------------------------------
# Create seafile conf
# -------------------------------------------
LD_LIBRARY_PATH=$SEAFILE_LD_LIBRARY_PATH ${SEAF_SERVER_INIT} --seafile-dir "${SEAFILE_DATA_DIR}" \
  --port ${SEAFILE_SERVER_PORT} --fileserver-port ${FILESERVER_PORT}


# -------------------------------------------
# Write seafile.ini
# -------------------------------------------
echo "${SEAFILE_DATA_DIR}" > "${DEFAULT_CCNET_CONF_DIR}/seafile.ini"


# -------------------------------------------
# Configure Seafile WebDAV Server(SeafDAV)
# -------------------------------------------
mkdir -p ${DEFAULT_CONF_DIR}
cat > ${DEFAULT_CONF_DIR}/seafdav.conf <<EOF
[WEBDAV]
enabled = true
port = 8080
fastcgi = true
share_name = /seafdav
EOF


# -------------------------------------------
# generate seahub_settings.py
# -------------------------------------------
echo "SECRET_KEY = \"${key}\"" > "${DEST_SETTINGS_PY}"


# -------------------------------------------
# prepare avatar folder
# -------------------------------------------
mkdir -p "${TOPDIR}/seahub-data"
mv "${ORIG_AVATAR_DIR}" "${DEST_AVATAR_DIR}"
ln -s ../../../seahub-data/avatars ${MEDIA_DIR}


# -------------------------------------------
# Create symlink for current server version
# -------------------------------------------
ln -s $(basename ${INSTALLPATH}) ${SEAFILE_SERVER_SYMLINK}


# Fix permissions
chmod 0600 "$DEST_SETTINGS_PY"
chmod 0700 "$DEFAULT_CCNET_CONF_DIR"
chmod 0700 "$SEAFILE_DATA_DIR"
chmod 0700 "$DEFAULT_CONF_DIR"


# -------------------------------------------
# copy user manuals to library template
# -------------------------------------------
mkdir -p ${LIBRARY_TEMPLATE_DIR}
cp -f ${SRC_DOCS_DIR}/*.doc ${LIBRARY_TEMPLATE_DIR}


# -------------------------------------------
# Configuring ccnet.conf
# -------------------------------------------
cat >> ${DEFAULT_CCNET_CONF_DIR}/ccnet.conf <<EOF

[Database]
ENGINE = mysql
HOST = 127.0.0.1
PORT = 3306
USER = seafile
PASSWD = $SEAFILESQLPW
DB = ccnet-db
CONNECTION_CHARSET = utf8
EOF


# -------------------------------------------
# Configuring seahub_settings.py
# -------------------------------------------
cat >> ${DEST_SETTINGS_PY} <<EOF

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'seahub-db',
        'USER': 'seafile',
        'PASSWORD': '$SEAFILESQLPW',
        'HOST': '127.0.0.1',
        'PORT': '3306',
        'OPTIONS': {
            'init_command': 'SET storage_engine=INNODB',
        }
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
    'LOCATION': '127.0.0.1:11211',
    }
}

EMAIL_USE_TLS                       = False
EMAIL_HOST                          = 'localhost'
EMAIL_HOST_USER                     = ''
EMAIL_HOST_PASSWORD                 = ''
EMAIL_PORT                          = '25'
DEFAULT_FROM_EMAIL                  = 'seafile@${IP_OR_DOMAIN}'
SERVER_EMAIL                        = 'EMAIL_HOST_USER'
TIME_ZONE                           = 'Europe/Berlin'
SITE_BASE                           = 'https://${IP_OR_DOMAIN}'
SITE_NAME                           = 'Seafile Server'
SITE_TITLE                          = 'Seafile Server'
SITE_ROOT                           = '/'
USE_PDFJS                           = True
ENABLE_SIGNUP                       = False
ACTIVATE_AFTER_REGISTRATION         = False
SEND_EMAIL_ON_ADDING_SYSTEM_MEMBER  = True
SEND_EMAIL_ON_RESETTING_USER_PASSWD = True
CLOUD_MODE                          = False
FILE_PREVIEW_MAX_SIZE               = 30 * 1024 * 1024
SESSION_COOKIE_AGE                  = 60 * 60 * 24 * 7 * 2
SESSION_SAVE_EVERY_REQUEST          = False
SESSION_EXPIRE_AT_BROWSER_CLOSE     = False
FILE_SERVER_ROOT                    = 'https://${IP_OR_DOMAIN}/seafhttp'
EOF


# -------------------------------------------
# Backup check_init_admin.py befor applying changes
# -------------------------------------------
cp ${INSTALLPATH}/check_init_admin.py ${INSTALLPATH}/check_init_admin.py.backup


# -------------------------------------------
# Set admin credentials in check_init_admin.py
# -------------------------------------------
eval "sed -i 's/= ask_admin_email()/= \"${SEAFILE_ADMIN}\"/' ${INSTALLPATH}/check_init_admin.py"
eval "sed -i 's/= ask_admin_password()/= \"${SEAFILE_ADMIN_PW}\"/' ${INSTALLPATH}/check_init_admin.py"


# -------------------------------------------
# Start and stop Seafile eco system. This generates the initial admin user.
# -------------------------------------------
${TOPDIR}/seafile-server-4.1.2/seafile.sh start
${TOPDIR}/seafile-server-4.1.2/seahub.sh start
${TOPDIR}/seafile-server-4.1.2/seahub.sh stop
${TOPDIR}/seafile-server-4.1.2/seafile.sh stop


# -------------------------------------------
# Restore original check_init_admin.py
# -------------------------------------------
mv ${INSTALLPATH}/check_init_admin.py.backup ${INSTALLPATH}/check_init_admin.py


# -------------------------------------------
# Fix permissions
# -------------------------------------------
chown seafile.nogroup -R /opt/seafile/


# -------------------------------------------
# Start seafile server
# -------------------------------------------
echo "Starting productive Seafile server"
service seafile-server start


# -------------------------------------------
# Final report
# -------------------------------------------
clear
cat <<EOF

  Your Seafile server is installed
  -----------------------------------------------------------------

  Server Name:         ${SERVER_NAME}
  Server Address:      https://${IP_OR_DOMAIN}

  Seafile Admin:       ${SEAFILE_ADMIN}
  Admin Password:      ${SEAFILE_ADMIN_PW}

  Seafile Data Dir:    ${SEAFILE_DATA_DIR}

  Seafile DB Credentials:  Check /opt/seafile/.my.cnf 
  Root DB Credentials:     Check /root/.my.cnf 
  

  
  Now you should manually complete the following steps
  -----------------------------------------------------------------

  1) seahub_settings.py:  Change IP within FILE_SERVER_ROOT variable to DNS

  2) ccnet.conf:          Change IP within SERVICE_URL variable to DNS

  3) Restart server with: service seafile-server restart

  4) If this server is behind a firewall, you need to ensure that
     tcp port 443 for the NGINX reverse proxy is open. Optionally
     you may also open tcp port 80 which redirects all unencrypted
     http traffic to the encrypted https port.

  5) Seahub tries to send emails via the local server. Install and 
     configure Postfix for this to work.
  
  
  Optional steps
  -----------------------------------------------------------------

  1) Check seahub_settings.py and customize it to fit your needs. Consult 
     http://manual.seafile.com/config/seahub_settings_py.html for possible switches.
  
  2) Setup NGINX with official SSL certificate.
  
  3) Secure server with iptables based firewall. For instance: UFW or shorewall
  
  4) Harden system with port knocking, fail2ban, etc.
  
  5) Enable unattended installation of security updates. Check 
     https://wiki.debian.org/UnattendedUpgrades for details.

  6) Implement a backup routine for your Seafile server.
    
  
  
  Seafile support options
  -----------------------------------------------------------------

  For free community support visit:   https://forum.seafile-server.org
  For paid commercial support visit:  https://seafile.com.de


  
  About
  -----------------------------------------------------------------

  Please contact alexander.jackson@seafile.com.de
  for bugs or suggestions about this installer. Thank you!
  
EOF

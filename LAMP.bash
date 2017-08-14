#!/bin/bash

##Import my Arch Base Takes care of the L in LAMP
source <ssinclude StackScriptID="12938">

# <UDF name="serveradmin" label="admin email address on error pages" />




## Install Apache Takes care of the A in LAMP
pacman -S apache --noconfirm

echo "Edit ServerAdmin in /etc/httpd/conf/httpd.conf"
sed -i 's/you\@example\.com/$SERVERADMIN\' /etc/httpd/conf/httpd.conf

echo "Edit ServerTokens in /etc/httpd/conf/httpd-default.conf  New Value=Prod"
sed -i 's/ServerTokens\ Full/ServerTokens\ Prod/' /etc/httpd/conf/extra/httpd-default.conf

echo "Comment out Include conf/extra/httpd-userdir.conf in /etc/httpd/conf/httpd.conf"
sed -e '/httpd-userdir/ s/^#*/#/' -i /etc/httpd/conf/httpd.conf


## Install PHP takes care of the P in LAMP... looks like I'm doing this in the wrong order
pacman -S php php-apache --noconfirm
sed -e '/LoadModule\ mpm_event_/ s/^#*/#/' -i /etc/httpd/conf/httpd.conf
sed -i '/LoadModule\ mpm_prefork_module/s/^#//' /etc/httpd/conf/httpd.conf

cat << 'EOF' >> /etc/httpd/conf/httpd.conf
LoadModule php7_module modules/libphp7.so
AddHandler php7-script php7
Include conf/extra/php7_module.conf
EOF

systemctl enable httpd

## Install MariaDB (the M)

pacman -S mariadb --noconfirm
mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

systemctl enable mariaDB
systemctl start mariadb

sed -i '/pdo_mysql\.so/ s/^;//' /etc/php/php.ini
sed -i '/mysqli\.so/ s/^;//' /etc/php/php.ini


#### Figure out Lets Encrypt
#In /etc/httpd/conf/httpd.conf, uncomment the following three lines:
#LoadModule ssl_module modules/mod_ssl.so
#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
#Include conf/extra/httpd-ssl.conf

pacman -S certbot certbot-apache --noconfirm

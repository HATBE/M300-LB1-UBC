#!/bin/bash

# (c) Aaron Gensetter, 2021
# Part from "Ultra Bad Cloud (UBC)"

## Check if some args are given
if [[ $# -eq 0 ]]
then
    echo "exit"
    exit 1
fi
# ($1 == nodename)

## Define vars
# Nextcloud
NEXTCLOUD_LINK="https://download.nextcloud.com/server/releases/nextcloud-21.0.2.zip"
NEXTCLOUD_ADMIN_USER="admin"
NEXTCLOUD_ADMIN_PW="Password123"

# Database
MYSQL_HOST="10.9.8.101"
MYSQL_USER="root"
MYSQL_PW="Password123"

## Installation
apt update -y 
#apt upgrade -y

apt install unzip -y
apt install apache2 apache2-utils -y
systemctl start apache2
systemctl enable apache2
apt install imagemagick php-imagick libapache2-mod-php7.4 php7.4-common php7.4-mysql php7.4-fpm php7.4-gd php7.4-json php7.4-curl php7.4-zip php7.4-xml php7.4-mbstring php7.4-bz2 php7.4-intl php7.4-bcmath php7.4-gmp -y # Install needed PHP modules
a2enmod php7.4 # enable php
systemctl restart apache2
rm /var/www/html/index.html
wget "${NEXTCLOUD_LINK}" # Download Nextcloud
unzip nextcloud*.zip -d /var/www/html # Unpack Nextcloud
cp /var/www/html/nextcloud/* /var/www/html -R
rm /var/www/html/nextcloud -R
chown www-data:www-data /var/www/html/ -R
# TODO: make sites-available stuff: https://www.linuxbabe.com/ubuntu/install-nextcloud-ubuntu-20-04-apache-lamp-stack

su -l www-data -s /bin/bash -c "php /var/www/html/occ maintenance:install --database 'mysql' --database-host '${MYSQL_HOST}' --database-name '${1}' --database-user '${MYSQL_USER}' --database-pass '${MYSQL_PW}' --admin-user '${NEXTCLOUD_ADMIN_USER}' --admin-pass '${NEXTCLOUD_ADMIN_PW}'" # Configure/Install Nextcloud

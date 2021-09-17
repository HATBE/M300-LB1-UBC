#!/bin/bash

# (c) Aaron Gensetter, 2021
# Part from "Ultra Bad Cloud (UBC)"

## Define vars
MYSQL_ROOT_PW="Password123"

## Installation
apt update -y
#apt upgrade -y

apt install mariadb-server mariadb-client -y

sed -e '/bind-address            = 127.0.0.1/ s/^#*/#/' -i /etc/mysql/mariadb.conf.d/50-server.cnf # comment out the bind adress, to open it to public
systemctl restart mariadb

## Install / Configure MariaDB
mysql -e "UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root';" # make shure the user can login, with the right plugin
mysql -e "UPDATE mysql.user SET Password = PASSWORD('${MYSQL_ROOT_PW}') WHERE User = 'root';" # Set a password for The root user
mysql -e "DROP USER IF EXISTS ''@'localhost';" # Remove the Anonymous User
mysql -e "DROP USER IF EXISTS ''@'$(hostname)';"
mysql -e "DROP DATABASE IF EXISTS test;" # Remove the Demo database
mysql -e "UPDATE mysql.user SET Host='%' WHERE User='root';"

mysql -e "FLUSH PRIVILEGES;"
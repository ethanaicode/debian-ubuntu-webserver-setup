#!/bin/bash

# update: 2025-04-27
# os: Debian/Ubuntu
# Note: This script is not complete. It is just a snippet.

# Before running this script, make sure you have run the following command:
# sudo apt update && sudo apt upgrade -y

#############################################
# Install PHP 7.4
#############################################

# Create downloads directory
if [ ! -d /www/downloads ]; then
    mkdir -p /www/downloads
fi
cd /www/downloads

# Download PHP
wget https://www.php.net/distributions/php-7.4.33.tar.gz \
&& tar -xzvf php-7.4.33.tar.gz \
&& cd php-7.4.33

# Install PHP dependencies
sudo apt install -y \
build-essential \
libxml2 libcurl4 openssl \
pkg-config sqlite3 libsqlite3-dev libsqlite3-0 \
libxml2-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libwebp-dev libxpm-dev \
libfreetype6-dev libgmp-dev libmcrypt-dev libreadline-dev libzip-dev \
libonig-dev libldap2-dev libkrb5-dev libssl-dev libicu-dev libxslt1-dev libtidy-dev libedit-dev

# Delete the following line avoiding RSA_SSLV23_PADDING error
# Only for php 7.4.33
# Thanks to: https://forum.directadmin.com/threads/end-of-life-of-php-7-4.67500/page-2
sed -i '/REGISTER_LONG_CONSTANT("OPENSSL_SSLV23_PADDING", RSA_SSLV23_PADDING, CONST_CS|CONST_PERSISTENT);/d' ext/openssl/openssl.c

# Configure PHP
./configure --prefix=/www/server/php/74 \
--with-config-file-path=/www/server/php/74/etc \
--enable-fpm \
--with-fpm-user=www-data \
--with-fpm-group=www-data \
--enable-mysqlnd \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--enable-mysqlnd-compression-support \
--with-zlib \
--enable-xml \
--disable-rpath \
--enable-bcmath \
--enable-shmop \
--enable-sysvsem \
--with-curl \
--enable-mbregex \
--enable-mbstring \
--enable-intl \
--enable-ftp \
--enable-gd-jis-conv \
--with-openssl \
--with-mhash \
--enable-pcntl \
--enable-sockets \
--enable-soap \
--with-gettext \
--enable-fileinfo \
--enable-opcache \
--with-ldap=shared \
--without-gdbm \
--with-jpeg \
--with-webp \
--with-xpm \
--with-freetype \
--enable-gd \
--enable-exif 

# Make PHP
make && make install

# Echo PHP version
/www/server/php/74/bin/php -v

# Copy PHP configuration
cp php.ini-production /www/server/php/74/etc/php.ini

# Download PHP-FPM configuration
wget -P /www/server/php/74/etc https://raw.githubusercontent.com/ethanaicode/debian-ubuntu-webserver-setup/main/conf/php/php-fpm.conf
# Note: if you use THISPROJECT/conf/php/php-fpm.conf instead of php-fpm.conf.default,
#     you wont need to copy the file to php-fpm.d/www.conf

# Copy PHP-FPM configuration
# cp /www/server/php/74/etc/php-fpm.conf.default /www/server/php/74/etc/php-fpm.conf

# Copy PHP-FPM pool configuration
# cp /www/server/php/74/etc/php-fpm.d/www.conf.default /www/server/php/74/etc/php-fpm.d/www.conf

# Link PHP-FPM binary
# If you have multiple PHP versions, you can create a symbolic link to the PHP version you want to use
# like this: ln -s /www/server/php/74/bin/php /usr/bin/php74
ln -s /www/server/php/74/sbin/php-fpm /usr/bin/php-fpm
ln -s /www/server/php/74/bin/php /usr/bin/php
ln -s /www/server/php/74/bin/phpize /usr/bin/phpize
# If you have multiple PHP versions, you can create a symbolic link to the PHP version you want to use
ln -s /www/server/php/74/sbin/php-fpm /usr/bin/php-fpm74
ln -s /www/server/php/74/bin/php /usr/bin/php74
ln -s /www/server/php/74/bin/phpize /usr/bin/phpize74

# Start PHP-FPM
php-fpm

# You can use THISPROJECT/conf/systemd/php-fpm.server to create a service file
# for PHP-FPM. You can copy the file to /usr/lib/systemd/system/php-fpm.service
# and reload systemd using systemctl daemon-reload
# and then start PHP-FPM using systemctl start php-fpm
# start on boot using systemctl enable php-fpm
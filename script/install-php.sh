#!/bin/bash

# update: 2024-11-15
# os: Debian 12
# Note: This script is not complete. It is just a snippet.

# Before running this script, make sure you have run the following command:
# sudo apt update && sudo apt upgrade -y

# Install PHP

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
libxml2 libcurl4 openssl \
pkg-config sqlite3 libsqlite3-dev libsqlite3-0 \
libxml2-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libwebp-dev libxpm-dev \
libfreetype6-dev libgmp-dev libmcrypt-dev libreadline-dev libzip-dev \
libonig-dev libldap2-dev libkrb5-dev libssl-dev libicu-dev libxslt1-dev libtidy-dev libedit-dev

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

# Copy PHP-FPM configuration
cp /www/server/php/74/etc/php-fpm.conf.default /www/server/php/74/etc/php-fpm.conf

# Copy PHP-FPM pool configuration
# This is not necessary if you are using the default configuration
# cp /www/server/php/74/etc/php-fpm.d/www.conf.default /www/server/php/74/etc/php-fpm.d/www.conf

# Link PHP-FPM binary
ln -s /www/server/php/74/sbin/php-fpm /usr/bin/php-fpm
ln -s /www/server/php/74/bin/php /usr/bin/php
ln -s /www/server/php/74/bin/phpize /usr/bin/phpize
# If you have multiple PHP versions, you can create a symbolic link to the PHP version you want to use
# like this: ln -s /www/server/php/74/bin/php /usr/bin/php74

# Start PHP-FPM
php-fpm

# Set PHP-FPM to start on boot
systemctl enable php-fpm
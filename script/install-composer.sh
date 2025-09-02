#!/bin/bash

# update: 2025-04-27
# os: Debian/Ubuntu

# Before running this script, make sure you have run the following command:
# sudo apt update && sudo apt upgrade -y

#############################################
# Install Composer
#############################################

# Before installing Composer, ensure that PHP is installed and available in the PATH.
# You can open https://getcomposer.org/download/ for the latest version of Composer and replace the URL in the command below if necessary.

# Check if PHP is installed
if ! command -v php &> /dev/null
then
    echo "PHP is not installed. Please install PHP first."
    exit 1
fi

# Download Composer by using the PHP command
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
# Verify the installer SHA-384
php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
# Install Composer globally
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
# Remove the installer
php -r "unlink('composer-setup.php');"

# Check if Composer is installed
if ! command -v composer &> /dev/null
then
    echo "Composer installation failed."
    exit 1
fi
echo "Composer installed successfully."

# Check Composer version
composer --version
#!/bin/bash

# update: 2024-12-25
# os: Debian 12
# Note: This script is not complete. It is just a snippet.

# Before running this script, make sure you have run the following command:
# sudo apt update && sudo apt upgrade -y

#############################################
# Install Nginx
#############################################

# Install Nginx
sudo apt install nginx -y

# Start Nginx
sudo systemctl start nginx

# echo Nginx status
sudo systemctl status nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Open port
# sudo ufw allow 'Nginx HTTP'
# sudo ufw allow 'Nginx HTTPS'
# sudo ufw status

# Check Nginx version
nginx -v
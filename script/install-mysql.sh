#!/bin/bash

# update: 2025-01-07
# os: Debian/Ubuntu
# Note: This script is not complete. It is just a snippet.

#############################################
# Install MySQL 8.0
#############################################

# 1. goto https://dev.mysql.com/downloads/repo/apt/

# 2. Download the latest MySQL repository information package by running the following command:
   wget https://dev.mysql.com/get/mysql-apt-config_0.8.33-1_all.deb

# 3. Install the MySQL repository information using the file by running the following command:
   sudo dpkg -i  mysql-apt-config_0.8.33-1_all.deb
#    You can select the MySQL version you want to install. In this case, we will select MySQL 8.0.

# 4. Update the server's package index to apply the new MySQL repository information.
   sudo apt update

# 5. Install the MySQL database server package.
    sudo apt install mysql-server -y

# 6. View the installed MySQL version on your server.
    mysql --version

#############################################
# Manage MySQL Service
#############################################

# Secure the MySQL Database Server

# 1. Run the MySQL secure installation.
    sudo mysql_secure_installation

# Access MySQL


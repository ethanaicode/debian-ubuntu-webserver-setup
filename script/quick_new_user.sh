#!/bin/bash

# 脚本作用: 快速添加新用户并赋予 sudo 权限
# 适用于 Ubuntu 或 Debian 系统
# 需要以 root 用户或具有 sudo 权限的用户执行
# How to use: ./quick_new_user.sh <username>

# <username> is the username of the new user to be added
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

# Add a new user
USERNAME=$1

sudo useradd -m $USERNAME 
echo "User $USERNAME added."

# Set password and grant sudo privileges
sudo passwd $USERNAME
sudo usermod -aG sudo $USERNAME
echo "User $USERNAME added and granted sudo privileges."
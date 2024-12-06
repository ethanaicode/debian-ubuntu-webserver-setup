#!/bin/bash

# How to use: ./quick_new_user.sh <username>

# Add a new user
USERNAME=$1
sudo useradd -m $USERNAME 
sudo passwd $USERNAME
sudo usermod -aG sudo $USERNAME
echo "User $USERNAME added and granted sudo privileges."
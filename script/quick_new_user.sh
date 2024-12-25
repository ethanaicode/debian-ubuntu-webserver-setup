#!/bin/bash

# How to use: ./quick_new_user.sh <username>

# Add a new user
USERNAME=$1

sudo useradd -m $USERNAME 
echo "User $USERNAME added."

# Set password and grant sudo privileges
sudo passwd $USERNAME
sudo usermod -aG sudo $USERNAME
echo "User $USERNAME added and granted sudo privileges."
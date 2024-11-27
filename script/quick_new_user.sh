#!/bin/bash
# Add a new user
USERNAME=$1
sudo useradd -m $USERNAME 
sudo passwd $USERNAME
sudo usermod -aG sudo $USERNAME
echo "User $USERNAME added and granted sudo privileges."
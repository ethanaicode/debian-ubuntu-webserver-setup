#!/bin/bash
# This script looks up and pings a Windows computer by name.

# ==============================
# Configuration
# ==============================
# Default device name is "Win-Ethan", can be overridden by passing a name as an argument.
DEVICE_NAME="${1:-Win-Ethan}"  

# ==============================
# SMB lookup
# ==============================
echo "=============================="
echo "Looking up Windows computer name..."
echo "=============================="
if smbutil lookup "$DEVICE_NAME"; then
  echo "Lookup successful for $DEVICE_NAME"
  echo "Trying to ping $DEVICE_NAME to ensure it's reachable..."
else
  echo "❌ Failed to lookup $DEVICE_NAME"
  echo "Trying to ping $DEVICE_NAME instead..."
fi

# ==============================
# Ping test
# ==============================
echo
echo "=============================="
echo "Pinging Windows computer..."
echo "=============================="
ping -c 4 "${DEVICE_NAME}.local"

# ==============================
# Done
# ==============================
echo
echo "=============================="
echo "Operation completed for $DEVICE_NAME"
echo "=============================="

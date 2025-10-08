#!/bin/bash

# Check if tmpfs is already mounted on /mnt/tmpfs
if mount | grep -q "tmpfs on /mnt/tmpfs"; then
    echo "tmpfs is already mounted on /mnt/tmpfs"
    echo "Current mount info:"
    mount | grep "/mnt/tmpfs"
    echo "Skipping mount operation."
else
    echo "No tmpfs found on /mnt/tmpfs, creating and mounting..."
    sudo mkdir -p /mnt/tmpfs
    sudo mount -t tmpfs -o size=50G tmpfs /mnt/tmpfs
    sudo chown u7300623:users /mnt/tmpfs
    sudo chmod 744 /mnt/tmpfs
    echo "tmpfs mounted successfully on /mnt/tmpfs"
fi
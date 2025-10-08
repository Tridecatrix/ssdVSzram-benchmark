sudo mkdir -p /mnt/tmpfs
sudo mount -t tmpfs -o size=50G tmpfs /mnt/tmpfs
sudo chown u7300623:users /mnt/tmpfs
sudo chmod 744 /mnt/tmpfs
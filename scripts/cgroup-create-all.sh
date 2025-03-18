#!/bin/bash

memlim=("256M" "512M" "1G" "2G" "4G" "8G" "16G" "32G" "64G") # these are memlims for all 64 processes together
# memlim=("16M" "32M" "64M" "128M" "256M" "512M" "1G") # these are memlims assuming that the cgroup applies seperately to each process

for memlim in ${memlim[@]}; do
  sudo ./scripts/cgroup-create.sh memlim.$memlim $memlim u7300623
done
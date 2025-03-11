#!/bin/bash

memlim=("256M" "512M" "1G" "2G" "4G" "8G" "16G" "32G" "64G")

for memlim in ${memlim[@]}; do
  sudo ./scripts/cgroup-create.sh memlim $memlim u7300623
done
#!/bin/bash

# run with sudo

# set up zram
sudo modprobe zram num_devices=3

cmp_algs=("lzo" "zstd" "lz4")

for i in ${!cmp_algs[@]}; do
    mkdir -p zrammnt$i-${cmp_algs[$i]}
    sudo zramctl /dev/zram$i -a ${cmp_algs[$i]} -s 128G
    sudo mkfs.ext4 /dev/zram$i
    sudo mount /dev/zram$i zrammnt$i-${cmp_algs[$i]}
done

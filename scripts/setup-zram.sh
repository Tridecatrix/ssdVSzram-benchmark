#!/bin/bash

# run with sudo

# set up zram
sudo modprobe zram num_devices=3

cmp_algs=("lzo" "zstd" "lz4")

for i in ${!cmp_algs[@]}; do
    zdir=zrammnt$i-${cmp_algs[$i]}

    mkdir -p $zdir
    sudo zramctl /dev/zram$i -a ${cmp_algs[$i]} -s 128G
    sudo mkfs.ext4 /dev/zram$i
    sudo mount /dev/zram$i $zdir

    sudo chmod u+xrw $zdir
    sudo chown u7300623:users $zdir # NOTE: replace this with name of your user and user group
done
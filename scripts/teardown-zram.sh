#!/bin/bash

# run with sudo

cmp_algs=("lzo" "zstd" "lz4")

for i in ${!cmp_algs[@]}; do
    zdir=zrammnt$i-${cmp_algs[$i]}
    rm -rf $zdir/*
    sudo umount $zdir
done

sudo modprobe zram -r
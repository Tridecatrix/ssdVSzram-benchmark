#!/bin/bash

# run with sudo

set -x

cmp_algs=("lzo" "zstd" "lz4")

for i in ${!cmp_algs[@]}; do
    zdir=/mnt/zrammnt$i-${cmp_algs[$i]}
    #rm -r $zdir/*
    sudo umount $zdir
    #rm -r $zdir
done

#!/bin/bash

# run with sudo

set -x

usage() {
  echo "Usage: ./setup-zram.sh [-s DEVICE_SIZE] [-m MEMORY_LIMIT] [-h]"
  echo "Suffixes allowed for both of these values" 
}

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -s | --size )
    shift; size=$1
    ;;
  -m | --memlim )
    shift; memlim=$1
    ;;
  -h | --help )
    usage
    exit
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

if [[ -z "$size" || -z "$memlim" ]]; then
  echo "Error: Both -s (size) and -m (memlim) options are required."
  echo "Note: for no memory limit, provide -m 0"
  usage
  exit 1
fi

# set up zram
sudo modprobe zram num_devices=3

cmp_algs=("lzo" "zstd" "lz4")

for i in ${!cmp_algs[@]}; do
    zdir=/mnt/zrammnt$i-${cmp_algs[$i]} # update this if you want zram to be elsewhere

    mkdir -p $zdir
    sudo zramctl /dev/zram$i -a ${cmp_algs[$i]} -s $size
    sudo sh -c "echo $memlim > /sys/block/zram${i}/mem_limit"
    sudo mkfs.ext4 /dev/zram$i
    sudo mount /dev/zram$i $zdir -o discard

    sudo chmod u+xrw $zdir
    sudo chown u7300623:users $zdir # NOTE: replace this with name of your user and user group
done

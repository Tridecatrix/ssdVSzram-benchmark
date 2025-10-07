#!/bin/bash

dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/ssd0/adnan" "/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("nvme0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

RESULTSDIR=data-raven3
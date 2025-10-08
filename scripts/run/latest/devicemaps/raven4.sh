#!/bin/bash

# device settings
dev_names=("ssdraid" "zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/nvme-raid/adnan/bench" "/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/md127" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("md127" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

RESULTSDIR=data-raven4
#!/bin/bash

# run this script with command ./run.sh > data/log.txt &

./system_util/start_statistics.sh -d data/system-util
echo "statistics started"

#fio config/job-file-async.ini --output=data/fio/log.txt
sleep 1

./system_util/stop_statistics.sh -d data/system-util
echo "statistics ended"

./system_util/extract-data.sh -r data/system-util -d /dev/zram0 -d /dev/nvme0n1
echo "data extracted"
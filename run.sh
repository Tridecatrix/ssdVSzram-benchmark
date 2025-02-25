#!/bin/bash

# run this script with command ./run.sh > data/log.txt &

./system_util/start_statistics.sh -d data/system-util
echo "statistics started"

fio job-file.ini --output=data/fio/log.txt

./system_util/stop_statistics.sh -d data/system-util
echo "statistics ended"

./system_util/extract-data.sh -r data/system-util -d /dev/zram0 -d /dev/nvme0n1
echo "data extracted"
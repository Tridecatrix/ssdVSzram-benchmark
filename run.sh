#!/bin/bash

# run this script with command nohup ./run.sh > data/log.txt & 2>&1
# if wanting to run fio only to check that job files are parsed correctly, use --parse-only option on fio below

if [[ $# -gt 1 ]]; then
    # expname is name of experiment, which is appended to the result directory name created in directory data
    echo "Usage: ./run.sh expname"
fi

if [[ -z $1 ]]; then
    EXPNAME=unnamed
else
    EXPNAME=$1
fi

RESULTSDIR=data/$(date +%F-time-%H-%M-%S)-$EXPNAME

mkdir -p $RESULTSDIR
mkdir $RESULTSDIR/fio
mkdir $RESULTSDIR/system-util

./system_util/start_statistics.sh -d $RESULTSDIR/system-util
echo "statistics started"

fio config/job-file-async.ini config/job-file-sync-mmap.ini config/job-file-sync-syscall.ini --output=$RESULTSDIR/fio/log.txt
echo "fio started"

./system_util/stop_statistics.sh -d $RESULTSDIR/system-util
echo "statistics ended"

./system_util/extract-data.sh -r $RESULTSDIR/system-util -d zram0 -d nvme0n1
echo "data extracted"
#!/bin/bash

# run this script with command ./run.sh > data/log.txt & 2>&1

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

#fio config/job-file-async.ini --output=$RESULTSDIR/fio/log.txt
#echo "fio started"
sleep 1

./system_util/stop_statistics.sh -d $RESULTSDIR/system-util
echo "statistics ended"

./system_util/extract-data.sh -r $RESULTSDIR/system-util -d zram0 -d nvme0n1
echo "data extracted"
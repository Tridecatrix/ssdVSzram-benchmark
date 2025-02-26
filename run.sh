#!/bin/bash

# run this script with this command: 
# nohup ./run.sh > data/log.txt & 2>&1

# ----------------------------------
# setup
# ----------------------------------

# set this to "--parse-only" to run fio with parse-only option (just check that job files parse), else set to blank 
testrunopt=""

# constants
size="32G"
SSDdir="/mnt/ssd/adnan/bench"
ZRAMdir="/home/users/u7300623/SSDvsZRAM-fio/zram"

# options for other fio variables
block_sizes=(512 1024 2048 4096)
nexecs=(8 16 32 64)
rws=("read" "write" "rw" "randread" "randwrite" "randrw")
sync_ioengines=("sync" "mmap")

# assert that ZRAM is mounted
if grep -qs "/dev/zram0 ${ZRAMdir} " /proc/mounts; then
  echo "Verified that ZRAM is mounted."
else
  echo "ZRAM is not mounted on the specified directory; please fix."
  exit
fi

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

# ----------------------------------
# running things
# ----------------------------------

./system_util/start_statistics.sh -d $RESULTSDIR/system-util
echo "statistics started"

echo "beginning fio runs"
echo ""

for bs in "${block_sizes[@]}"s; do
  for nexec in "${nexecs[@]}"; do
    for rw in "${rws[@]}"; do
      echo "running fio with block size $bs, $nexec parallel requests and $rw for read/write setting"

      mkdir -p "$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/async/zram"
      mkdir -p "$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-sync/zram"
      mkdir -p "$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-mmap/zram"
      mkdir -p "$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/async/ssd"
      mkdir -p "$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-sync/ssd"
      mkdir -p "$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-mmap/ssd"

      # run zram configs

      SIZE="$size" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" fio config/timed-async.fio --output="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/async/zram/fio_out.txt" $testrunopt

      SIZE="$size" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="sync" fio config/timed-sync.fio --output="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-sync/zram/fio_out.txt" $testrunopt

      SIZE="$size" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="mmap" fio config/timed-sync.fio --output="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-mmap/zram/fio_out.txt" $testrunopt

      # run ssd configs

      SIZE="$size" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" fio config/timed-async.fio --output="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/async/ssd/fio_out.txt" $testrunopt

      SIZE="$size" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="sync" fio config/timed-sync.fio --output="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-sync/ssd/fio_out.txt" $testrunopt

      SIZE="$size" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="mmap" fio config/timed-sync.fio --output="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs/sync-mmap/ssd/fio_out.txt" $testrunopt

      echo "done"
      echo ""
    done
  done
done


./system_util/stop_statistics.sh -d $RESULTSDIR/system-util
echo "statistics ended"

./system_util/extract-data.sh -r $RESULTSDIR/system-util -d zram0 -d nvme0n1
echo "data extracted"
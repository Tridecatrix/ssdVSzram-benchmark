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

# ----------------------------------
# running things
# ----------------------------------

echo "beginning runs"
echo ""

for bs in "${block_sizes[@]}"s; do
  for nexec in "${nexecs[@]}"; do
    for rw in "${rws[@]}"; do
      echo "running fio with block size $bs, $nexec parallel requests and $rw for read/write setting"

      SUBDIR="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs"
      mkdir -p "$SUBDIR/async/zram"
      mkdir -p "$SUBDIR/sync-sync/zram"
      mkdir -p "$SUBDIR/async/ssd"
      mkdir -p "$SUBDIR/sync-sync/ssd"

      # run zram configs

      ./system_util/start_statistics.sh -d $SUBDIR/async/zram
      SIZE="$size" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" fio config/timed-async.fio --output="$SUBDIR/async/zram/fio_out.txt" $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/async/zram
      ./system_util/extract-data.sh -r $SUBDIR/async/zram -d zram0 -d nvme0n1

      ./system_util/start_statistics.sh -d $SUBDIR/sync-sync/zram
      SIZE="$size" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="sync" fio config/timed-sync.fio --output="$SUBDIR/sync-sync/zram/fio_out.txt" $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/sync-sync/zram
      ./system_util/extract-data.sh -r $SUBDIR/sync-sync/zram -d zram0 -d nvme0n1

      # run ssd configs

      ./system_util/start_statistics.sh -d $SUBDIR/async/ssd
      SIZE="$size" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" fio config/timed-async.fio --output="$SUBDIR/async/ssd/fio_out.txt" $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/async/ssd
      ./system_util/extract-data.sh -r $SUBDIR/async/ssd -d zram0 -d nvme0n1

      ./system_util/start_statistics.sh -d $SUBDIR/sync-sync/ssd
      SIZE="$size" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="sync" fio config/timed-sync.fio --output="$SUBDIR/sync-sync/ssd/fio_out.txt" $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/sync-sync/ssd
      ./system_util/extract-data.sh -r $SUBDIR/sync-sync/ssd -d zram0 -d nvme0n1


      # can't run mmap without a block size of 4096 bits
      if [[ $bs -eq 4096 ]]; then
        mkdir -p "$SUBDIR/sync-mmap/zram"
        mkdir -p "$SUBDIR/sync-mmap/ssd"

        ./system_util/start_statistics.sh -d $SUBDIR/sync-mmap/zram
        SIZE="$size" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="mmap" fio config/timed-sync.fio --output="$SUBDIR/sync-mmap/zram/fio_out.txt" $testrunopt
        ./system_util/stop_statistics.sh -d $SUBDIR/sync-mmap/zram
        ./system_util/extract-data.sh -r $SUBDIR/sync-mmap/zram -d zram0 -d nvme0n1

        ./system_util/start_statistics.sh -d $SUBDIR/sync-mmap/ssd
        SIZE="$size" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="mmap" fio config/timed-sync.fio --output="$SUBDIR/sync-mmap/ssd/fio_out.txt" $testrunopt
        ./system_util/stop_statistics.sh -d $SUBDIR/sync-mmap/ssd
        ./system_util/extract-data.sh -r $SUBDIR/sync-mmap/ssd -d zram0 -d nvme0n1
      fi

      echo "done"
      echo ""

      # clear job files
      rm $ZRAMdir/job-*
      rm $SSDdir/job-*
    done
  done
done


./system_util/stop_statistics.sh -d $RESULTSDIR/system-util
echo "statistics ended"

./system_util/extract-data.sh -r $RESULTSDIR/system-util -d zram0 -d nvme0n1
echo "data extracted"
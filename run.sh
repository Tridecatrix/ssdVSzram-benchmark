#!/bin/bash

# run this script with this command AFTER SETTING NECESSARY PARAMETERS BELOW: 
# nohup ./run.sh > data/log.txt & 2>&1

# ----------------------------------
# setup
# ----------------------------------

# set these before running
# - testrunopt can be set to --parse-only to disable fio from actually running
# - outputFormat is json by default
testrunopt=""
outputFormat="json"

# constants
totalSize=$((32 * 1024 * 1024 * 1024))
SSDdir="/mnt/ssd/adnan/bench"
ZRAMdir="/home/users/u7300623/SSDvsZRAM-fio/zrammount"

# options for other fio variables
block_sizes=(4096)
nexecs=(32 64)
rws=("read" "write" "rw" "randread" "randwrite" "randrw")
sync_ioengines=("sync" "mmap")

# assert that ZRAM is mounted
if grep -qs "/dev/zram0 ${ZRAMdir} " /proc/mounts; then
  echo "Verified that ZRAM is mounted."
else
  echo "ZRAM is not mounted on the specified directory; please fix."
  exit
fi

# assert that directories have correct permissions
if [ -d "$SSDdir" ] && [ -x "$SSDdir" ] && [ -d "$ZRAMdir" ] && [ -x "$ZRAMdir" ]; then
  echo "Verified that ZRAM and SSD directories exist and are accessible."
else
  echo "Permission issues with accessing ZRAM and SSD; please check."
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

# clear any existing job files in the directories
if [ -z $testrunopt ]; then
  rm $ZRAMdir/job-* 
  rm $SSDdir/job-* 
fi

# ----------------------------------
# running things
# ----------------------------------

echo "beginning runs"
echo ""

for bs in "${block_sizes[@]}"; do
  for nexec in "${nexecs[@]}"; do
    for rw in "${rws[@]}"; do
      echo "running fio with block size $bs, $nexec parallel requests and $rw for read/write setting"

      SUBDIR="$RESULTSDIR/fio/$rw/iodepth_$nexec/request_size_$bs"
      mkdir -p "$SUBDIR/async/zram"
      mkdir -p "$SUBDIR/sync-sync/zram"
      mkdir -p "$SUBDIR/async/ssd"
      mkdir -p "$SUBDIR/sync-sync/ssd"

      # run zram configs

      echo "running async on zram"

      ./system_util/start_statistics.sh -d $SUBDIR/async/zram
      SIZE="$totalSize" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" fio config/timed-async.fio --output="$SUBDIR/async/zram/fio_out.txt" --output-format=$outputFormat $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/async/zram
      ./system_util/extract-data.sh -r $SUBDIR/async/zram -d zram0 -d nvme0n1

      echo "running sync w/ syscall on zram"

      ./system_util/start_statistics.sh -d $SUBDIR/sync-sync/zram
      SIZE_PER_PROC="$(($totalSize / $nexec))" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="sync" fio config/timed-sync.fio --output="$SUBDIR/sync-sync/zram/fio_out.txt" --output-format=$outputFormat $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/sync-sync/zram
      ./system_util/extract-data.sh -r $SUBDIR/sync-sync/zram -d zram0 -d nvme0n1

      # run ssd configs

      echo "running async on ssd"

      ./system_util/start_statistics.sh -d $SUBDIR/async/ssd
      SIZE="$totalSize" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" fio config/timed-async.fio --output="$SUBDIR/async/ssd/fio_out.txt" --output-format=$outputFormat $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/async/ssd
      ./system_util/extract-data.sh -r $SUBDIR/async/ssd -d zram0 -d nvme0n1

      echo "running sync w/ syscall on ssd"

      ./system_util/start_statistics.sh -d $SUBDIR/sync-sync/ssd
      SIZE_PER_PROC="$(($totalSize / $nexec))" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="sync" fio config/timed-sync.fio --output="$SUBDIR/sync-sync/ssd/fio_out.txt" --output-format=$outputFormat $testrunopt
      ./system_util/stop_statistics.sh -d $SUBDIR/sync-sync/ssd
      ./system_util/extract-data.sh -r $SUBDIR/sync-sync/ssd -d zram0 -d nvme0n1


      # can't run mmap without a block size of 4096 bits
      if [[ $bs -ge 4096 ]]; then
        mkdir -p "$SUBDIR/sync-mmap/zram"
        mkdir -p "$SUBDIR/sync-mmap/ssd"

        echo "running sync w/ mmap on zram"

        ./system_util/start_statistics.sh -d $SUBDIR/sync-mmap/zram
        SIZE_PER_PROC="$(($totalSize / $nexec))" BS="$bs" DIR="$ZRAMdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="mmap" fio config/timed-sync.fio --output="$SUBDIR/sync-mmap/zram/fio_out.txt" --output-format=$outputFormat $testrunopt
        ./system_util/stop_statistics.sh -d $SUBDIR/sync-mmap/zram
        ./system_util/extract-data.sh -r $SUBDIR/sync-mmap/zram -d zram0 -d nvme0n1

        echo "running sync w/ mmap on ssd"

        ./system_util/start_statistics.sh -d $SUBDIR/sync-mmap/ssd
        SIZE_PER_PROC="$(($totalSize / $nexec))" BS="$bs" DIR="$SSDdir" N_PAR_REQUESTS="$nexec" RW="$rw" IOENGINE="mmap" fio config/timed-sync.fio --output="$SUBDIR/sync-mmap/ssd/fio_out.txt" --output-format=$outputFormat $testrunopt
        ./system_util/stop_statistics.sh -d $SUBDIR/sync-mmap/ssd
        ./system_util/extract-data.sh -r $SUBDIR/sync-mmap/ssd -d zram0 -d nvme0n1
      fi

      # clear job files
      echo "clearing job files"
      if [ -z $testrunopt ]; then
        rm $ZRAMdir/job-* 
        rm $SSDdir/job-* 
      fi

      echo "done"
      echo ""

    done
  done
done

echo "all runs done"
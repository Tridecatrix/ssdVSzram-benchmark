#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./run.sh > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# nohup ./run.sh | tee data/log.txt | ssh ctoo 'cat /dev/stdin > fioLog.txt' &

# ----------------------------------
# parameters
# ----------------------------------

# set these before running
# - testrunopt can be set to --parse-only to disable fio from actually running
# - outputFormat is json by default
testrunopt="--parse-only"
outputFormat="json"

# constants
totalSize=$((32 * 1024 * 1024 * 1024))
SSDdir="/mnt/ssd/adnan/bench"
ZRAMdir="/home/users/u7300623/SSDvsZRAM-fio/zrammount"

# options for other fio variables
block_sizes=(4096)
nprocs=(1 32 64)
iodepths=(64 128)
rws=("read" "write" "rw" "randread" "randwrite" "randrw")
sync_ioengines=("sync" "mmap")
async_ioengines=("libaio" "io_uring")

# ---------------------------------
# setup and pre-run checks
# ---------------------------------

# assert that nobody else is on the machine
# - note: based on how you're running the script, you may count as one of the users outputted as who;
#   in this case update below comparison to "$(($nusers-1)) -gt 0"
nusers=`who | wc -l`
if [[ $nusers -gt 0 ]]; then
  echo "Detected $nusers other users on the machine; aborting"
  exit
fi

# TODO: add check that no other processes are running
# - maybe filter output of top for processes with above 50% utilisation
# - ps u $(pgrep -v -u root) is a start but picks up the shell process that the user is running this script from,
# as well as a bunch of other random system processes

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
# print run config and zram config
# ----------------------------------

echo ""
echo "Parameters for this run:"
touch $RESULTSDIR/fio-config.txt
echo "Total file size during runs: $totalSize" | tee -a $RESULTSDIR/fio-config.txt
echo "Block sizes: ${block_sizes[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Numbers of processes: ${nprocs[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Read/write type options: ${rws[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Async I/O engines: ${async_ioengines[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Async I/O depths: ${iodepths[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Sync I/O engines: ${sync_ioengines[@]}" | tee -a $RESULTSDIR/fio-config.txt

# check ZRAM config parameters; print them to sout as well as recording them in a file in the resultdir
echo ""
echo "Zram config:"
zramctl | tee $RESULTSDIR/zram-config.txt
echo ""

# ----------------------------------
# running things
# ----------------------------------

echo "beginning runs"
echo ""

for bs in "${block_sizes[@]}"; do
  for nproc in "${nprocs[@]}"; do
    for rw in "${rws[@]}"; do
      echo "running fio with block size $bs, $nproc processes and $rw for read/write setting"

      SUBDIR="$RESULTSDIR/$rw/nproc-$nproc/request-size-$bs"

      # run async configs
      for ioengine in "${async_ioengines[@]}"; do
        for iodepth in "${iodepths[@]}"; do
          echo "running async (engine $ioengine, iodepth $iodepth) on zram"
          SUBSUBDIR="$SUBDIR/async-$ioengine/iodepth-$iodepth/zram"
          mkdir -p $SUBSUBDIR

          ./system_util/start_statistics.sh -d $SUBSUBDIR
          SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="$ZRAMdir" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" IODEPTH="$iodepth" fio config/async.fio --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
          ./system_util/stop_statistics.sh -d $SUBSUBDIR
          ./system_util/extract-data.sh -r $SUBSUBDIR -d zram0

          echo "running async (engine $ioengine, iodepth $iodepth) on ssd"
          SUBSUBDIR="$SUBDIR/async-$ioengine/iodepth-$iodepth/ssd"
          mkdir -p $SUBSUBDIR

          ./system_util/start_statistics.sh -d $SUBSUBDIR
          SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="$SSDdir" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" IODEPTH="$iodepth" fio config/async.fio --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
          ./system_util/stop_statistics.sh -d $SUBSUBDIR
          ./system_util/extract-data.sh -r $SUBSUBDIR -d nvme0n1

          ./clear_job_files.sh $ZRAMdir $SSDdir
        done
      done

      # run sync configs
      for ioengine in "${sync_ioengines[@]}"; do
        echo "running sync (engine $ioengine) on zram"
        SUBSUBDIR="$SUBDIR/sync-$ioengine/zram"
        mkdir -p $SUBSUBDIR

        ./system_util/start_statistics.sh -d $SUBSUBDIR
        SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="$ZRAMdir" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" fio config/sync.fio --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
        ./system_util/stop_statistics.sh -d $SUBSUBDIR
        ./system_util/extract-data.sh -r $SUBSUBDIR -d zram0

        echo "running sync (engine $ioengine) on ssd"
        SUBSUBDIR="$SUBDIR/sync-$ioengine/ssd"
        mkdir -p $SUBSUBDIR

        ./system_util/start_statistics.sh -d $SUBSUBDIR
        SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="$SSDdir" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" fio config/sync.fio --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
        ./system_util/stop_statistics.sh -d $SUBSUBDIR
        ./system_util/extract-data.sh -r $SUBSUBDIR -d zram0

        ./clear_job_files.sh $ZRAMdir $SSDdir
      done

      echo ""

    done
  done
done

echo "all runs done"
#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run.sh > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# nohup ./scripts/run.sh | tee data/log.txt | ssh ctoo 'cat /dev/stdin > fioLog.txt' &

# ----------------------------------
# parameters
# ----------------------------------

# set these before running
# - testrunopt can be set to --parse-only to disable fio from actually running
# - outputFormat is json by default
testrunopt=""
outputFormat="json"

# constants
totalSize=$((32 * 1024 * 1024 * 1024))
RAMdir="/mnt/mem"
HOMEdir="/home/users/u7300623/ssdVSzram-benchmark" # change to root directory of this repo
# note: to change which folder results are stored in, change RESULTSDIR further below

# options for other fio variables
block_sizes=(4096)
nprocs=(1 32 64 96)
iodepths=(64 128)
rws=("read" "write" "rw" "randread" "randwrite" "randrw")
sync_ioengines=("sync" "mmap")
async_ioengines=("libaio" "io_uring")

# ---------------------------------
# setup and pre-run checks
# ---------------------------------

cd $HOMEdir

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

# assert that directories exist
if [ -d "$RAMdir" ]; then
  echo "Verified the RAM directories exist"
else
  echo "RAM directories doesn't exist"
  exit
fi

if [ -x "$RAMdir" ]; then
  echo "Verified that RAM directories exist and are accessible."
else
  echo "Permission issues with accessing RAM; please check."
  exit
fi

# assert that RAM is mounted
if grep -qs "${RAMdir} tmpfs" /proc/mounts; then
  echo "Verified that RAM (tmpfs) is mounted."
else
  echo "Provided directory does not have a tmpfs mount on it; please fix."
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
  rm $RAMdir/job-*
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
          echo "running async (engine $ioengine, iodepth $iodepth) on ram"
          SUBSUBDIR="$SUBDIR/async-$ioengine/iodepth-$iodepth/ram"
          mkdir -p $SUBSUBDIR

          ./system_util/start_statistics.sh -d $SUBSUBDIR
          SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="$RAMdir" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" IODEPTH="$iodepth" fio config/async.fio --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
          ./system_util/stop_statistics.sh -d $SUBSUBDIR
          ./system_util/extract-data.sh -r $SUBSUBDIR -d tmpfs

          ./scripts/clear_job_files.sh $RAMdir $RAMdir
        done
      done

      # run sync configs
      for ioengine in "${sync_ioengines[@]}"; do
        echo "running sync (engine $ioengine) on ram"
        SUBSUBDIR="$SUBDIR/sync-$ioengine/ram"
        mkdir -p $SUBSUBDIR

        ./system_util/start_statistics.sh -d $SUBSUBDIR
        SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="$RAMdir" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" fio config/sync.fio --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
        ./system_util/stop_statistics.sh -d $SUBSUBDIR
        ./system_util/extract-data.sh -r $SUBSUBDIR -d tmpfs
      done

      echo ""

    done
  done
done

echo "all runs done"
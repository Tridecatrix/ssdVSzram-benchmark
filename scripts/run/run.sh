#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run/run.sh > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# stdbuf -oL nohup ./scripts/run/run.sh | tee data/log.txt | ssh ctoo 'cat /dev/stdin > fioLog.txt' & disown

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
HOMEdir=`git rev-parse --show-toplevel`

# device settings
dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/ssd0/adnan/bench" "$HOMEdir/zrammnt0-lzo" "$HOMEdir/zrammnt1-zstd" "$HOMEdir/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("nvme0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

# config file paths
sync_config="$HOMEdir/config/2025-07-10-no-NUMA-bind/sync.fio"
async_config="$HOMEdir/config/2025-07-10-no-NUMA-bind/async.fio"

# options for other fio variables
block_sizes=(4096 65536)
nprocs=(32 64)
iodepths=(128 2056)
rws=("read" "write" "rw" "randread" "randwrite" "randrw")
sync_ioengines=("sync" "mmap")
async_ioengines=("libaio" "io_uring")

EXPNAME=raven3-benchmark

RESULTSDIR=data/$(date +%F-time-%H-%M-%S)-$EXPNAME
mkdir -p $RESULTSDIR

# ---------------------------------
# setup and pre-run checks
# ---------------------------------

cd $HOMEdir

# assert that nobody else is on the machine
# - note: based on how you're running the script, you may count as one of the users outputted as who;
#   in this case update below comparison to "$(($nusers-1)) -gt 0"
# nusers=`who | wc -l`
# if [[ $nusers -gt 0 ]]; then
#   echo "Detected $nusers other users on the machine; aborting"
#   exit
# fi

# TODO: add check that no other processes are running
# - maybe filter output of top for processes with above 50% utilisation
# - ps u $(pgrep -v -u root) is a start but picks up the shell process that the user is running this script from,
# as well as a bunch of other random system processes


for di in ${!dev_names[@]}; do
  # assert that directories exist
  if [ ! -d "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, does not exist."
  fi

  # assert that directories are accessible
  if [ ! -x "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, is not accessible."
  fi

  # assert that the directories are mounted on correct devices
  if df ${dev_paths[$di]} | xargs grep -qs ${dev_names_sys[$di]}; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, is not mounted on the specified device."
  fi
done

echo "Completed pre-run checks; all directories specified were found, accessible and mounted on specified devices."

# ----------------------------------
# print run config and zram config
# ----------------------------------

echo ""
echo "Parameters for this run:"
touch $RESULTSDIR/fio-config.txt
echo "Devices: ${dev_names[@]}" | tee -a $RESULTSDIR/fio-config.txt
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
          for di in "${!dev_names[@]}"; do
            echo "running async (engine $ioengine, iodepth $iodepth) on ${dev_names[$di]}"
            SUBSUBDIR="$SUBDIR/async-$ioengine/iodepth-$iodepth/${dev_names[$di]}"
            mkdir -p $SUBSUBDIR

            echo "removing job files if they exist"
            rm -f ${dev_paths[$di]}/job-* 

            echo "`date +%F/%H:%M:%S:` beginning run"
            $HOMEdir/system_util/start_statistics.sh -d $SUBSUBDIR
            SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="${dev_paths[$di]}" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" IODEPTH="$iodepth" fio $async_config --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
            $HOMEdir/system_util/stop_statistics.sh -d $SUBSUBDIR
            $HOMEdir/system_util/extract-data.sh -r $SUBSUBDIR -d ${dev_names_iostat[$di]}

            echo "`date +%F/%H:%M:%S:` done"
          done
        done
      done

      # run sync configs
      for ioengine in "${sync_ioengines[@]}"; do
        for di in "${!dev_names[@]}"; do
          echo "running sync (engine $ioengine) on ${dev_names[$di]}"
          SUBSUBDIR="$SUBDIR/sync-$ioengine/${dev_names[$di]}"
          mkdir -p $SUBSUBDIR

          echo "removing job files if they exist"
          rm -f ${dev_paths[$di]}/job-* 

          echo "`date +%F/%H:%M:%S:`: beginning run"
          $HOMEdir/system_util/start_statistics.sh -d $SUBSUBDIR
          SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="${dev_paths[$di]}" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" fio $sync_config --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
          $HOMEdir/system_util/stop_statistics.sh -d $SUBSUBDIR
          $HOMEdir/system_util/extract-data.sh -r $SUBSUBDIR -d ${dev_names_iostat[$di]}

          echo "`date +%F/%H:%M:%S:`: done"
        done
      done

    echo ""
    done
  done
done

echo "all runs done"
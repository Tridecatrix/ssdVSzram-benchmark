#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run/specific/run-dump.sh > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# stdbuf -oL nohup ./scripts/run/specific/run-dump.sh | tee data/log.txt | ssh ctoo 'cat /dev/stdin > fioLog.txt' & disown

# ----------------------------------
# parameters
# ----------------------------------

# set these before running
# - testrunopt can be set to --parse-only to disable fio from actually running
# - outputFormat is json by default
testrunopt=""
outputFormat="json"

# constants
HOMEdir=`git rev-parse --show-toplevel`

# device settings
dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/ssd/adnan/bench" "$HOMEdir/zrammnt0-lzo" "$HOMEdir/zrammnt1-zstd" "$HOMEdir/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("nvme0c0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

# config file paths
sync_config="$HOMEdir/config/2025-03-27-run-dumps/sync.fio"

# options for other fio variables
block_sizes=(4096)
nprocs=(32)
#rws=("read" "write" "rw" "randread" "randwrite" "randrw")
rws=("read" "randread")
sync_ioengines=("mmap")

# dacapo benchmarks
dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"
dacapo_benchs=($dacapo_benchs)

# max number of dumps to run for each benchmark. used to avoid spending ages running fio on every dump.
maxdumps=5

EXPNAME=fourth-run-dumps

RESULTSDIR=data/$(date +%F-time-%H-%M-%S)-$EXPNAME
mkdir -p $RESULTSDIR

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


for di in ${!dev_names[@]}; do
  # assert that directories exist
  if [ ! -d "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_path[$di]}, does not exist."
  fi

  # assert that directories are accessible
  if [ ! -x "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_path[$di]}, is not accessible."
  fi

  # assert that the directories are mounted on correct devices
  if df ${dev_paths[$di]} | xargs grep -qs ${dev_names_sys[$di]}; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_path[$di]}, is not mounted on the specified device."
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
      for ioengine in "${sync_ioengines[@]}"; do
        for di in "${!dev_names[@]}"; do
          echo "running (engine $ioengine, nproc $nproc, bs $bs, rw $rw) on device ${dev_names[$di]}"
          SUBDIR="$RESULTSDIR/$rw/nproc-$nproc/request-size-$bs/sync-$ioengine/${dev_names[$di]}"

          # iterate through each heap dump, ignoring the first and last from each benchmark
          for bc in "${dacapo_benchs[@]}"; do
            ndumps=`find $HOMEdir/dumps -name $bc-*.hprof | wc -l`

            ndumpsToRun=$(( $maxdumps > $ndumps ? $ndumps : $maxdumps ))

            for i in `seq $ndumpsToRun`; do
              dumpi=$((($ndumps / $ndumpsToRun) * $i - 1)) 

              # remove any existing files
              find ${dev_paths[$di]}/* ! -name "lost+found" -exec rm -rf {} +

              # copy over the heap dump
              cp $HOMEdir/dumps/$bc-$dumpi.hprof ${dev_paths[$di]}
              DUMPFILE=${dev_paths[$di]}/$bc-$dumpi.hprof

              # run fio over the heap dump file

              echo "`date +%F/%H:%M:%S:`: running fio on heapdump $bc-$dumpi"
              SUBSUBDIR=$SUBDIR/$bc/dump-$dumpi
              mkdir -p $SUBSUBDIR

              $HOMEdir/system_util/start_statistics.sh -d $SUBSUBDIR
              BS="$bs" FILE="$DUMPFILE" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" fio $sync_config --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
              $HOMEdir/system_util/stop_statistics.sh -d $SUBSUBDIR
              $HOMEdir/system_util/extract-data.sh -r $SUBSUBDIR -d ${dev_names_iostat[$di]}
            done
          done
        done
      done
    done
  done
done

echo "all runs done"
#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run/specific/DEPRECATED-run-dump-sync-timed.sh > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# stdbuf -oL nohup ./scripts/run/specific/DEPRECATED-run-dump-sync-timed.sh | tee data-deprecated/log.txt | ssh ctoo 'cat /dev/stdin > fioLogDeprecated.txt' & disown

# ----------------------------------
# parameters
# ----------------------------------

# set these before running
# - testrunopt can be set to --parse-only to disable fio from actually running
# - outputFormat is json by default
testrunopt=""
outputFormat="json"

extend_dumpfile=false
extended_dumpfile_size=$((32 * 1024 * 1024 * 1024))

# constants
HOMEdir=`git rev-parse --show-toplevel`

# device settings
# dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
# dev_paths=("/mnt/ssd/adnan/bench" "$HOMEdir/zrammnt0-lzo" "$HOMEdir/zrammnt1-zstd" "$HOMEdir/zrammnt2-lz4") # paths where job files should be stored for each device
# dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
# dev_names_iostat=("nvme0c0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

dev_names=("zram0")
dev_paths=("$HOMEdir/zrammnt0-lzo")
dev_names_sys=("/dev/zram0")
dev_names_iostat=("zram0")

# config file paths
sync_config="$HOMEdir/config/2025-03-27-run-dumps/sync-timed.fio"

# options for other fio variables
block_sizes=(4096)
nprocs=(32)
#rws=("read" "write" "rw" "randread" "randwrite" "randrw")
rws=("read" "randread")
sync_ioengines=("sync")

# dacapo benchmarks
# dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"
dacapo_benchs="spring"
dacapo_benchs=($dacapo_benchs)

# max number of dumps to run for each benchmark. used to avoid spending ages running fio on every dump.
maxdumps=2

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
              find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null

              # copy over the heap dump
              cp $HOMEdir/dumps/$bc-$dumpi.hprof ${dev_paths[$di]}
              DUMPFILE=${dev_paths[$di]}/$bc-$dumpi.hprof

              if $extend_dumpfile; then
                echo "extending file"

                EXTENDEDDUMPFILE=${dev_paths[$di]}/$bc-$dumpi-ext.hprof
                cp $DUMPFILE $EXTENDEDDUMPFILE

                dumpsize=`du $EXTENDEDDUMPFILE -B1 | awk '{print $1}'`
                while [[ $dumpsize -lt $extended_dumpfile_size ]]; do
                  cat $DUMPFILE >> $EXTENDEDDUMPFILE
                  dumpsize=`du $EXTENDEDDUMPFILE -B1 | awk '{print $1}'`
                done

                echo "final size after going over required size: $dumpsize"
                if [[ $dumpsize -gt $extended_dumpfile_size ]]; then
                  truncate --size=$extended_dumpfile_size $EXTENDEDDUMPFILE
                fi
                echo "after truncating: $dumpsize"

                DUMPFILE=$EXTENDEDDUMPFILE
              fi

              # run fio over the heap dump file

              echo "`date +%F/%H:%M:%S:`: running fio on heapdump $bc-$dumpi"
              SUBSUBDIR=$SUBDIR/$bc/dump-$dumpi
              mkdir -p $SUBSUBDIR

              # get the dump's size (is passed to fio as offset_increment and io_size so that each process only does I/O on a particular
              # part of the file. Easier than duplicating the file and passing different files to each process.)
              dumpsize=`du $DUMPFILE -B1 | awk '{print $1}'`
              sizepp=$(($dumpsize / $nproc))

              # Start zram monitoring if this is a zram device
              ZRAM_PID=""
              if [[ ${dev_names_sys[$di]} == *"zram"* ]]; then
                echo "Starting zram monitoring for ${dev_names_sys[$di]}"
                $HOMEdir/scripts/misc/zram_usage.sh "$SUBSUBDIR/zram_usage.txt" "${dev_names_sys[$di]}" &
                ZRAM_PID=$!
              fi

              $HOMEdir/system_util/start_statistics.sh -d $SUBSUBDIR
              SIZE_PER_PROC="$sizepp" BS="$bs" FILE="$DUMPFILE" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" fio $sync_config --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
              $HOMEdir/system_util/stop_statistics.sh -d $SUBSUBDIR
              
              # Stop zram monitoring and parse results if monitoring was started
              if [[ -n "$ZRAM_PID" ]]; then
                echo "Stopping zram monitoring (PID: $ZRAM_PID)"
                kill $ZRAM_PID 2>/dev/null
                wait $ZRAM_PID 2>/dev/null
                
                # Parse zram results if the file exists
                if [[ -f "$SUBSUBDIR/zram_usage.txt" ]]; then
                  echo "Parsing zram results"
                  $HOMEdir/scripts/misc/parse_zram_results.sh "$SUBSUBDIR" > "$SUBSUBDIR/zram_parsed.csv"
                fi
              fi
              
              $HOMEdir/system_util/extract-data.sh -r $SUBSUBDIR -d ${dev_names_iostat[$di]}
            done
          done
        done
      done
    done
  done
done

echo "all runs done"
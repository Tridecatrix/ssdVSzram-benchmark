#!/bin/bash

HOMEdir=`git rev-parse --show-toplevel`
RESULTSDIR=$HOMEdir/data/$(date +%F-time-%H-%M-%S)-fourth-run-compression-ratio

mkdir -p $RESULTSDIR

# zram device settings
dev_names=("zram0" "zram1" "zram2") # (informal) device names
dev_paths=("$HOMEdir/zrammnt0-lzo" "$HOMEdir/zrammnt1-zstd" "$HOMEdir/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("zram0" "zram1" "zram2") # names of devices as given in output of iostat

# dacapo benchmarks
dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"
dacapo_benchs=($dacapo_benchs)

# iterate through each heap dump, ignoring the first and last from each benchmark
for bc in "${dacapo_benchs[@]}"; do
  ndumps=`find $HOMEdir/dumps -name $bc-*.hprof | wc -l`

  # ignore the last dump for each benchmark as it may occur after or as the benchmark is ending
  for i in `seq 0 $(($ndumps-2))`; do
    for di in ${!dev_names[@]}; do
      # Create device-specific subdirectories
      SUBDIR=$RESULTSDIR/$bc-$i/${dev_names[$di]}
      mkdir -p $SUBDIR

      # remove all files existing there except for lost+found, and issue fstrim
      find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null
      fstrim ${dev_paths[$di]}

      # Monitor zram usage during sleep to verify data has been cleared

      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage_during_sleep.txt ${dev_names_sys[$di]} &
      MONITORPID=$!
      sleep 10 # wait for the fstrim to register
      kill $MONITORPID

      # Collect zram usage before (should be mostly empty after cleanup)
      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage.txt ${dev_names_sys[$di]} --once

      # copy over the heap file and issue sync
      cp dumps/$bc-$i.hprof ${dev_paths[$di]}
      sync ${dev_paths[$di]}/$bc-$i.hprof

      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage_after_sync.txt ${dev_names_sys[$di]} &
      MONITORPID=$!
      sleep 5 # wait a bit to allow zram stats to stabilize
      kill $MONITORPID
      
      # Collect zram usage after copying the file
      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage.txt ${dev_names_sys[$di]} --once

      echo "`date +%F/%H:%M:%S:` analysed heap compression of dump $bc-$i for device ${dev_names[$di]}"
    done
  done
done
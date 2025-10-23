#!/bin/bash
# stdbuf -oL nohup ./scripts/misc/measure-compression-ratio.sh | tee log.txt | ssh ctoo 'cat /dev/stdin > fioLog'"$(hostname)"'.txt' & disown

HOMEdir=`git rev-parse --show-toplevel`
RESULTSDIR=$HOMEdir/data/$(date +%F-time-%H-%M-%S)-fourth-run-compression-ratio

mkdir -p $RESULTSDIR

# zram device settings
dev_names=("zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("zram0" "zram1" "zram2") # names of devices as given in output of iostat

# dacapo benchmarks
dacapo_benchs="h2"
dacapo_benchs=($dacapo_benchs)

maxdumps=5

# iterate through each heap dump, ignoring the first and last from each benchmark
for bc in "${dacapo_benchs[@]}"; do
  ndumps=$(find $HOMEdir/dumps -name $bc-*.hprof | wc -l)
  ndumpsToRun=$(( maxdumps > ndumps ? ndumps : maxdumps ))

  for i in $(seq $ndumpsToRun); do
    dumpi=$(( (ndumps / ndumpsToRun) * i - 1 ))

    # ignore the last dump for each benchmark as it may occur after or as the benchmark is ending
    for di in ${!dev_names[@]}; do
      # Create device-specific subdirectories
      SUBDIR=$RESULTSDIR/$bc-$dumpi/${dev_names[$di]}
      mkdir -p $SUBDIR

      echo "`date +%F/%H:%M:%S:` begin dump $bc-$dumpi for device ${dev_names[$di]}"

      # remove all files existing there except for lost+found, and issue fstrim
      find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null
      sudo fstrim ${dev_paths[$di]}

      # Monitor zram usage during sleep to verify data has been cleared

      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage_during_sleep.txt ${dev_names_sys[$di]} &
      MONITORPID=$!
      sleep 10 # wait for the fstrim to register
      kill $MONITORPID
      
      echo "`date +%F/%H:%M:%S:` cleared device"

      # Collect zram usage before (should be mostly empty after cleanup)
      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage.txt ${dev_names_sys[$di]} --once

      # copy over the heap file and issue sync
      cp dumps/$bc-$dumpi.hprof ${dev_paths[$di]}
      sync ${dev_paths[$di]}/$bc-$dumpi.hprof

      echo "`date +%F/%H:%M:%S:` copied dump"

      # Collect zram usage after copying the file
      $HOMEdir/scripts/misc/zram_usage.sh $SUBDIR/zram_usage.txt ${dev_names_sys[$di]} --once

      echo "`date +%F/%H:%M:%S:` analysed heap compression of dump $bc-$dumpi for device ${dev_names[$di]}"
    done
  done
done
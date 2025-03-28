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
    SUBRDIR=$RESULTSDIR/$bc-$i
    mkdir -p $SUBRDIR

    for di in ${!dev_names[@]}; do
      # remove all files existing there except for lost+found, and issue fstrim
      # (note this command is a little broken because it still tries to recurse into the subdirectory lost+found, dunno how to stop that)
      find ${dev_paths[$di]}/* ! -name "lost+found" -exec rm -rf {} +
      fstrim ${dev_paths[$di]}
    done

    zramctl > $SUBRDIR/before

    for di in ${!dev_names[@]}; do
      # copy over the heap file and issue sync
      cp dumps/$bc-$i.hprof ${dev_paths[$di]}
      sync ${dev_paths[$di]}/$bc-$i.hprof
    done

    zramctl > $SUBRDIR/after

    echo "`date +%F/%H:%M:%S:` analysed heap compression of dump $bc-$i"
  done
done
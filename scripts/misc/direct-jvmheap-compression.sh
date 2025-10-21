#!/bin/bash

# run command
# stdbuf -oL nohup ./scripts/misc/direct-jvmheap-compression.sh| tee log.txt | ssh ctoo 'cat /dev/stdin > fioLog'"$(hostname)"'.txt' & disown

# List of benchmarks:
# avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing

mkdir -p data/

dev_names=("zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device

benchmarks=$(java -jar dacapo.jar -l)
# benchmarks="xalan"

datetime=$(date +%F-time-%H-%M-%S)

for di in ${!dev_names[@]}; do
    for b in $benchmarks; do
        echo "$(date +%F-time-%H-%M-%S): running benchmark $b on ${dev_names[$di]}"

        rdir=data/$datetime-jvmheap-compression/$b/${dev_names[$di]}
        mkdir -p $rdir

        find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null
        sudo fstrim ${dev_paths[$di]}

        ./scripts/misc/zram_usage.sh $rdir/zram_usage.txt ${dev_names[$di]} &
        ZRAMUSAGEPID=$!

        java -XX:AllocateHeapAt=${dev_paths[$di]} -jar dacapo.jar $b -s large > $rdir/javalog.txt &
        JVMPID=$!

        jstat -gcutil $JVMPID 1000 > $rdir/jstat &

        while $(ps -p $JVMPID > /dev/null); do
            sleep 1
        done

        kill $ZRAMUSAGEPID
        ./scripts/misc/parse_zram_results.sh $rdir > $rdir/zram.csv

        echo "done"
    done
done
#!/bin/bash

# Command to run:
# nohup ./scripts/misc/generate-heap-dumps.sh | tee dumps/log.txt | ssh ctoo 'cat /dev/stdin > dumpLog.txt' &

# List of benchmarks:
# avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing

if [[ ! -z `find dumps -name *.hprof` ]]; then
    echo "Dumps folder contains existing dumps; please move them elsewhere before generating again."
    exit
fi

mkdir -p dumps

for b in `java -jar dacapo.jar -l`; do
    java -jar dacapo.jar $b -s large &
    JVMPID=$!

    nd=0
    while `ps -p $JVMPID > /dev/null`; do
        sleep 10
        jcmd $JVMPID GC.heap_dump dumps/$b-$nd.hprof
        nd=$((nd+1))
    done
done
#!/bin/bash

dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"
dacapo_benchs=($dacapo_benchs)

maxdumps=5

for bc in "${dacapo_benchs[@]}"; do
    ndumps=$(find dumps -name $bc-*.hprof | wc -l)
    ndumpsToRun=$(( maxdumps > ndumps ? ndumps : maxdumps ))

    for i in $(seq $ndumpsToRun); do
        dumpi=$(( (ndumps / ndumpsToRun) * i - 1 ))

        cp dumps/$bc-$dumpi.hprof reprdumps
    done
done

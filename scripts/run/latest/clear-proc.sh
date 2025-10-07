#!/bin/bash

# Author: Adnan Hasnat
# Clears all processes run as part of a fio run
# Useful for cleaning up if a Spark run is interrupted.

# kill run scripts
ps -u u7300623 -f | grep -E "scripts/run|scripts/misc" | awk '!/clear-proc/ && !/grep/ { \
    pid=$2; \
    if ($8 == "bash" || $8 ~ /\/bash$/) { \
        script_name = $9; \
        cmd = "bash " script_name; \
    } else { \
        cmd=""; \
        for(i=8; i<=NF; i++) cmd=cmd $i " "; \
    } \
    print pid, cmd \
}' | while read pid cmd; do
    if [[ $cmd == "grep" ]]; then
        continue; 
    fi
    echo "Killing run.sh process with PID $pid, CMD: $cmd"
    kill "$pid"
done

for proc in iostat mpstat fio; do
    pkill "$proc" && echo "Killed all $proc processes"
done
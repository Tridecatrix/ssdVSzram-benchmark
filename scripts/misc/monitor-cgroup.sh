#!/bin/bash

while true; do
    if ! cat /sys/fs/cgroup/$1/cgroup.procs; then
        break
    fi
    sleep 1
done
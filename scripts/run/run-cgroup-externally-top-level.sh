#!/bin/bash

memlims=("16M" "32M" "64M" "128M" "256M" "512M" "1G")

for memlim in "${memlims[@]}"; do
    sudo cgexec -g memory:memlim/$memlim ./scripts/run-cgroup-externally.sh | tee -a data/log.txt
done
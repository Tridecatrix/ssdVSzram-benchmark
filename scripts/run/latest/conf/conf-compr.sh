#!/bin/bash

# Configuration file for compressibility-raven3.sh
# This file sets the environment variables needed for the benchmark run

# ----------------------------------
# Basic run options
# ----------------------------------

# testrunopt can be set to --parse-only to disable fio from actually running
testrunopt=""

# outputFormat is json by default
outputFormat="json"

# total size for the benchmark (32GB default)
totalSize=$((4 * 1024 * 1024 * 1024))

# ----------------------------------
# Device settings
# ----------------------------------

# device settings (comment/uncomment as needed)
dev_names=("zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("zram0" "zram1" "zram2") # names of devices as given in output of iostat

# alternative device settings including SSD (uncomment to use)
# dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
# dev_paths=("/mnt/ssd0/adnan" "/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device
# dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
# dev_names_iostat=("nvme0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

# ----------------------------------
# Config file paths (will be resolved after HOMEdir is set)
# ----------------------------------

# These will use HOMEdir which gets set by the main script
sync_config_path="config/2025-10-05-FINAL-RUN/sync-compressible.fio"
async_config_path="config/2025-10-05-FINAL-RUN/async-compressible.fio"

# ----------------------------------
# Benchmark parameters
# ----------------------------------

# NUMA settings
numa=all

# Block sizes to test
block_sizes=(65536)

# Number of processes
nprocs=(1)

# IO depths (empty for sync ioengines)
iodepths=()

# Read/write patterns
rws=("read" "write")

# IO engines
sync_ioengines=("sync")
async_ioengines=()

# Compression percentages to test
compress_percentages=(0 10 20 30 40 50 60 70 80 90 100)

# ----------------------------------
# Experiment naming
# ----------------------------------

# Optional: customize experiment name
# EXPNAME=compressible-question-mark
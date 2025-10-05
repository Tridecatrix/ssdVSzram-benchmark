#!/bin/bash

# Configuration file example for SSD + ZRAM testing
# This file sets the environment variables needed for the benchmark run

# ----------------------------------
# Basic run options
# ----------------------------------

# testrunopt can be set to --parse-only to disable fio from actually running
testrunopt=""

# outputFormat is json by default
outputFormat="json"

# total size for the benchmark
totalSize=$((16 * 1024 * 1024 * 1024))

# ----------------------------------
# Device settings - SSD + ZRAM
# ----------------------------------

dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/ssd0/adnan" "/mnt/zrammnt0-lzo" "/mnt/zrammnt1-zstd" "/mnt/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("nvme0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

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

# IO depths (for async ioengines)
iodepths=(1 4 16 32 64 128 256)

# Read/write patterns
rws=("read" "write" "randread" "randwrite")

# IO engines
sync_ioengines=()
async_ioengines=("io_uring")

# Compression percentages to test (subset for faster testing)
compress_percentages=(50)

# ----------------------------------
# Experiment naming
# ----------------------------------

# Optional: customize experiment name
EXPNAME=async-perf
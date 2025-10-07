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
totalSize=$((8 * 1024 * 1024 * 1024))

# ----------------------------------
# Device settings
# ----------------------------------

# alternative device settings including SSD (uncomment to use)
dev_names=("ssd") # (informal) device names
dev_paths=("/mnt/ssd0/adnan") # paths where job files should be stored for each device
dev_names_sys=("/dev/nvme0n1") # paths to device files for each device
dev_names_iostat=("nvme0n1") # names of devices as given in output of iostat

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
iodepths=(21)

# Read/write patterns
rws=("randrw")

# IO engines
sync_ioengines=()
async_ioengines=("aio")

# Compression percentages to test
compress_percentages=(80)

# ----------------------------------
# Experiment naming
# ----------------------------------

# Optional: customize experiment name
EXPNAME=test
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
totalSize=$((32 * 1024 * 1024 * 1024))

# ----------------------------------
# Device settings - SSD + ZRAM
# ----------------------------------

dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names

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
block_sizes=(64K)

# Number of processes
nprocs=(1 2 4 8 16 32 64)

# IO depths (for async ioengines)
iodepths=()

# Read/write patterns
rws=("read" "write" "randread" "randwrite")

# IO engines
sync_ioengines=("sync")
async_ioengines=()

# Compression percentages to test (subset for faster testing)
compress_percentages=(50)

# ----------------------------------
# Experiment naming
# ----------------------------------

# Optional: customize experiment name
EXPNAME=process-scaling
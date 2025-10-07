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
dev_names=("ssd" "zram0") # (informal) device names

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
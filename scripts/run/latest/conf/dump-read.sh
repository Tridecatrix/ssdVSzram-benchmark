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

dev_names=("ssd" "zram0" "zram1" "zram2" "ram") # (informal) device names

# ----------------------------------
# Config file paths (will be resolved after HOMEdir is set)
# ----------------------------------

# These will use HOMEdir which gets set by the main script
config_1proc_path="config/2025-10-05-FINAL-RUN/sync-dump-read-1-proc.fio"
config_64proc_path="config/2025-10-05-FINAL-RUN/sync-dump-read-64-proc.fio"

# ----------------------------------
# Benchmark parameters
# ----------------------------------

# NUMA settings
numa=all

# Block sizes to test
block_sizes=(64K)

# IO depths (for async ioengines) - not used for sync-only configs
iodepths=()

# Number of processes
nprocs=(1 64)

# Read/write patterns
rws=("read")

# IO engines
sync_ioengines=("sync")
async_ioengines=()

# Dumps
dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"
dacapo_benchs=($dacapo_benchs)
maxdumps=2

# ----------------------------------
# Experiment naming
# ----------------------------------

# Optional: customize experiment name
EXPNAME=dump-read
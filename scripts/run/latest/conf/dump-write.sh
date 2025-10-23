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
totalSize=$((32 * 1024 * 1024 * 1024))

# ----------------------------------
# Device settings
# ----------------------------------

# alternative device settings including SSD (uncomment to use)
dev_names=("zram0" "zram1" "zram2") # (informal) device names

# ----------------------------------
# Config file paths (will be resolved after HOMEdir is set)
# ----------------------------------

# These will use HOMEdir which gets set by the main script
sync_config_path="config/2025-10-05-FINAL-RUN/sync-dump-write.fio"
async_config_path="config/2025-10-05-FINAL-RUN/async-dump-write.fio"

# ----------------------------------
# Benchmark parameters
# ----------------------------------

# NUMA settings
numa=all

# Block sizes to test
block_sizes=100M

# Number of processes
nprocs=(1 `nproc --all`)

# IO depths (empty for sync ioengines)
iodepths=()

# Read/write patterns
rws=("write")

# IO engines
sync_ioengines=("sync")
async_ioengines=()

# Dumps
dacapo_benchs="avrora batik biojava cassandra eclipse fop graphchi h2 h2o jme jython kafka luindex lusearch pmd spring sunflow tomcat tradebeans tradesoap xalan zxing"
dacapo_benchs=($dacapo_benchs)
maxdumps=1

# ----------------------------------
# Experiment naming
# ----------------------------------

# Optional: customize experiment name
EXPNAME=dump-write
# Compressibility Benchmark Configuration

This directory contains the compressibility benchmark script and configuration files.

## Usage

The `compressibility-raven3.sh` script now requires a configuration file as a command line argument:

```bash
./scripts/run/latest/compressibility-raven3.sh <config_file.sh>
```

## Configuration Files

### Available Configuration Files

1. **`conf.sh`** - Default ZRAM-only configuration
   - Tests only ZRAM devices (zram0, zram1, zram2) 
   - 32GB total size
   - Full compression percentage range (0-100%)
   - Basic block size and process configuration

2. **`conf-ssd-zram.sh`** - SSD + ZRAM comparison configuration
   - Tests SSD and all ZRAM devices
   - 16GB total size (faster testing)
   - Multiple block sizes, process counts, and IO depths
   - Subset of compression percentages for faster testing

### Creating Custom Configuration Files

Create a new shell script that sets the required environment variables:

```bash
#!/bin/bash

# Required variables:
dev_names=("device1" "device2")                    # Device names
dev_paths=("/path1" "/path2")                     # Mount paths  
dev_names_sys=("/dev/device1" "/dev/device2")     # System device paths
dev_names_iostat=("device1" "device2")           # iostat device names
sync_config_path="config/path/to/sync.fio"       # Sync FIO config (relative to repo root)
async_config_path="config/path/to/async.fio"     # Async FIO config (relative to repo root)
numa="all"                                        # NUMA setting
block_sizes=(4096 65536)                         # Block sizes to test
nprocs=(1)                                        # Number of processes
rws=("read" "write")                             # Read/write patterns
sync_ioengines=("sync")                          # Sync IO engines
compress_percentages=(0 50 100)                 # Compression percentages

# Optional variables (defaults will be used if not set):
testrunopt=""                                     # FIO test options (e.g., "--parse-only")
outputFormat="json"                              # Output format
totalSize=$((32 * 1024 * 1024 * 1024))          # Total size in bytes
iodepths=()                                      # IO depths (for async)
async_ioengines=()                               # Async IO engines
```

### Variable Descriptions

- **Device Arrays**: All device arrays must have the same length and correspond to each other by index
- **Config Paths**: Use relative paths from the repository root (HOMEdir will be prepended automatically)
- **Compression Percentages**: Range from 0 (incompressible) to 100 (highly compressible)
- **Block Sizes**: In bytes (e.g., 4096 = 4KB, 65536 = 64KB, 1048576 = 1MB)
- **NUMA**: CPU node binding ("all" or specific node numbers)

## Example Commands

```bash
# Run with default ZRAM configuration
nohup ./scripts/run/latest/compressibility-raven3.sh scripts/run/latest/conf.sh > data/log.txt 2>&1 &

# Run with SSD+ZRAM comparison configuration  
nohup ./scripts/run/latest/compressibility-raven3.sh scripts/run/latest/conf-ssd-zram.sh > data/log.txt 2>&1 &

# Test configuration without running FIO (dry run)
# First create a test config with testrunopt="--parse-only"
./scripts/run/latest/compressibility-raven3.sh my-test-conf.sh
```

## Migration from Old Script

The old hardcoded parameters have been moved to configuration files. To migrate:

1. Copy your existing parameter values from the old script
2. Create a new configuration file with those values
3. Use the new command syntax with your configuration file

This allows multiple configuration presets and easier parameter management without modifying the main script.
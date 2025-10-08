#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <config_file.sh> <devicemap.sh>"
    echo "  config_file.sh: Path to shell script containing configuration parameters"
    echo "  devicemap.sh: Path to shell script containing device mappings"
    exit 1
fi

CONFIG_FILE="$1"
DEVICEMAP_FILE="$2"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found"
    exit 1
fi
if [ ! -f "$DEVICEMAP_FILE" ]; then
    echo "Error: Device map file '$DEVICEMAP_FILE' not found"
    exit 1
fi

# constants
EXPNAME=misc-exp   # default
HOMEdir=`git rev-parse --show-toplevel`

# Source the configuration file to load parameters
echo "Loading device map from: $DEVICEMAP_FILE"
source "$DEVICEMAP_FILE"

# Save the device map arrays before they get overwritten
devicemap_dev_names=("${dev_names[@]}")
devicemap_dev_paths=("${dev_paths[@]}")
devicemap_dev_names_sys=("${dev_names_sys[@]}")
devicemap_dev_names_iostat=("${dev_names_iostat[@]}")

echo "Loading configuration from: $CONFIG_FILE"
source "$CONFIG_FILE"  # Note: dev_names will be overwritten by contents from this file.
                       # This is intentional: the config file should specify which devices to use.
                       # While the devicemap file specifies the paths for those devices.

# Now map the config devices to their corresponding devicemap entries
config_dev_names=("${dev_names[@]}")
mapped_dev_paths=()
mapped_dev_names_sys=()
mapped_dev_names_iostat=()

echo "Mapping config devices to devicemap entries:"
for config_dev in "${config_dev_names[@]}"; do
    found=false
    for i in "${!devicemap_dev_names[@]}"; do
        if [[ "${devicemap_dev_names[$i]}" == "$config_dev" ]]; then
            mapped_dev_paths+=("${devicemap_dev_paths[$i]}")
            mapped_dev_names_sys+=("${devicemap_dev_names_sys[$i]}")
            mapped_dev_names_iostat+=("${devicemap_dev_names_iostat[$i]}")
            echo "  $config_dev -> ${devicemap_dev_paths[$i]} (sys: ${devicemap_dev_names_sys[$i]}, iostat: ${devicemap_dev_names_iostat[$i]})"
            found=true
            break
        fi
    done
    if [[ "$found" == false ]]; then
        echo "Error: Device '$config_dev' specified in config file not found in device map"
        echo "Available devices in device map: ${devicemap_dev_names[*]}"
        exit 1
    fi
done

# Replace the original arrays with the mapped ones
dev_paths=("${mapped_dev_paths[@]}")
dev_names_sys=("${mapped_dev_names_sys[@]}")
dev_names_iostat=("${mapped_dev_names_iostat[@]}")

# Construct config file paths if they were set as relative paths
if [ -n "$sync_config_path" ]; then
    sync_config="$HOMEdir/$sync_config_path"
elif [ -z "$sync_config" ]; then
    echo "Error: Neither sync_config nor sync_config_path is set in config file"
    exit 1
fi

if [ -n "$async_config_path" ]; then
    async_config="$HOMEdir/$async_config_path"
elif [ -z "$async_config" ]; then
    echo "Error: Neither async_config nor async_config_path is set in config file"
    exit 1
fi

# ----------------------------------
# parameters
# ----------------------------------

# The following parameters should now be set by the sourced config file:
# testrunopt, outputFormat, totalSize, dev_names, dev_paths, dev_names_sys,
# dev_names_iostat, sync_config, async_config, numa, block_sizes, nprocs,
# iodepths, rws, sync_ioengines, async_ioengines, compress_percentages

# Validate that required variables are set
required_vars=("dev_names" "dev_paths" "dev_names_sys" "dev_names_iostat" "sync_config" "async_config" "numa" "block_sizes" "nprocs" "rws" "compress_percentages")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "Error: The following required variables are not set in the config file:"
    printf '  %s\n' "${missing_vars[@]}"
    echo "Please check your configuration file: $CONFIG_FILE"
    exit 1
fi

# Additional validation for ioengines and iodepths
validation_errors=()

# Check that at least one of sync_ioengines or async_ioengines is provided
if [ ${#sync_ioengines[@]} -eq 0 ] && [ ${#async_ioengines[@]} -eq 0 ]; then
    validation_errors+=("At least one of sync_ioengines or async_ioengines must be provided")
fi

# Check that if async_ioengines are provided, iodepths must also be provided
if [ ${#async_ioengines[@]} -gt 0 ] && [ ${#iodepths[@]} -eq 0 ]; then
    validation_errors+=("iodepths must be provided when async_ioengines are specified")
fi

if [ ${#validation_errors[@]} -gt 0 ]; then
    echo "Error: Configuration validation failed:"
    printf '  %s\n' "${validation_errors[@]}"
    echo "Please check your configuration file: $CONFIG_FILE"
    exit 1
fi

# Set default values for optional variables if not set
: ${testrunopt:=""}
: ${outputFormat:="json"}
: ${totalSize:=$((32 * 1024 * 1024 * 1024))}

# ---------------------------------
# setup and pre-run checks
# ---------------------------------

cd $HOMEdir

# assert that nobody else is on the machine
# - note: based on how you're running the script, you may count as one of the users outputted as who;
#   in this case update below comparison to "$(($nusers-1)) -gt 0"
# nusers=`who | wc -l`
# if [[ $nusers -gt 0 ]]; then
#   echo "Detected $nusers other users on the machine; aborting"
#   exit
# fi

# TODO: add check that no other processes are running
# - maybe filter output of top for processes with above 50% utilisation
# - ps u $(pgrep -v -u root) is a start but picks up the shell process that the user is running this script from,
# as well as a bunch of other random system processes


for di in ${!dev_names[@]}; do
  # assert that directories exist
  if [ ! -d "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, does not exist."
    exit
  fi

  # assert that directories are accessible
  if [ ! -x "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, is not accessible."
    exit
  fi

  # assert that the directories are mounted on correct devices
  if df ${dev_paths[$di]} | xargs grep -qs ${dev_names_sys[$di]}; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, is not mounted on the specified device."
    exit
  fi

  # assert that the SparkBench directory is not present
  if [ -d "${dev_paths[$di]}/SparkBench" ]; then
    echo "Device ${dev_names[$di]} has spark bench directory; aborting as it will be deleted by experiment otherwise"
    exit
  fi
done

echo "Completed pre-run checks; all directories specified were found, accessible and mounted on specified devices."
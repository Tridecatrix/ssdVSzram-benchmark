#!/bin/bash

CONFIG_FILE=$1

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found"
    exit 1
fi

# constants
HOMEdir=`git rev-parse --show-toplevel`

# Source the configuration file to load parameters
echo "Loading configuration from: $CONFIG_FILE"
source "$CONFIG_FILE"

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
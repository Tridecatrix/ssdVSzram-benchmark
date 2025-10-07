#!/bin/bash

DEVICEMAP_FILE=$1

if [ -z "$DEVICEMAP_FILE" ]; then
    echo "Usage: $0 <devicemap-file> [config-file]"
    exit 1
fi

if [ ! -f "$DEVICEMAP_FILE" ]; then
    echo "Error: Device map file '$DEVICEMAP_FILE' not found!"
    exit 1
fi

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

echo "Device map checks passed; all directories specified were found, accessible and mounted on specified devices."
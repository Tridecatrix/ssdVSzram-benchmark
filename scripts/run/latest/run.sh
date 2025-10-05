#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run/latest/run.sh <config_file.sh> > data-raven3/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# stdbuf -oL nohup ./scripts/run/latest/run.sh <config_file.sh> | tee data-raven3/log.txt | ssh ctoo 'cat /dev/stdin > fioLog.txt' & disown
# stdbuf -oL nohup ./scripts/run/latest/run.sh ./scripts/run/latest/conf-async.sh | tee data-raven3/log.txt | ssh ctoo 'cat /dev/stdin > fioLog.txt' & disown

# ----------------------------------
# command line arguments
# ----------------------------------

if [ $# -ne 1 ]; then
    echo "Usage: $0 <config_file.sh>"
    echo "  config_file.sh: Path to shell script containing configuration parameters"
    exit 1
fi

CONFIG_FILE="$1"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found"
    exit 1
fi

# Source the configuration file to load parameters
echo "Loading configuration from: $CONFIG_FILE"
source "$CONFIG_FILE"

# constants
HOMEdir=`git rev-parse --show-toplevel`

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

EXPNAME=compressibile-question-mark

RESULTSDIR=data-raven3/$(date +%F-time-%H-%M-%S)-$EXPNAME
mkdir -p $RESULTSDIR

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

# ----------------------------------
# print run config and zram config
# ----------------------------------

echo ""
echo "Parameters for this run:"
touch $RESULTSDIR/fio-config.txt
echo "Devices: ${dev_names[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Total file size during runs: $totalSize" | tee -a $RESULTSDIR/fio-config.txt
echo "Block sizes: ${block_sizes[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Numbers of processes: ${nprocs[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Read/write type options: ${rws[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Async I/O engines: ${async_ioengines[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Async I/O depths: ${iodepths[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Sync I/O engines: ${sync_ioengines[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Compression percentages: ${compress_percentages[@]}" | tee -a $RESULTSDIR/fio-config.txt

# check ZRAM config parameters; print them to sout as well as recording them in a file in the resultdir
echo ""
echo "Zram config:"
zramctl --output-all | tee $RESULTSDIR/zram-config.txt
echo ""

# ----------------------------------
# running things
# ----------------------------------

echo "beginning runs"
echo ""

for compress_pct in "${compress_percentages[@]}"; do
  echo "running with compression percentage: $compress_pct%"
  
  for bs in "${block_sizes[@]}"; do
    for nproc in "${nprocs[@]}"; do
      for rw in "${rws[@]}"; do
        echo "running fio with block size $bs, $nproc processes, $rw for read/write setting, and $compress_pct% compression"

        SUBDIR="$RESULTSDIR/$rw/nproc-$nproc/request-size-$bs/compress-$compress_pct"

      # run async configs
      for ioengine in "${async_ioengines[@]}"; do
        for iodepth in "${iodepths[@]}"; do
          for di in "${!dev_names[@]}"; do
            echo "running async (engine $ioengine, iodepth $iodepth) on ${dev_names[$di]}"
            SUBSUBDIR="$SUBDIR/async-$ioengine/iodepth-$iodepth/${dev_names[$di]}"
            mkdir -p $SUBSUBDIR

            echo "$(date +%F/%H:%M:%S) Removing any existing files from ${dev_paths[$di]}"
            find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null

            # Start zram monitoring if this is a zram device
            ZRAM_PID=""
            if [[ ${dev_names_sys[$di]} == *"zram"* ]]; then
              echo "Starting zram monitoring for ${dev_names_sys[$di]}"
              $HOMEdir/scripts/misc/zram_usage.sh "$SUBSUBDIR/zram_usage.txt" "${dev_names_sys[$di]}" &
              ZRAM_PID=$!
            fi

            echo "`date +%F/%H:%M:%S:` beginning run"
            $HOMEdir/system_util/start_statistics.sh -d $SUBSUBDIR
            SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="${dev_paths[$di]}" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" IODEPTH="$iodepth" NUMA="$numa" CMPR_PNT="$compress_pct" fio $async_config --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
            $HOMEdir/system_util/stop_statistics.sh -d $SUBSUBDIR
            
            # Stop zram monitoring and parse results if monitoring was started
            if [[ -n "$ZRAM_PID" ]]; then
              echo "Stopping zram monitoring (PID: $ZRAM_PID)"
              kill $ZRAM_PID 2>/dev/null
              wait $ZRAM_PID 2>/dev/null
              
              # Parse zram results if the file exists
              if [[ -f "$SUBSUBDIR/zram_usage.txt" ]]; then
                echo "Parsing zram results"
                $HOMEdir/scripts/misc/parse_zram_results.sh "$SUBSUBDIR" > "$SUBSUBDIR/zram_parsed.csv"
              fi
            fi
            
            $HOMEdir/system_util/extract-data.sh -r $SUBSUBDIR -d ${dev_names_iostat[$di]}

            echo "`date +%F/%H:%M:%S:` done"
          done
        done
      done

      # run sync configs
      for ioengine in "${sync_ioengines[@]}"; do
        for di in "${!dev_names[@]}"; do
          echo "running sync (engine $ioengine) on ${dev_names[$di]}"
          SUBSUBDIR="$SUBDIR/sync-$ioengine/${dev_names[$di]}"
          mkdir -p $SUBSUBDIR

          echo "$(date +%F/%H:%M:%S) Removing any existing files from ${dev_paths[$di]}"
          find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null

          # Start zram monitoring if this is a zram device
          ZRAM_PID=""
          if [[ ${dev_names_sys[$di]} == *"zram"* ]]; then
            echo "Starting zram monitoring for ${dev_names_sys[$di]}"
            $HOMEdir/scripts/misc/zram_usage.sh "$SUBSUBDIR/zram_usage.txt" "${dev_names_sys[$di]}" &
            ZRAM_PID=$!
          fi

          echo "`date +%F/%H:%M:%S:`: beginning run"
          $HOMEdir/system_util/start_statistics.sh -d $SUBSUBDIR
          SIZE_PER_PROC="$(($totalSize/$nproc))" BS="$bs" DIR="${dev_paths[$di]}" NPROC="$nproc" RW="$rw" IOENGINE="$ioengine" NUMA="$numa" CMPR_PNT="$compress_pct" fio $sync_config --output="$SUBSUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
          $HOMEdir/system_util/stop_statistics.sh -d $SUBSUBDIR
          
          # Stop zram monitoring and parse results if monitoring was started
          if [[ -n "$ZRAM_PID" ]]; then
            echo "Stopping zram monitoring (PID: $ZRAM_PID)"
            kill $ZRAM_PID 2>/dev/null
            wait $ZRAM_PID 2>/dev/null
            
            # Parse zram results if the file exists
            if [[ -f "$SUBSUBDIR/zram_usage.txt" ]]; then
              echo "Parsing zram results"
              $HOMEdir/scripts/misc/parse_zram_results.sh "$SUBSUBDIR" > "$SUBSUBDIR/zram_parsed.csv"
            fi
          fi
          
          $HOMEdir/system_util/extract-data.sh -r $SUBSUBDIR -d ${dev_names_iostat[$di]}

          echo "`date +%F/%H:%M:%S:`: done"
        done
      done

      echo ""
      done
    done
  done
done

echo "all runs done"
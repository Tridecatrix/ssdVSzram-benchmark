#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run/latest/run-dump-read.sh <config_file.sh> <devicemap.sh> > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# DMAP=?    <- put this in bashrc with the device mapping file
# CONF=?    <-  replace ? with conf you want to run
# stdbuf -oL nohup ./scripts/run/latest/run-dump.sh $CONF $DMAP | tee log.txt | ssh ctoo 'cat /dev/stdin > fioLog'"$(hostname)"'.txt' & disown

# ----------------------------------
# command line arguments
# ----------------------------------

if [ $# -ne 2 ]; then
    echo "Usage: $0 <config_file.sh> <devicemap.sh>"
    echo "  config_file.sh: Path to shell script containing configuration parameters"
    echo "  devicemap.sh: Path to shell script containing device mappings (and result dir for server)"
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
EXPNAME=dump-exp   # default
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
if [ -n "$config_1proc_path" ]; then
    config_1proc="$HOMEdir/$config_1proc_path"
elif [ -z "$config_1proc" ]; then
    echo "Error: Neither config_1proc nor config_1proc_path is set in config file"
    exit 1
fi

if [ -n "$config_64proc_path" ]; then
    config_64proc="$HOMEdir/$config_64proc_path"
elif [ -z "$config_64proc" ]; then
    echo "Error: Neither config_64proc nor config_64proc_path is set in config file"
    exit 1
fi

# ----------------------------------
# parameters
# ----------------------------------

# The following parameters should now be set by the sourced config file:
# testrunopt, outputFormat, totalfilesize, dev_names, dev_paths, dev_names_sys,
# dev_names_iostat, config_1proc, config_64proc, block_sizes, rws, sync_ioengines,
# dacapo_benchs, maxdumps

# Validate that required variables are set
required_vars=("dev_names" "dev_paths" "dev_names_sys" "dev_names_iostat" "config_1proc" "config_64proc" "block_sizes" "nprocs" "rws" "sync_ioengines" "dacapo_benchs" "maxdumps")
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

# Set default values for optional variables if not set
: ${testrunopt:=""}
: ${outputFormat:="json"}
: ${totalfilesize:=$((32 * 1024 * 1024 * 1024))}

RESULTSDIR=$RESULTSDIR/$(date +%F-time-%H-%M-%S)-$EXPNAME
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
done

echo "Completed pre-run checks; all directories specified were found, accessible and mounted on specified devices."

# ----------------------------------
# print run config and zram config
# ----------------------------------

echo ""
echo "Parameters for this run:"
touch $RESULTSDIR/fio-config.txt
echo "Devices: ${dev_names[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Total file size during runs: $totalfilesize" | tee -a $RESULTSDIR/fio-config.txt
echo "Block sizes: ${block_sizes[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Number of processes: ${nprocs[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Read/write type options: ${rws[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Sync I/O engines: ${sync_ioengines[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "1-process config: $config_1proc" | tee -a $RESULTSDIR/fio-config.txt
echo "64-process config: $config_64proc" | tee -a $RESULTSDIR/fio-config.txt
echo "Dacapo benchmarks used: ${dacapo_benchs[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Number of dumps per bench: $maxdumps" | tee -a $RESULTSDIR/fio-config.txt

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

for di in "${!dev_names[@]}"; do
  for bc in "${dacapo_benchs[@]}"; do
    echo "==================== $(date +%F/%H:%M:%S) Starting benchmark $bc on device ${dev_names[$di]} ===================="
    ndumps=$(find $HOMEdir/dumps -name $bc-*.hprof | wc -l)
    ndumpsToRun=$(( maxdumps > ndumps ? ndumps : maxdumps ))

    for i in $(seq $ndumpsToRun); do
      dumpi=$(( (ndumps / ndumpsToRun) * (i - 1) ))

      echo "$(date +%F/%H:%M:%S) Preparing heapdump $bc-$dumpi on device ${dev_names[$di]}"

      # 1. Remove any existing files for this device
      echo "$(date +%F/%H:%M:%S) Removing any existing files from ${dev_paths[$di]}"
      find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null

      for nproc in "${nprocs[@]}"; do
        # Determine which config to use based on process count
        if [ "$nproc" -eq 1 ]; then
          fio_config="$config_1proc"
          config_name="1proc"
        elif [ "$nproc" -eq 64 ]; then
          fio_config="$config_64proc"
          config_name="64proc"
        else
          echo "Error: No FIO config available for $nproc processes"
          exit 1
        fi

        # Split and extend the heap dump for this specific process count and benchmark
        echo "$(date +%F/%H:%M:%S) Splitting and extending file into $nproc parts"
        $HOMEdir/scripts/misc/split-n-extend.sh $HOMEdir/dumps/$bc-$dumpi.hprof ${dev_paths[$di]} $nproc $(($totalfilesize / $nproc))
        echo "$(date +%F/%H:%M:%S) Calling sync"
        sync ${dev_paths[$di]}/*

        # 2. Run all config combinations, splitting files as needed for each process count
        for bs in "${block_sizes[@]}"; do
          for rw in "${rws[@]}"; do
            for ioengine in "${sync_ioengines[@]}"; do              
              echo "$(date +%F/%H:%M:%S) Running (engine $ioengine, nproc $nproc, bs $bs, rw $rw) on device ${dev_names[$di]} using heapdump $bc-$dumpi"              

              SUBDIR=$RESULTSDIR/$rw/nproc-$nproc/request-size-$bs/sync-$ioengine/${dev_names[$di]}/$bc/dump-$dumpi
              mkdir -p $SUBDIR

              # Start zram monitoring if this is a zram device
              ZRAM_PID=""
              if [[ ${dev_names_sys[$di]} == *"zram"* ]]; then
                echo "Starting zram monitoring for ${dev_names_sys[$di]}"
                $HOMEdir/scripts/misc/zram_usage.sh "$SUBDIR/zram_usage.txt" "${dev_names_sys[$di]}" &
                ZRAM_PID=$!
              fi

              $HOMEdir/system_util/start_statistics.sh -d $SUBDIR
              BS="$bs" LOC="${dev_paths[$di]}" RW="$rw" IOENGINE="$ioengine" NUMA="$numa" FPREFIX="$bc-$dumpi-ext-" fio "$fio_config" --output="$SUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
              $HOMEdir/system_util/stop_statistics.sh -d $SUBDIR

              # Stop zram monitoring and parse results if monitoring was started
              if [[ -n "$ZRAM_PID" ]]; then
                echo "Stopping zram monitoring (PID: $ZRAM_PID)"
                kill $ZRAM_PID 2>/dev/null
                wait $ZRAM_PID 2>/dev/null
                
                # Parse zram results if the file exists
                if [[ -f "$SUBDIR/zram_usage.txt" ]]; then
                  echo "Parsing zram results"
                  $HOMEdir/scripts/misc/parse_zram_results.sh "$SUBDIR" > "$SUBDIR/zram_parsed.csv"
                fi
              fi
              
              $HOMEdir/system_util/extract-data.sh -r $SUBDIR -d ${dev_names_iostat[$di]}

              echo "$(date +%F/%H:%M:%S) Done"
            done
          done
        done

        # 4. Remove the split/extended files before next dump
        echo "$(date +%F/%H:%M:%S) Removing split/extended files from ${dev_paths[$di]} before next dump"
        find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null
        echo ""
      done
    done
  done
done

echo "all runs done"
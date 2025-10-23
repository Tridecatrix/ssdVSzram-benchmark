#!/bin/bash

# run this script with these commands AFTER SETTING NECESSARY PARAMETERS BELOW
#
# run while logging the output and error to file:
# nohup ./scripts/run/latest/run-dump-writes.sh <config_file.sh> <devicemap.sh> > data/log.txt 2>&1 &
#
# run while logging the output and error to file both locally and to remote ssh
# DMAP=?    <- put this in bashrc with the device mapping file
# CONF=?    <-  replace ? with conf you want to run
# stdbuf -oL nohup ./scripts/run/latest/run-dump-writes.sh $CONF $DMAP | tee log.txt | ssh ctoo 'cat /dev/stdin > fioLog'"$(hostname)"'.txt' & disown

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
if [ -n "$sync_config_path" ]; then
    sync_config="$HOMEdir/$sync_config_path"
elif [ -z "$sync_config" ]; then
    echo "Error: Neither sync_config nor sync_config_path is set in config file"
    exit 1
fi

# ----------------------------------
# parameters
# ----------------------------------

# The following parameters should now be set by the sourced config file:
# testrunopt, outputFormat, totalSize, dev_names, dev_paths, dev_names_sys,
# dev_names_iostat, sync_config, block_sizes, nprocs, rws, sync_ioengines,
# dacapo_benchs, maxdumps

# Validate that required variables are set
required_vars=("dev_names" "dev_paths" "dev_names_sys" "dev_names_iostat" "sync_config" "block_sizes" "nprocs" "rws" "sync_ioengines" "dacapo_benchs" "maxdumps")
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
: ${totalSize:=$((32 * 1024 * 1024 * 1024))}

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
echo "Total file size during runs: $totalSize" | tee -a $RESULTSDIR/fio-config.txt
echo "Block sizes: ${block_sizes[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Numbers of processes: ${nprocs[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Read/write type options: ${rws[@]}" | tee -a $RESULTSDIR/fio-config.txt
echo "Sync I/O engines: ${sync_ioengines[@]}" | tee -a $RESULTSDIR/fio-config.txt
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
      dumpi=$(( (ndumps / ndumpsToRun) * i - 1 ))
      dumppath=$HOMEdir/dumps/$bc-$dumpi.hprof

      echo $dumppath

      for bs in "${block_sizes[@]}"; do
        for nproc in "${nprocs[@]}"; do
          for rw in "${rws[@]}"; do
            for ioengine in "${sync_ioengines[@]}"; do
              # 1. Remove files
              echo "$(date +%F/%H:%M:%S) Removing files from ${dev_paths[$di]}"
              find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null

              # 2. make directory
              echo "$(date +%F/%H:%M:%S) Running (engine $ioengine, nproc $nproc, bs $bs, rw $rw) on device ${dev_names[$di]} using heapdump $bc-$dumpi"

              SUBDIR=$RESULTSDIR/$rw/nproc-$nproc/request-size-$bs/sync-$ioengine/${dev_names[$di]}/$bc/dump-$dumpi
              mkdir -p $SUBDIR

              # 3. Start zram monitoring if this is a zram device
              ZRAM_PID=""
              if [[ ${dev_names_sys[$di]} == *"zram"* ]]; then
                echo "Starting zram monitoring for ${dev_names_sys[$di]}"
                $HOMEdir/scripts/misc/zram_usage.sh "$SUBDIR/zram_usage.txt" "${dev_names_sys[$di]}" &
                ZRAM_PID=$!
              fi

              # 4. do run
              $HOMEdir/system_util/start_statistics.sh -d $SUBDIR
              BS="$bs" DIR="${dev_paths[$di]}" RW="$rw" IOENGINE="$ioengine" NUMA="$numa" DUMP="$dumppath" NPROC="$nproc" SIZE_PER_PROC="$((totalSize / nproc))" fio $sync_config --output="$SUBDIR/fio_out.txt" --output-format=$outputFormat $testrunopt
              $HOMEdir/system_util/stop_statistics.sh -d $SUBDIR
              
              # 5. Stop zram monitoring and parse results if monitoring was started
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

              # 6. Remove files again
              echo "$(date +%F/%H:%M:%S) Removing files from ${dev_paths[$di]}"
              find ${dev_paths[$di]} -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} + 2>/dev/null
              echo ""

              echo "$(date +%F/%H:%M:%S) Done"
              echo ""
            done
          done
        done
      done
    done
  done
done

echo "all runs done"
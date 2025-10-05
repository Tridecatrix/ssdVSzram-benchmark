#!/usr/bin/env bash

###################################################
#
# file: zram_usage.sh
#
# @Author:  Iacovos G. Kolokasis
# @Version: 19-01-2021
# @email:   kolokasis@ics.forth.gr
#
# @brief    This script tracks the zram usage 
###################################################

echoheader() {
    echo "ioheaders  failed_reads failed_writes invalid_io notify_free"
    echo "mmheaders  orig_data_size compr_data_size mem_used_total mem_limit mem_used_max same_pages pages_compacted huge_pages huge_pages_since"
    echo "bdheaders  bd_count bd_reads bd_writes"
    echo
}

# Output file name
OUTPUT=$1        
NUM_OF_EXECUTORS=$2
ZRAMDEV=$(echo $3 | awk -F/ '{print $NF}')

if [[ ${ZRAMDEV:0:4} != "zram" ]]; then
    echo "Device $ZRAMDEV is not a zram device" >> "${OUTPUT}"
    exit 0
fi

# Number of executors
numOfExecutors=0

# Clear existing statistics
echo 0 | sudo tee /sys/block/${ZRAMDEV}/mem_used_max > /dev/null

# Wait here until the executors are launched
while [ ${numOfExecutors} -lt "${NUM_OF_EXECUTORS}" ] 
do
    # Calculate number of executors running
    numOfExecutors=$(jps |grep -c "CoarseGrainedExecutorBackend")
done

# Echo header line (for human readability)
echoheader >> "${OUTPUT}"
while true; do
    # zramctl --output-all >> "${OUTPUT}"
    echo "iostat  $(cat /sys/block/${ZRAMDEV}/io_stat)" >> "${OUTPUT}"
    echo "mmstat  $(cat /sys/block/${ZRAMDEV}/mm_stat)" >> "${OUTPUT}"
    echo "bdstat  $(cat /sys/block/${ZRAMDEV}/bd_stat)" >> "${OUTPUT}"
    echo >> "${OUTPUT}"
    
    sleep 1
done

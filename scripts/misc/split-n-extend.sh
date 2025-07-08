#!/bin/bash

INFILE=$1
OUTDIR=$2
NP=$3
SIZEPP=$4

split -n $NP -d $INFILE $OUTDIR/s

# Call extend-file.sh on each split file in parallel
for i in $(seq -f "%02g" 0 $((NP-1))); do
    ./scripts/misc/extend-file.sh $OUTDIR/s$i $OUTDIR/se$i $SIZEPP &
done

# Wait for all background processes to finish
wait
#!/bin/bash

INFILE=$1
OUTDIR=$2
NP=$3
SIZEPP=$4

if [[ -z $INFILE || -z $OUTDIR || -z $NP || -z $SIZEPP ]]; then
    echo "Usage: $0 <input_file> <output_directory> <number_of_parts> <size_per_part>"
    exit 1
fi  

# get filename
fname=$(basename $INFILE)
ext="${fname##*.}"
fname="${fname%.*}" # remove extension

split -n $NP -d $INFILE $OUTDIR/$fname- --additional-suffix=-$ext

# Call extend-file.sh on each split file in parallel
for i in $(seq -f "%02g" 0 $((NP-1))); do
    ./scripts/misc/extend-file.sh $OUTDIR/$fname-$i.$ext $OUTDIR/$fname-ext-$i.$ext $SIZEPP &
done

# Wait for all background processes to finish
wait
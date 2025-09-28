#!/bin/bash

ORIGFILE=$1
EXTFILE=$2
NEWSIZE=$3

# echo "extending file"
cp $ORIGFILE $EXTFILE

SIZE=`stat --format=%s $EXTFILE`
while [[ $SIZE -lt $NEWSIZE ]]; do
    cat $ORIGFILE >> $EXTFILE

    if [[ $? -ne 0 ]]; then
        echo "Error extending file"
        exit 1
    fi

    SIZE=`stat --format=%s $EXTFILE`
    # echo "current size: $SIZE"
done

# echo "final size after going over required size: $SIZE"
if [[ $SIZE -gt $NEWSIZE ]]; then
    truncate --size=$NEWSIZE $EXTFILE
fi
# echo "after truncating: $SIZE"

rm $ORIGFILE

# echo "done"
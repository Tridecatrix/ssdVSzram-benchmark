#!/bin/bash

ORIGFILE=$1
EXTFILE=$2
NEWSIZE=$((32*1024*1024*1024))

echo "extending file"

cp $ORIGFILE $EXTFILE

SIZE=`du $EXTFILE -B1 | awk '{print $1}'`
while [[ $SIZE -lt $NEWSIZE ]]; do
    cat $ORIGFILE >> $EXTFILE
    SIZE=`du $EXTFILE -B1 | awk '{print $1}'`
done

echo "final size after going over required size: $SIZE"
if [[ $SIZE -gt $NEWSIZE ]]; then
    truncate --size=$NEWSIZE $EXTFILE
fi
echo "after truncating: $SIZE"

echo "done"
#!/bin/bash

ORIGFILE=$1
EXTFILE=$2
NEWSIZE=$((32*1024*1024*1024))

echo "extending file"

EXTFILEcopy="${2}2"
cp $ORIGFILE $EXTFILE

SIZE=`du $EXTFILE -B1 | awk '{print $1}'`
while [[ $SIZE -lt $NEWSIZE ]]; do
    cat $EXTFILEcopy >> $EXTFILE
    tmp=$EXTFILE
    EXTFILE=$EXTFILEcopy
    EXTFILEcopy=$tmp

    SIZE=`du $EXTFILE -B1 | awk '{print $1}'`
    echo "current size: $SIZE"
done

rm $EXTFILEcopy

echo "final size after going over required size: $SIZE"
if [[ $SIZE -gt $NEWSIZE ]]; then
    truncate --size=$NEWSIZE $EXTFILE
fi
echo "after truncating: $SIZE"

echo "done"
echo "final file in path $EXTFILE"
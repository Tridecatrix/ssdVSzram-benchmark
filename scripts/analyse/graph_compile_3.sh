#!/bin/bash

INDIR="processed-data/2025-03-18-limmem"

INPUTFILES=""
for direct in 0 1; do
    for rw in 'read' 'randread' 'rw' 'randrw'; do
        INPUTFILES="$INPUTFILES $INDIR/$rw-direct-$direct-readBW.png"
    done

    for rw in 'write' 'randwrite' 'rw' 'randrw'; do
        INPUTFILES="$INPUTFILES $INDIR/$rw-direct-$direct-writeBW.png"
    done
done
  
montage -tile 4x4 -mode concatenate $INPUTFILES $INDIR/compile.png
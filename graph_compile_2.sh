#!/bin/bash

INDIR="processed-data/2025-03-04-second-run-finch2/graphs"

INPUTFILES=""
for iotype in 'iouring' 'libaio' 'sync' 'mmap'; do
  for metric in 'readBW' 'writeBW' 'readlat' 'writelat'; do
    INPUTFILES="$INPUTFILES $INDIR/$metric/max-$iotype.png"
  done
done
  
montage -tile 4x4 -mode concatenate $INPUTFILES $INDIR/compile.png
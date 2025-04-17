#!/bin/bash

CMD=$1
EXPNAME=$2
if [ -z $RDIR ]; then
    EXPNAME="miscexp"
fi
HOMEdir=`git rev-parse --show-toplevel`

RDIR="$HOMEdir/data/$(date +%F-time-%H-%M-%S)-$EXPNAME"

$HOMEdir/system_util/start_statistics.sh -d $RDIR
$CMD
$HOMEdir/system_util/stop_statistics.sh -d $RDIR
$HOMEdir/system_util/extract-data.sh -r $RDIR -d nvme0c0n1 -d zram0 -d zram1 -d zram2
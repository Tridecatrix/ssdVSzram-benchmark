#!/bin/bash

configfile=$1

if [[ -z $configfile ]]; then
    echo "usage: ./single-run.sh /path/to/configfile"
fi

homedir=`git rev-parse --show-toplevel`
cd $homedir

rdir=data/$(date +%F-time-%H-%M-%S)-single-run-$(basename $configfile | awk -F. '{print $1}')
mkdir -p $rdir

./system_util/start_statistics.sh -d $rdir
fio -f $configfile > $rdir/fio_out.txt
./system_util/stop_statistics.sh -d $rdir
./system_util/extract-data.sh -r $rdir -d zram0 -d zram1 -d zram2 -d nvme0n1

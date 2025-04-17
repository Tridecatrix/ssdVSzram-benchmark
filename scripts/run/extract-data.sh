#!/bin/bash

RESULTDIR=$1

find $RESULTDIR -name system.csv | xargs rm
find $RESULTDIR -name diskstat.csv | xargs rm
find $RESULTDIR -name ssd | xargs -i ./system_util/extract-data.sh -r {} -d nvme0c0n1
find $RESULTDIR -name zram | xargs -i ./system_util/extract-data.sh -r {} -d zram0
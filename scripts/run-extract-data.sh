#!/bin/bash

RESULTDIR=data/2025-03-14-time-17-12-08-third-run-limmem-pp

find $RESULTDIR -name system.csv | xargs rm
find $RESULTDIR -name diskstat.csv | xargs rm
find $RESULTDIR -name ssd | xargs -i ./system_util/extract-data.sh -r {} -d nvme0c0n1
find $RESULTDIR -name zram | xargs -i ./system_util/extract-data.sh -r {} -d zram0
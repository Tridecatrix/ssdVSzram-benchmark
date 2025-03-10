#!/bin/bash

RESULTSDIR=data/2025-02-28-time-14-37-09-finale/fio/
OUTPUTDIR=processed-data/2025-02-28-first-run/graphs

mkdir -p $OUTPUTDIR

block_sizes=(4096)
nexecs=(32 64)
rws=(read write rw randread randwrite randrw)
ioengines=(async sync-sync sync-mmap)
plots=(
    avg_qu_sz
    avg_rq_sz
    cpu
    idle_cpu
    iow_cpu
    r_thrput
    sys_cpu
    thrput
    user_cpu
    util
    wr_thrput
)

for bs in "${block_sizes[@]}"; do
  for nexec in "${nexecs[@]}"; do
    for ioengine in "${ioengines[@]}"; do
      for p in "${plots[@]}"; do
        SUBDIR=iodepth_$nexec/request_size_$bs/$ioengine

        mkdir -p $OUTPUTDIR/$SUBDIR

        INPUTFILES=""
        for device in ssd zram; do
          for rw in "${rws[@]}"; do
            F=${RESULTSDIR}${rw}/$SUBDIR/$device/plots/$p.png
            convert $F -pointsize 32 label:"$device-$rw" -gravity Center -append tmp/$device-$rw.png
            INPUTFILES="tmp/$device-$rw.png $INPUTFILES"
          done
        done

        montage -tile 3x4 -mode concatenate -label %l $INPUTFILES $OUTPUTDIR/$SUBDIR/$p.png
      done
    done
  done
done

rm tmp/*


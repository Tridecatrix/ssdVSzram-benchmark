#!/bin/bash

ZRAMdir=$1
SSDdir=$2

echo "clearing job files on ZRAM and SSD"
rm -f $ZRAMdir/job-* 
rm -f $SSDdir/job-* 
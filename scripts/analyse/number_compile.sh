#!/bin/bash

# NOTE: this script runs on the raw output directory and extracts comparisons of
# metrics, but it specifically runs on files using the "normal" (human readable) output
# of fio. For more serious data analysis, using the "json" format from the outset is recommended.

nexecs=(32 64)
ioengines=(async sync-sync sync-mmap)
rws=(read write rw randread randwrite randrw)
devices=(ssd zram)

metrics=(avglat)
grepStrings=("READ: bw=" "WRITE: bw=" "lat (nsec):")

for x in `seq ${#metrics[@]}`; do
    for n in ${nexecs[@]}; do
        SUBDIR=processed-data/2025-02-28-first-run/numbers/iodepth-$n
        mkdir -p $SUBDIR
        OUTFILE=$SUBDIR/compile-${metrics[x-1]}.md

        rm -f $OUTFILE
        touch $OUTFILE

        for i in ${ioengines[@]}; do
            echo -e "# $i\n" >> $OUTFILE

            for rw in ${rws[@]}; do
                for d in ${devices[@]}; do
                    echo -n "$d-$rw: " >> $OUTFILE

                    INFILE="data/2025-02-28-time-14-37-09-finale/fio/$rw/iodepth_$n/request_size_4096/$i/$d/fio_out.txt"

                    case ${metrics[x-1]} in
                        readBW | writeBW)
                            data=`grep "${grepStrings[x-1]}" $INFILE | awk -F'bw=' '{print $2}' | awk -F',' '{print $1}'`
                            ;;
                        avglat)
                            data=`grep 'lat' $INFILE | sed '2q;d' | awk -F'avg=' '{print $2}' | awk -F',' '{print $1}'`
                            data="$data `grep 'lat' $INFILE | sed '2q;d' | awk '{print $2}' | awk -F':' '{print $1}'`"
                            ;;
                        *)
                            echo "Unable to parse this metric ${metric[x-1]}; please check script for typo" >> $OUTFILE
                            ;;
                    esac

                    if [ -z "$data" ]; then
                        echo "n/a" >> $OUTFILE
                    else
                        echo "$data" >> $OUTFILE
                    fi
                done

                echo -e "" >> $OUTFILE
            done

            echo -e "\n" >> $OUTFILE
        done
    done
done
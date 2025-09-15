I/O benchmarking data and scripts for profiling and comparing ZRAM and SSD. 

Submodule repositories initially provided by Iacovos "Jack" Kolokakis.

# TODOS

(URGENT) Update run scripts:
- make sure the comments describing what command to run the script with is accurate
- update all mentions of zrammnt to fit new location of zram mounts (/mnt)

# Setup

Run the `scripts/setup.sh` script to download the git submodules `fio_scripts` and `system_util` as well as initialize a mounting point for zram. You will likely need to adjust commands there as necessary, but the script contains the necessary steps. 

If you are using VICS machines, it is recommended to set up passwordless SSH connection from this device to Cockatoo so that run logs can be sent there for remote experiment monitoring.

# Running base experiment

To run the experiment using fio-created files, after doing setup, review and modify parameters in `scripts/run/run.sh` as appropriate and then run it. `fio` will create its own files on the devices. The run script generates a results directory containing (for each fio configuration) data from fio, data from iostat/mpstat which are run during fio's execution, and data from diskutil. 

# Running dumps experiment

To run the dumps experiment, first download a JAR for the DaCapo benchmarks from https://github.com/dacapobench/dacapobench into the root of the repo. Then run `scripts/misc/generate-heap-dumps.sh` to generate the heap dumps into a folder called `dumps`. Finally, run `scripts/run/specific/run-dump.sh`. As usual scripts may require modifying parameters. 

# Data analysis

`scripts/analyse` contains all data analysis scripts. `create-master-table.py` is the most useful one; it will collate the various fio/iostat/mpstat results within an experiment into a single master CSV which can then be queried and processed with Pandas in another Python script. The `analysislib.py` file provides some helper functions, and the existing data analysis scripts can serve as a model for building your own.
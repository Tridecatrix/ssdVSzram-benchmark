I/O benchmarking data and scripts for profiling and comparing ZRAM and SSD. 

Submodule repositories initially provided by Iacovos "Jack" Kolokakis.

# Setup

Run the `scripts/setup.sh` script to download the git submodules as well as initialize a mounting point for zram. You will likely need to adjust commands there as necessary, but the script contains the necessary steps.

To run the heap dump based experiments, first download and unzip the latest (binary) release of the DaCapo benchmark from https://github.com/dacapobench/dacapobench. This may take up to 20 minutes.
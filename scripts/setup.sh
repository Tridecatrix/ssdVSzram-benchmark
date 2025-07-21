#!/bin/bash

# run this script with sudo, or copypaste commands from here. run from repo root directory.
# if you only want to set up ZRAM, run setup-zram.sh

# install git submodules
git submodule init
git submodule update --init fio_scripts
git submodule update --init system_util

# install dependencies
apt install fio

# for using the python scripts, you should also have the following python modules for quick analysis:
# - pandas
# - pandasql
# and the following for more complex analysis:
# - matplotlib
# - anything else imported by the scripts givtoucen
# I'd put the pip install commands for these here but you may be wanting to use a different package manager

./scripts/setup-zram.sh

# you will need to have SSD setup seperately

# set up passwordless SSH access to ctoo (this wont run directly due to requiring inputs so run these in terminal)
# ssh-keygen -t ed-25519
# scp ~/.ssh/config u7300623@machineName:~/.ssh   # run this from local device to copy over config for connecting to remote devices
# (in my case I also need to modify the config to remove windows style filepaths)
# ssh-copy-id bulwark
# ssh-copy-id ctoo

# finally set paths in run.sh


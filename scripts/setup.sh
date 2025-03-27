# run this script with sudo, or copypaste commands from here. run from repo root directory.
# if you only want to set up ZRAM, run setup-zram.sh

# install git submodules
git submodule init
git submodule update

# install dependencies
pip install matplotlib

./scripts/setup-zram.sh

# you will need to set up SSD seperately

# set up passwordless SSH access to ctoo (this wont run directly due to requiring inputs so run these in terminal)
# ssh-keygen -t ed-25519
# scp ~/.ssh/config u7300623@machineName:~/.ssh   # run this from local device to copy over config for connecting to remote devices
# (in my case I also need to modify the config to remove windows style filepaths)
# ssh-copy-id bulwark
# ssh-copy-id ctoo

# finally set paths in run.sh


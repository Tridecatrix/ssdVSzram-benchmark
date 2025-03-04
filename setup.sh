# run this script with sudo, or copypaste commands from here

# install git submodules
git submodule init
git submodule update

# install dependencies
pip install matplotlib

# set up zram
mkdir zrammount
sudo modprobe zram num_devices=1
sudo zramctl /dev/zram0 -a lzo -s 250G -t 96
sudo mkfs.ext4 /dev/zram0
sudo mount /dev/zram0 zrammount

# set permissions on SSD and ZRAM
sudo chmod u+xrw zrammount
sudo chown u7300623:users zrammount
# do ssd seperately lol

# set up passwordless SSH access to ctoo (this wont run directly so run these in terminal)
# ssh-keygen -t ed-25519
# scp ~/.ssh/config u7300623@machineName:~/.ssh   # run this from local device to copy over config for connecting to remote devices
# (in my case I also need to modify the config to remove windows style filepaths)
# ssh-copy-id bulwark
# ssh-copy-id ctoo

# also verify that SSD is mounted; set up directory on SSD
# finally set paths in run.sh


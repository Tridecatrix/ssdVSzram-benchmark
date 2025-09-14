# device settings
dev_names=("ssd" "zram0" "zram1" "zram2") # (informal) device names
dev_paths=("/mnt/ssd0/adnan/bench" "$HOMEdir/zrammnt0-lzo" "$HOMEdir/zrammnt1-zstd" "$HOMEdir/zrammnt2-lz4") # paths where job files should be stored for each device
dev_names_sys=("/dev/nvme0n1" "/dev/zram0" "/dev/zram1" "/dev/zram2") # paths to device files for each device
dev_names_iostat=("nvme0n1" "zram0" "zram1" "zram2") # names of devices as given in output of iostat

for di in ${!dev_names[@]}; do
  # assert that directories exist
  if [ ! -d "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, does not exist."
  fi

  # assert that directories are accessible
  if [ ! -x "${dev_paths[$di]}" ]; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, is not accessible."
  fi

  # assert that the directories are mounted on correct devices
  if df ${dev_paths[$di]} | xargs grep -qs ${dev_names_sys[$di]}; then
    echo "Path given for device ${dev_names[$di]}, which is ${dev_paths[$di]}, is not mounted on the specified device."
  fi
done

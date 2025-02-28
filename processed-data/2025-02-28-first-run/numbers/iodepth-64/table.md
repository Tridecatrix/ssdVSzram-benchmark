async:
                  read          write        rw          randread     randwrite   randrw
ssd read B/W      1328MiB/s     n/a          637MiB/s    1314MiB/s    n/a         521MiB/s                   
ssd write B/W     n/a           1219MiB/s    637MiB/s    n/a          1168MiB/s   521MiB/s
zram read B/W     1437MiB/s     n/a          196MiB/s    1322MiB/s    n/a         198MiB/s
zram write B/W    n/a           202MiB/s     196MiB/s    n/a          211MiB/s    198MiB/s



sync (syscall):
                  read          write       rw          randread     randwrite   randrw
ssd read B/W      1902MiB/s     n/a         904MiB/s    2017MiB/s    n/a         852MiB/s                   
ssd write B/W     n/a           2132MiB/s   903MiB/s    n/a          2042MiB/s   852MiB/s
zram read B/W     14.3GiB/s     n/a         1902MiB/s   25.0GiB/s    n/a         1753MiB/s
zram write B/W    n/a           1930MiB/s   1901MiB/s   n/a          1928MiB/s   1752MiB/s



sync (mmap):
                  read          write       rw          randread     randwrite   randrw
ssd read B/W      3378MiB/s     n/a         1105MiB/s   2044MiB/s    n/a         566MiB/s                   
ssd write B/W     n/a           1109MiB/s   1105MiB/s   n/a          924MiB/s    566MiB/s 
zram read B/W     17.2GiB/s     n/a         2098MiB/s   12.9GiB/s    n/a         2075MiB/s
zram write B/W    n/a           2100MiB/s   2097MiB/s   n/a          2172MiB/s   2075MiB/s
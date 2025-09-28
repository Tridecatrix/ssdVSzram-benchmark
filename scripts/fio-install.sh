#!/bin/bash

FIO_VERSION="3.40"
git clone https://github.com/axboe/fio.git fio-${FIO_VERSION}
cd fio-${FIO_VERSION}
git checkout "fio-${FIO_VERSION}"
./configure
make -j$(nproc)
sudo make install
cd ..
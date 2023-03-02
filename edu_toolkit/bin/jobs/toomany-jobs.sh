#!/bin/bash
echo
echo "Starting 9 jobs all at once..."
./pools.sh pool1 start
./pools.sh pool1 start
./pools.sh pool1 start
./pools.sh pool2 start
./pools.sh pool2 start
./pools.sh pool2 start
./pools.sh pool3 start
./pools.sh pool3 start
./pools.sh pool3 start
#!/bin/bash

expect -c "set timeout -1
spawn impala-shell

expect -re \"\\[Not connected\\]*\"
send \"connect worker-1;\r\"

expect -re \"\\[worker\\\-1:21000\\]*\"
send \"show databases;\r\"

expect -re \"\\[worker\\\-1:21000\\]*\"
send \"use default;\r\"

expect -re \"\\[worker\\\-1:21000\\]*\"
send \"show tables;\r\"

expect -re \"\\[worker\\\-1:21000\\]*\"
send \"SELECT * FROM default.ngrams_s3_gz WHERE gram='computer';\r\"

expect -re \"\\[worker\\\-1:21000\\]*\"
send \"quit();\r\"

expect eof"
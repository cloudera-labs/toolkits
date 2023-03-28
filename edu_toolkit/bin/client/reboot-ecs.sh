#!/bin/bash

input="target-hosts-ecs.txt"

sudo_user='centos'
user_privkey='~/.ssh/lab.key'

while read -r -u10 host;
do echo '"'Trying..${host}'"';
ssh -i ${user_privkey} -o StrictHostKeyChecking=no ${sudo_user}@${host} "sudo reboot now";
done 10< "$input"

#!/bin/bash

sudo_user='training'
user_privkey='~/.ssh/admincourse.pem'
input="list_ecs_hosts.txt"

while read -r -u10 host;
do echo '"'Trying..${host}'"';
ssh -i ${user_privkey} -o StrictHostKeyChecking=no ${sudo_user}@${host} "sudo reboot now";
done 10< "$input"

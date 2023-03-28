#!/bin/bash


echo "Make sure you kill registry and shut down the ECS Services"

input="target-hosts-ecs.txt"

docker_store='/mnt/docker/*'
local_store='/mnt/local-storage/*'
longhorn_store='/ecs/longhorn-storage/*'
sudo_user='training'
user_privkey='~/.ssh/admincourse.pem'


while read -r -u10 host;
do echo '"'Trying..${host}'"';
ssh -i ${user_privkey} -o StrictHostKeyChecking=no  ${sudo_user}@${host} "
sudo /opt/cloudera/parcels/ECS/docker/docker container stop registry;
sudo /opt/cloudera/parcels/ECS/docker/docker container rm -v registry;
sudo /opt/cloudera/parcels/ECS/docker/docker image rm registry:2";
done 10< "$input"


echo "Registry killed and no go shut down Docker and ECS services"

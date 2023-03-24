#!/bin/bash


echo "Make sure you kill registry and shut down the ECS Services"

input="target-hosts-ecs.txt"

docker_store='/mnt/docker/*'
local_store='/mnt/local-storage/*'
longhorn_store='/ecs/longhorn-storage/*'
sudo_user='centos'
user_privkey='~/.ssh/lab.key'

echo "Registry killed and shut down ECS services"

while read -r -u10 host;
do echo '"'Trying..${host}'"';
echo '"'xxxxxxxxxxxxxxxxxxxxxx'"';
ssh -i ${user_privkey} -o StrictHostKeyChecking=no ${sudo_user}@${host} "
cd /opt/cloudera/parcels/ECS/bin;
sudo ./rke2-killall.sh;
echo '"'xxxxxxxxxxxxxxxxxxxxx'"'
echo "Removing global read-only mounts, if any";
sudo mount | awk '/on \/var\/lib\/(kubelet|k3s)/{print \$3}' | xargs -r sudo umount -l
sudo ./rke2-uninstall.sh;
sudo [ -d "/var/lib/rancher" ] && echo "Directory /var/lib/rancher exists. rke2-uninstall.sh has failed!";
sudo [ -d "/var/lib/kubelet" ] && echo "Directory /var/lib/kubelet exists. rke2-uninstall.sh has failed!";
sudo rm -rf /var/lib/docker_server;
sudo [ -d "/var/lib/docker_server" ] && echo "Directory /var/lib/docker_server  exists.thats a fail!";
sudo rm -rf /etc/docker/certs.d;
sudo [ -d "/etc/docker/certs.d" ] && echo "Directory /etc/docker/certs.d  exists.thats a fail!";
echo "Deleting docker, local and longhorn storage";
sudo rm -rf ${docker_store};
sudo rm -rf ${local_store};
sudo rm -rf ${longhorn_store};
sudo rm -rf /var/lib/docker/*;
sudo rm -rf /var/log/containers/*;
sudo rm -rf /var/log/pods/*;

echo "Reset iptables to ACCEPT all, then flush and delete all other chains";
declare -A chains=(
[filter]=INPUT:FORWARD:OUTPUT
[raw]=PREROUTING:OUTPUT
[mangle]=PREROUTING:INPUT:FORWARD:OUTPUT:POSTROUTING
[security]=INPUT:FORWARD:OUTPUT
[nat]=PREROUTING:INPUT:OUTPUT:POSTROUTING
)
for table in "${!chains[@]}"; do
echo "${chains[$table]}" | tr : $"\n" | while IFS= read -r; do
sudo iptables -t "$table" -P "$REPLY" ACCEPT
done
sudo iptables -t "$table" -F
sudo iptables -t "$table" -X
done;
";
done 10< "$input"

echo "Now delete the ECS Cluster"

#!/bin/bash
nocheck="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error"
###### Managing the HDFS superuser group
# TO DO: create the Hue superuser 

check=$(sudo systemctl status cloudera-scm-server | grep Active: | cut -d " " -f5)
echo "Last check: $check"
if [[ "$check" == "failed" ]]; then 
	exit 1
fi
# also create the /user/training dir in HDFS (which Hue would have done)
sudo -u hdfs hdfs dfs -mkdir /user/training
sudo -u hdfs hdfs dfs -chown training:training /user/training

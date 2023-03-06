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

#repeat the exercise steps
ssh $nocheck training@master-1 sudo groupadd supergroup
ssh $nocheck training@master-1 sudo usermod -aG supergroup training 
ssh $nocheck training@master-2 sudo groupadd supergroup
ssh $nocheck training@master-2 sudo usermod -aG supergroup training 
hdfs dfsadmin -refreshUserToGroupsMappings

###### Using the HDFS CLI
hdfs dfs -mkdir /testdir
touch testfile1 testfile2 testfile3
hdfs dfs -put testfile* /testdir/
hdfs dfs -rm /testdir/testfile1
hdfs dfs -rm -skipTrash /testdir/testfile2
hdfs dfs -rm -r /testdir
hdfs dfs -expunge
ssh $nocheck training@master-1 sudo gpasswd -d training supergroup 
ssh $nocheck training@master-2 sudo gpasswd -d training supergroup 
hdfs dfsadmin -refreshUserToGroupsMappings
sudo -u hdfs hdfs dfs -mkdir /weblogs
sudo -u hdfs hdfs dfs -chown training /weblogs
hdfs dfs -ls /

###### Add weblog Data to HDFS
echo
echo "adding weblog data ot HDFS"
hdfs dfs -put ~/training_materials/admin/data/weblogs/* /weblogs/
hdfs fsck /weblogs -blocks

###### Ingest the Unzipped Ngrams Data into HDFS Using the HDFS CLI
hdfs dfs -mkdir /tmp/ngrams
echo
echo "################################"
echo "Ingesting ngram data into HDFS"
echo "################################"
echo
hdfs dfs -put /ngrams/unzipped/*[a-e] /tmp/ngrams/

hdfs dfs -setrep 2 /tmp/ngrams

#!/bin/bash
nocheck="-o StrictHostKeyChecking=no"

#do an hdfs fsck -files -blocks -locations on a candidate file. 
#Then shut down HDFS and edit all the block replicas by hand to corrupt it.  
#Then bring HDFS back up. 
#You have to do all the replicas or it will fix itself, hence my recommendation to shut down HDFS. 
#You could probably do it all online if you were fast enough to do it before the block scanner finds it, but shutting down HDFS seems easier. 

echo 
echo "First see if any blocks are already missing and/or corrupt..."
echo "-------------------------------------------------------------"
sudo -u hdfs hdfs fsck /
echo "-------------------------------------------------------------"
echo

#These are the files which we want to corrupt 
file1="/weblogs/2013-09-24.log"
file2="/weblogs/2013-09-25.log"
file3="/weblogs/2013-09-26.log"
#sudo -u hdfs hdfs dfs -setrep -R 1 $file

#TEST
delete3="yes"

#FIND FILE1
f1b1=$(sudo -u hdfs hdfs fsck $file1 -files -blocks -locations | grep BP- | cut -d ':' -f2 | awk '{print $1}' | cut -d '_' -f1-2)
echo "f1b1="$f1b1
f1dn1=$(sudo -u hdfs hdfs fsck $file1 -files -blocks -locations | grep BP- | cut -d '[' -f3 | cut -d ':' -f1)
f1dn1=$(cat /etc/hosts | grep $f1dn1 | awk '{print $3}')
echo "f1dn1="$f1dn1
f1dn2=$(sudo -u hdfs hdfs fsck $file1 -files -blocks -locations | grep BP- | cut -d '[' -f4 | cut -d ':' -f1)
f1dn2=$(cat /etc/hosts | grep $f1dn2 | awk '{print $3}')
echo "f1dn2="$f1dn2
f1b1rep1=$(ssh $nocheck training@$f1dn1 sudo find /dfs/dn/current/ -name *$f1b1* )
echo "File 1 replica 1 on "$f1dn1": "$f1b1rep1
f1b1rep2=$(ssh $nocheck training@$f1dn2 sudo find /dfs/dn/current/ -name *$f1b1* )
echo "File 1 replica 2 on "$f1dn2": "$f1b1rep2
if [[ "$delete3" == "yes" ]]; then
	f1dn3=$(sudo -u hdfs hdfs fsck $file1 -files -blocks -locations | grep BP- | cut -d '[' -f5 | cut -d ':' -f1)
	f1dn3=$(cat /etc/hosts | grep $f1dn3 | awk '{print $3}')
	echo "f1dn3="$f1dn3
	f1b1rep3=$(ssh $nocheck training@$f1dn3 sudo find /dfs/dn/current/ -name *$f1b1* )
	echo "File 1 replica 3 on "$f1dn3": "$f1b1rep3
fi

#FIND FILE2
f2b1=$(sudo -u hdfs hdfs fsck $file2 -files -blocks -locations | grep BP- | cut -d ':' -f2 | awk '{print $1}' | cut -d '_' -f1-2)
echo "f2b1="$f2b1
f2dn1=$(sudo -u hdfs hdfs fsck $file2 -files -blocks -locations | grep BP- | cut -d '[' -f3 | cut -d ':' -f1)
f2dn1=$(cat /etc/hosts | grep $f2dn1 | awk '{print $3}')
echo "f2dn1="$f2dn1
f2dn2=$(sudo -u hdfs hdfs fsck $file2 -files -blocks -locations | grep BP- | cut -d '[' -f4 | cut -d ':' -f1)
f2dn2=$(cat /etc/hosts | grep $f2dn2 | awk '{print $3}')
echo "f2dn2="$f2dn2
f2b1rep1=$(ssh $nocheck training@$f2dn1 sudo find /dfs/dn/current/ -name *$f2b1* )
echo "File 2 replica 1 on "$f2dn1": "$f2b1rep1
f2b1rep2=$(ssh $nocheck training@$f2dn2 sudo find /dfs/dn/current/ -name *$f2b1* )
echo "File 2 replica 2 on "$f2dn2": "$f2b1rep2
if [[ "$delete3" == "yes" ]]; then
	f2dn3=$(sudo -u hdfs hdfs fsck $file2 -files -blocks -locations | grep BP- | cut -d '[' -f5 | cut -d ':' -f1)
	f2dn3=$(cat /etc/hosts | grep $f2dn3 | awk '{print $3}')
	echo "f2dn3="$f2dn3
	f2b1rep3=$(ssh $nocheck training@$f2dn3 sudo find /dfs/dn/current/ -name *$f2b1* )
	echo "File 2 replica 3 on "$f2dn3": "$f2b1rep3
fi

#FIND FILE3
f3b1=$(sudo -u hdfs hdfs fsck $file3 -files -blocks -locations | grep BP- | cut -d ':' -f2 | awk '{print $1}' | cut -d '_' -f1-2)
echo "f3b1="$f3b1
f3dn1=$(sudo -u hdfs hdfs fsck $file3 -files -blocks -locations | grep BP- | cut -d '[' -f3 | cut -d ':' -f1)
f3dn1=$(cat /etc/hosts | grep $f3dn1 | awk '{print $3}')
echo "f3dn1="$f3dn1
f3dn2=$(sudo -u hdfs hdfs fsck $file3 -files -blocks -locations | grep BP- | cut -d '[' -f4 | cut -d ':' -f1)
f3dn2=$(cat /etc/hosts | grep $f3dn2 | awk '{print $3}')
echo "f3dn2="$f3dn2
f3b1rep1=$(ssh $nocheck training@$f3dn1 sudo find /dfs/dn/current/ -name *$f3b1* | grep -v meta ) #don't delete the meta on this one
echo "File 3 replica 1 on "$f3dn1": "$f3b1rep1
f3b1rep2=$(ssh $nocheck training@$f3dn2 sudo find /dfs/dn/current/ -name *$f3b1* | grep -v meta ) #don't delete the meta on this one
echo "File 3 replica 2 on "$f3dn2": "$f3b1rep2
if [[ "$delete3" == "yes" ]]; then
	f3dn3=$(sudo -u hdfs hdfs fsck $file3 -files -blocks -locations | grep BP- | cut -d '[' -f5 | cut -d ':' -f1)
	f3dn3=$(cat /etc/hosts | grep $f3dn3 | awk '{print $3}')
	echo "f3dn3="$f3dn3
	f3b1rep3=$(ssh $nocheck training@$f3dn3 sudo find /dfs/dn/current/ -name *$f3b1* )
	echo "File 3 replica 3 on "$f3dn3": "$f3b1rep3
fi


#CM API DETAILS
clusterName=$(curl -s -X GET -u "admin:admin" -i http://cmhost:7180/api/v8/clusters/ | grep name| cut -d '"' -f4)
curlURL="-s -X GET -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/"
hdfsServiceName=$(curl $curlURL | grep CD-HDFS | grep name | cut -d '"' -f4 )
if [[ "$hdfsServiceName" == "" ]]; then
	hdfsServiceName="hdfs"
fi
#STOP HDFS
echo
echo "Stopping the HDFS service..."
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$hdfsServiceName/commands/stop
sleep 10

#DELETE BLOCKS
ssh $nocheck training@$f1dn1 sudo rm $f1b1rep1
ssh $nocheck training@$f1dn2 sudo rm $f1b1rep2
ssh $nocheck training@$f2dn1 sudo rm $f2b1rep1
ssh $nocheck training@$f2dn2 sudo rm $f2b1rep2
ssh $nocheck training@$f3dn1 sudo rm $f3b1rep1
ssh $nocheck training@$f3dn2 sudo rm $f3b1rep2
if [[ "$delete3" == "yes" ]]; then
	ssh $nocheck training@$f1dn3 sudo rm $f1b1rep3
	ssh $nocheck training@$f2dn3 sudo rm $f2b1rep3
	ssh $nocheck training@$f3dn3 sudo rm $f3b1rep3
fi

echo
echo "Starting the HDFS service..."
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$hdfsServiceName/commands/start
sleep 10

echo 
echo "Here is the fsck report"
sudo -u hdfs hdfs fsck /

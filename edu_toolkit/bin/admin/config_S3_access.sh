#!/bin/bash
# Script to automate S3 access for NGEE CDH cluster instances
# Pulls down the lastest AWS IAM credentials that permit read/write to a bucket on S3, 
# updates the hdfs core-site.xml snippet in CM, and redeploys client configs

# pull current CM configuration json from cmhost
curl -u admin:admin "http://localhost:7180/api/v9/cm/deployment" > ./cm-deployment.json

# retrieve from running CM its cluster name, HDFS service name and zookeeper service names needed for CM API calls
clusterName=$(awk '/clusters/ {getline; print $NF }' ./cm-deployment.json | sed 's/,$/ /g' | sed 's/\"//g' | sed 's/[ \t]*$//')
serviceName=$(awk '/services/ && ++ n == 1 {getline; print $NF; exit }' ./cm-deployment.json | sed 's/,$/ /g' | sed 's/\"//g' | sed 's/[ \t]*$//')
zooName=$(awk '/zookeeper_service/ && ++ n == 1 {getline; print $NF; exit }' ./cm-deployment.json | sed 's/,$/ /g' | sed 's/\"//g' | sed 's/[ \t]*$//')

# make a copy of template json file and place in working directory
mkdir -p working
cp cm-iam.json working/cm-iam.json

# get latest IAM security file from AWS - in this example, ClouderaDirectorRole is the IAM Role that has a valid S3 policy attached
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ClouderaDirectorRole > newS3sec.txt

#
# remove unwanted characters surrounding security credentials 
#
sed -i 's/\"//g' newS3sec.txt 
sed -i 's/,*$//g' newS3sec.txt

#
# re-build json with new fs.s3a security 
#
changeme1=$(awk '/AccessKeyId/{print $NF}' newS3sec.txt) 
sed -i s/CHANGEME1/$changeme1/ working/cm-iam.json

changeme2=$(awk '/SecretAccessKey/{print $NF}' newS3sec.txt)
sed -i 's|CHANGEME2|'"$changeme2"'|g' working/cm-iam.json

changeme3=$(awk '/Token/{print $NF}' newS3sec.txt)
sed -i 's|CHANGEME3|'"$changeme3"'|g' working/cm-iam.json

sed -i 's|change-zoo|'"$zooName"'|g' working/cm-iam.json


#
# Upload the modified CM Deployment JSON with an updated S3 security credentials
# Use CM API to update configuration deployment
#
curl -X PUT -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v9/clusters/$clusterName/services/$serviceName/config -d @working/cm-iam.json 

#
# Deploy cluster client configuration with the changes
#
curl -X POST -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v15/clusters/$clusterName/commands/deployClientConfig
curl -X POST -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v15/clusters/$clusterName/services/$serviceName/commands/restart


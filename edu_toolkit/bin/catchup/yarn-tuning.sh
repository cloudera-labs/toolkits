#!/bin/bash

#curl -s -X GET -u "admin:admin" -H "Content-Type:application/json" -i http://cmhost:7180/api/v18/clusters/$clusterName/services/$yarnServiceName/roles/

clusterName=$(curl -s -X GET -u "admin:admin" -i http://cmhost:7180/api/v8/clusters/ | grep name| cut -d '"' -f4)

curlURL="-s -X GET -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/"
hdfsServiceName=$(curl $curlURL | grep CD-HDFS | grep name | cut -d '"' -f4 )
if [[ "$hdfsServiceName" == "" ]]; then
	hdfsServiceName="hdfs"
fi
yarnServiceName=$(curl $curlURL | grep CD-YARN | grep name | cut -d '"' -f4 )
if [[ "$yarnServiceName" == "" ]]; then
	yarnServiceName="yarn"
fi
hiveServiceName=$(curl  $curlURL | grep CD-HIVE | grep name | cut -d '"' -f4 )
if [[ "$hiveServiceName" == "" ]]; then
	hiveServiceName="hive"
fi
hueServiceName=$(curl  $curlURL | grep CD-HUE | grep name | cut -d '"' -f4 )
if [[ "$hueServiceName" == "" ]]; then
	hueServiceName="hue"
fi
impalaServiceName=$(curl $curlURL | grep CD-IMPALA | grep name | cut -d '"' -f4 )
if [[ "$impalaServiceName" == "" ]]; then
	impalaServiceName="impala"
fi
oozieServiceName=$(curl $curlURL | grep CD-OOZIE | grep name | cut -d '"' -f4 )
if [[ "$oozieServiceName" == "" ]]; then
	oozieServiceName="oozie"
fi
soyarnServiceName=$(curl $curlURL | grep CD-SPARK2_ON_YARN | grep name | cut -d '"' -f4 )
if [[ "$soyarnServiceName" == "" ]]; then
	soyarnServiceName="spark2_on_yarn"
fi

gatewayDefaultGroup=$yarnServiceName"-GATEWAY-BASE"
rmanDefaultGroup=$yarnServiceName"-RESOURCEMANAGER-BASE"
nmanDefaultGroup=$yarnServiceName"-NODEMANAGER-BASE"
nmanOneDefaultGroup=$yarnServiceName"-NODEMANAGER-1"

#adjust gatewayDefaultGroup settings
curl -s -X PUT -u "admin:admin" -H "Content-Type:application/json" -i http://cmhost:7180/api/v18/clusters/$clusterName/services/$yarnServiceName/roleConfigGroups/$gatewayDefaultGroup/config -d "{\"items\":[{\"name\":\"mapreduce_map_memory_mb\",\"value\":\"1024\"},{\"name\":\"mapreduce_map_java_opts_max_heap\",\"value\":\"1073741824\"},{\"name\":\"mapreduce_reduce_memory_mb\",\"value\":\"1024\"},{\"name\":\"mapreduce_reduce_java_opts_max_heap\",\"value\":\"1073741824\"},{\"name\":\"yarn_app_mapreduce_am_max_heap\",\"value\":\"1073741824\"}]}" 

#adjust rmanDefaultGroup settings
curl -s -X PUT -u "admin:admin" -H "Content-Type:application/json" -i http://cmhost:7180/api/v18/clusters/$clusterName/services/$yarnServiceName/roleConfigGroups/$rmanDefaultGroup/config -d "{\"items\":[{\"name\":\"yarn_scheduler_maximum_allocation_vcores\",\"value\":\"1\"},{\"name\":\"yarn_scheduler_maximum_allocation_mb\",\"value\":\"8192\"}]}" 

#adjust nmanDefaultGroup settings
curl -s -X PUT -u "admin:admin" -H "Content-Type:application/json" -i http://cmhost:7180/api/v18/clusters/$clusterName/services/$yarnServiceName/roleConfigGroups/$nmanDefaultGroup/config -d "{\"items\":[{\"name\":\"yarn_nodemanager_resource_memory_mb\",\"value\":\"10240\"}]}"

#adjust nmanOneGroup settings
curl -s -X PUT -u "admin:admin" -H "Content-Type:application/json" -i http://cmhost:7180/api/v18/clusters/$clusterName/services/$yarnServiceName/roleConfigGroups/$nmanOneDefaultGroup/config -d "{\"items\":[{\"name\":\"yarn_nodemanager_resource_memory_mb\",\"value\":\"10240\"}]}"

	
echo
echo "Restarting services..."
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$yarnServiceName/commands/restart
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$soyarnServiceName/commands/restart
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$hiveServiceName/commands/restart
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$impalaServiceName/commands/restart
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$oozieServiceName/commands/restart
curl -s -X POST -u "admin:admin" -i http://localhost:7180/api/v10/clusters/$clusterName/services/$hueServiceName/commands/restart
echo
echo "Deploying client configs..."
#calling this on Hive will redeploy the configs for all the other services as well
curl -s -X POST -u "admin:admin" -H "Content-Type:application/json" -i http://cmhost:7180/api/v18/clusters/$clusterName/commands/deployClientConfig/ -d "{\"items\":[\"$hiveServiceName\"]}"





#!/bin/bash
cd /home/training/config

setup(){
	sudo rm -rf /home/training/config/working
	mkdir /home/training/config/working
	cp /home/training/config/addCMS.json /home/training/config/working/addCMS.json
}

gather_info(){
	curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/hosts|grep 'hostId\|ipAddress\|hostname' > /home/training/config/CMhostInfo.txt
	
	sed -i 's/"//g' /home/training/config/CMhostInfo.txt
	sed -i 's/,//g' /home/training/config/CMhostInfo.txt

	newHostID=$(cat /home/training/config/CMhostInfo.txt | sed -n 1p | awk '{print $3}')
	newIP=$(cat /home/training/config/CMhostInfo.txt | sed -n 2p | awk '{print $3}')
	newHostname=$(cat /home/training/config/CMhostInfo.txt | sed -n 3p | awk '{print $3}')
}

add_mgmt_services(){

	curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/cm/trial/begin

	sudo sed -i "s/replace-host-id/$newHostID/g" /home/training/config/working/addCMS.json
	sudo sed -i "s/replace-ip-addr/$newIP/g" /home/training/config/working/addCMS.json
	sudo sed -i "s/replace-hostname/$newHostname/g" /home/training/config/working/addCMS.json

	echo 
	echo "deploying Cloudera Management Service to cmhost"
	curl -s -X PUT -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/cm/deployment -d @/home/training/config/working/addCMS.json
}


setup 
gather_info
add_mgmt_services

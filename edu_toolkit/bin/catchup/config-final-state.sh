#!/bin/bash

# ------------------------------[ Documentation ]----------------------------------------
#
# This script performs the installation of CM agents, Cloudera management services,
# and to reset the state of the cluster to a point after after exercise, 'Working with HDFS'
# has been completed. It assumes that symbolic hostnames are already established
# and that there is IP addressability and passwordless SSH
# across the private interfaces of the nodes.
#
# The commands for CM installation are all run from the cmhost server.
#
# (1) Check that the script is running on cmhost, if not exit.
#    The add-cluster-non-ha script depends on named nodes and that it is homed on cmhost
#
# (2) Echo's the hostname where the script is running
#
# (3) Check for existence of Cloudera manager servers, and verify if running
#       Restart Cloudera manager server, and verify installation is okay
#       Wait for 15 seconds for server to start up, and check again
#       Only continue to next function if Cloudera manager is running and reachable
#
# (4) Install, enable and start CM agents to every nodes in the cluster
#
# (5) Install Cloudera Management Service (CMS), and start it up
#       Wait for 45 seconds, and verify CMS is running
#       Only continue to next function if CMS starts up, and is okay
#
# (6) Import CM template to a the lab exercise state with the following services installed and configured:
#       - CDH 7.1.3
#       - HDFS
#       - Hive
#       - Hive on tez
#       - Nifi
#       - Kafka
#       - Hue
#       - Impala
#       - Oozie
#       - Spark
#       - Tez
#       - Sqoop
#       - Yarn
#       - Yarn Queue Manager
#       - Zookeeper
#
#
# (7) Configure command line tools to use CDH7.1.3 as default
#


nocheck="-o StrictHostKeyChecking=no"

#source /var/tmp/deployments/vars-cdh514.sh
#source /var/tmp/deployments/vars-cdh515.sh


if [ $HOSTNAME != "cmhost" ]; then
	echo "This script should only be run on cmhost. It appears you are running this on " $HOSTNAME
	echo "Exiting..."
	sleep 5
	exit 0
fi
echo "verified the hostname is cmhost. Continuing..."

verify_cm_server(){
	#verify installed
	check=$(sudo rpm -qa|grep cloudera-manager-server)
	if [[ "$check" == "" ]]; then
		echo
		echo "You must first install CM server before running this script. You can do this by running install-cmserver.sh."
		echo "Exiting"
		exit 1
	fi


	#verify running
	cmApiTest=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/cm/version'|grep snapshot|cut -d " " -f5-|sed 's/[",]//g')
	if [[ "$cmApiTest" == "" ]]; then
		echo
		echo "CM Server installed but not running. Restarting CM Server now..."
		sudo systemctl restart cloudera-scm-server 
		cmApiTest=""
		COUNTER=0
		while [[ $cmApiTest != "false" && $COUNTER -le 20 ]]
			do
			cmApiTest=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/cm/version'|grep snapshot|cut -d " " -f5-|sed 's/[",]//g')
			sleep 15
			COUNTER=$((COUNTER+1))
			if [[ $COUNTER -eq 2 ]]; then
				check=$(sudo systemctl status cloudera-scm-server | grep Active: | cut -d " " -f5)
				if [[ "$check" == "failed" ]]; then 
					echo "********************************************************************************"
					echo ""
					echo "There is a problem while running the reset_cluster script during CM Server installation."
					echo "Please run reset_cluster.sh again."
					echo "Exiting."
					echo ""
					echo "********************************************************************************"
					exit 1
			    else
			    	echo "CM Server installation looks OK. Moving on..."
				fi
			elif [[ $COUNTER -eq 5 ]]; then
				sudo systemctl restart cloudera-scm-server

				sudo systemctl status cloudera-scm-server
			elif [[ $COUNTER -eq 10 ]]; then
				echo "Restarting CM Server one last time."

				sudo systemctl restart cloudera-scm-server
			elif [[ $COUNTER -eq 20 ]]; then
				echo "********************************************************************************"
				echo ""
				echo "The test to reach the CM Server has failed after 20 tries."
				echo "Please run reset_cluster.sh again."
				echo "Exiting."
				echo ""
				echo "********************************************************************************"
				exit
			fi
		done
	fi
}

install_cm_agents(){
	echo
	echo "Installing CM agent on cmhost"
    ssh training@cmhost -o StrictHostKeyChecking=no /home/training/training_materials/admin/scripts/catchup/installAgents.sh
}

add_mgmt_services(){
	echo
	echo "Adding CM mgmt services via CM API..."
    ssh training@cmhost -o StrictHostKeyChecking=no /home/training/training_materials/admin/scripts/add-mgmt-service.sh 
}

apply_cm_template(){
	echo 
	echo "Applying cluster template via CM API..."
    sleep 10
	url="http://cmhost:7180/api/v12/cm/importClusterTemplate"
	passJson="-d @/home/training/training_materials/admin/scripts/catchup/json/admin20_PROD_FINAL.json"
	respo=$(curl -s -X POST -H "Content-Type:application/json" -u admin:admin $url $passJson)
	echo "Starting import - API response:"
	echo $respo
	procId=$(echo $respo | awk '{print $4}' | sed 's/,//') 

	echo 
	echo "NOTE: This will take 20 to 30 minutes to complete. Please be patient..."
	echo 

	#verify status 
	xvResp=0
	xcount=0
	while [ $xvResp -eq 0 ] 
	do 
		#wait for the import to complete
		status=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v1/commands/$procId |grep active)
		s1=$(echo $status |awk '{print $3}'|sed s/,//)
		
		if [[ "$s1" == "false" ]]; then 
			printf "\n"
			echo "The template import command has completed. Verifying successful import."
			echo
			#check if the import succeeded
			tresult=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v1/commands/$procId |grep '"success"')
			t1=$(echo $tresult |awk '{print $3}'|sed s/,// )
			
			if [[ "$t1" == "true" ]]; then 
				echo "Cluster template import was successful. "
				echo
				xvResp=1
			else
				echo
				echo "ERROR: The template did not import successfully."
				echo 
				echo "Please re-run reset-cluster.sh. Exiting."
                sleep 10
				exit 1
			fi
		else
			#import is still in progress
			xcount=0
			while [ $xcount -lt 15 ];
			do
				xcount=$(( $xcount +1 ))
				printf "."
				sleep 1	
			done

		fi
	done
}

config_hdfs_settings() {
	echo 
	echo "Add HDFS local dirs settings."

	hdfsURL="http://localhost:7180/api/v9/clusters/Cluster1/services/hdfs/roleConfigGroups"

	cp /home/training/training_materials/admin/scripts/catchup/json/hdfs1.json /home/training/config/working/
	cp /home/training/training_materials/admin/scripts/catchup/json/hdfs2.json /home/training/config/working/

	curl -X PUT -H "Content-Type:application/json" -u admin:admin $hdfsURL/hdfs-DATANODE-1 -d @/home/training/config/working/hdfs1.json
	curl -X PUT -H "Content-Type:application/json" -u admin:admin $hdfsURL/hdfs-DATANODE-2 -d @/home/training/config/working/hdfs2.json

}

config_yarn_queue_manager_prereq () {
    ssh training@master-1 -o StrictHostKeyChecking=no 'sudo rm -rf /var/lib/hadoop-yarn; \
    sudo mkdir /var/lib/hadoop-yarn; sudo chmod 755 /var/lib/hadoop-yarn; sudo chown yarn:hadoop /var/lib/hadoop-yarn' &> /dev/null
#   echo
#   echo "Add Yarn local dirs settings."

#   yarnURL="http://localhost:7180/api/v9/clusters/Cluster1/services/yarn/roleConfigGroups"

#   cp /home/training/training_materials/admin/scripts/catchup/json/yarn1.json /home/training/config/working/
#   cp /home/training/training_materials/admin/scripts/catchup/json/yarn2.json /home/training/config/working/

#   curl -X PUT -H "Content-Type:application/json" -u admin:admin $yarnURL/yarn-NODEMANAGER-1 -d @/home/training/config/working/yarn1.json
#   curl -X PUT -H "Content-Type:application/json" -u admin:admin $yarnURL/yarn-NODEMANAGER-2 -d @/home/training/config/working/yarn2.json
}

set_cmdline_defaults_713() {

	# Use Expect script to configure command line tools to use CDH5.14 as default:
	# hdfs, yarn, beeline, mapred

	#Configure hdfs to use CDH5.14
	expect -c "set timeout -1
spawn sudo alternatives --config hdfs
expect -re \"Enter *\"
send \"1\r\"
expect eof"

	#Configure yarn to use CDH5.14
	expect -c "set timeout -1
spawn sudo alternatives --config yarn
expect -re \"Enter *\"
send \"1\r\"
expect eof"


	#Configure beeline to C5.14
	expect -c "set timeout -1
spawn sudo alternatives --config beeline
expect -re \"Enter *\"
send \"1\r\"
expect eof"

	#Configure mapred to C5.11
	expect -c "set timeout -1
spawn sudo alternatives --config mapred
expect -re \"Enter *\"
send \"1\r\"
expect eof"

}


#verify_cm_server
install_cm_agents | dialog --title "Install CM Agent" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
add_mgmt_services | dialog --title "Add CMS Services" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
config_yarn_queue_manager_prereq 
# Verify configured hosts before importing CM template
hosts_configured=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/hosts'|grep 'hostId\|hostname' | grep -i hostname | wc -l)
if [[ $hosts_configured != 6 ]];  then
  echo "***************************"
  #echo "ERROR : CM agent did not get configured as should be, please do investigate and run the re-set script again!"
  msg="CM agent did not get configured as should be on one or more node(s), please do investigate and run the re-set script again"
  dialog --title "Fatal Error" --backtitle "Cluster Reset"  --no-collapse  --infobox "$msg" 6 60
  sleep 10
  exit 1
else
 apply_cm_template | dialog --title "Configure cluster with required services" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
 set_cmdline_defaults_7x | dialog --title "Set CLI defaults" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
fi

#config_hdfs_settings
#config_yarn_settings

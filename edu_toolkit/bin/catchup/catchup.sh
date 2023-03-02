#!/bin/bash
echo "RUNNING catchup.sh on " $HOSTNAME " at " $(date)

#source /var/tmp/deployments/vars-cdh514.sh
#source /var/tmp/deployments/vars-cdh515.sh

#Check that the user is running this script from elephant..
if [ $HOSTNAME != "cmhost" ]; then
	echo "This script should only be run on elephant. It appears you are running this on " $HOSTNAME
	echo "Exiting..."
	sleep 5
	exit 0
fi
echo "Verified the hostname is" $HOSTNAME". Continuing..."

SCRIPTS_DIR=/home/training/training_materials/admin/scripts
ACTION=$1
#PARCEL_NAME="CDH-5.9.0-1.cdh5.9.0.p0.23-el6.parcel"
#PARCEL_SHORT_NAME="CDH-5.9.0-1.cdh5.9.0.p0.23"

PARCEL_NAME=$CDH_PARCELEL7
PARCEL_SHORT_NAME=$CDH_PARCEL_SHORT_NAME


##############################################################
## 				CALL CM FUNCTION			 				##
##############################################################

callCmApi () {
	echo "********************************************"
	echo "CM API: " $(echo $1 | cut -c 24-) 
	echo "********************************************"

	# Other functions use this function to issue calls to CM. 
	# Requires the URL and TYPE of call (one of POST, GET, or PUT)
	# Optionally takes a JSON request body in the form of a quoted "-d @/dir/filename"
	# Processing will stay here until the command completes

	URL=$1
	TYPE=$2
	
	echo 
	echo "URL: " $URL
	echo "Type: "$TYPE
	
	if [[ $# -eq 3 ]]; then
		passJSON=$3
		echo "Request Body: "$passJSON
	fi

	echo
	if [[ $# -eq 3 ]]; then
		response=$(curl -X $TYPE -H "Content-Type:application/json" -u admin:admin $URL $passJSON)
		echo
	else
		response=$(curl -X $TYPE -H "Content-Type:application/json" -u admin:admin $URL)
	fi
		
	#capture json response as an array
	declare -a initResp=$(echo $response | python -m json.tool)	
	
	#echo "Full INITIAL response:"
	#printf '%s\n' "${initResp[@]}" 
	echo
	echo "Parsed INITIAL response results."
	id=$(printf '%s\n' "${initResp[@]}" | grep -m 1 '"id"' | awk '{print $2}' | sed 's/,//g') 
	initActive=$(printf '%s\n' "${initResp[@]}" | grep -m 1 '"active"'| awk '{print $2}' | sed 's/,//g')
	initResultMsg=$(printf '%s\n' "${initResp[@]}" | grep -m 1 '"resultMessage"'| cut -d " "  -f6- | sed 's/[,\"]//g')
	initSuccess=$(printf '%s\n' "${initResp[@]}" | grep -m 1 '"success"'| awk '{print $2}') 

	echo "--------------------"
	echo "ID: "$id
	echo "Active: "$initActive
	echo "Result Message: "$initResultMsg
	echo "Success: "$initSuccess
	echo "--------------------"
	statusURL="http://cmhost:7180/api/v9/commands/$id"
	echo "statusURL: "$statusURL

	active=$initActive
	while [[ $active == "true" ]]
		do 
		#wait 10 seconds and check again
		echo "Checking status..."
		sleep 10
		statusResponse=$(curl -X GET -H "Content-Type:application/json" -u admin:admin $statusURL)

		declare -a statusJson=$(echo $statusResponse | python -m json.tool)	
		
		#Parse latest status response results."
		active=$(printf '%s\n' "${statusJson[@]}" | grep -m 1 '"active"' | awk '{print $2}' | sed 's/,//g') 
		dispMsgTest=$active
		statResultMsg=$(printf '%s\n' "${statusJson[@]}" | grep '"resultMessage"'| tail -1 | cut -d " "  -f6- | sed 's/[,\"]//g')

		if [[ $dispMsgTest == "false" ]]; then
			echo "--------------------"
			echo "Result Message: "$statResultMsg
			echo "--------------------"
			echo
		elif [[ $dispMsgTest == "true" ]]; then
			echo $(printf '%s\n' "${statusJson[@]}")
		fi
		
		active=$active
	done
}

checkPending () {
	service=$1
	#This general function will query for pending commands on the service specified.
	#Pending commands (if they exist) can cause newer commands to fail.
	echo
	echo "Waiting for any pending "$1 "commands to complete."
	echo 

	checkCommands=$(curl -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v9/clusters/cluster/services/$1/commands|grep -C4 items|grep active|cut -d " " -f7- | sed 's/[,:"]//g')
	echo $1" commands currently running? "$checkCommands

	while [[ $checkCommands == "true" ]];
		do
		echo "Commands still running? "$checkCommands
		sleep 10
		checkCommands=$(curl -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v9/clusters/cluster/services/$1/commands|grep -C4 items|grep active|cut -d " " -f7- | sed 's/[,:"]//g')
	done

	echo "The "$1" service has no more pending commands."
	echo
	echo "Showing GET results again."
	echo
	curl -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v9/clusters/cluster/services/$1/commands
}

##############################################################
## 				BACKUP DEPLOYMENT FUNCTION	 				##
##############################################################

backupDeployment () {
	echo "backing up current deployment."
	mkdir -p $2/catchup/working
	curl -X GET -H "Content-Type:application/json" -u admin:admin \
	'http://cmhost:7180/api/v9/cm/deployment' > $2/catchup/working/$1
}
##############################################################
## 				GENERATE JSON FUNCTION		 				##
##############################################################

generateJson () {
	# Make a copy of deployment#.json
	echo
	echo "Source deployment is: " $1 # catchup/deployment1.json
	echo "Scripts dir is: " $2		 # /home/training/training_materials/admin/scripts
	echo "Copying template."
	
	mkdir -p $2/working
	echo ls -l $2/working" exists"
	
	echo ">>Copying "$2/catchup/$1" to $2/catchup/working/$1"
	cp $2/catchup/$1 $2/catchup/working/$1

	OUTPUT_FILE=$2/catchup/working/$1
	echo "OUTPUT_FILE is " $OUTPUT_FILE
	
	echo "********************************************"
	echo "Editing " $OUTPUT_FILE " for new environment"
	echo "********************************************"
	echo ""
	echo "Capturing the hostIds and ipAddresses of the current cluster"
	echo
	# Capture the hostId, ipAddress, and hostname from the new installation
	curl -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/hosts'|grep 'hostId\|ipAddress\|hostname' > /home/training/training_materials/admin/scripts/catchup/working/hostIds.txt
	
	# Strip out the quotes and commas
	sed -i 's/"//g' $2/catchup/working/hostIds.txt
	sed -i 's/,//g' $2/catchup/working/hostIds.txt
	
	echo
	echo "Updating host ids."
	
	# Old hostIds in deployment1.json template  - UPDATED 20161027
	OldEId1="i-f2279465"
	OldHId1="i-f5279462"
	OldLId1="i-f7279460"
	OldMId1="i-f6279461"
	OldTId1="i-f4279463"

	# Old hostIds in all other templates - only need to update if these jsons are captured new
	#found in addFlumeService, addHiveService, addImpalaService, addSparkGateway, addSqoopService, addZHKService
	OldEId="68185aa5-b9c6-49f6-8af0-a880ea253ec8" 
	#found in addFlumeService, addImpalaService, addZHKService
	OldHId="9bcb38ca-9a2a-4f3d-a4bc-d445b123b338"
	#not found anywhere
	OldLId="fdc0a299-c0af-46d5-93bd-1b47b767b6c2"
	#found in addHttpFs, addHueService, addImpalaService, addOozieService, addSparkService
	OldMId="61f8e12f-e474-4d64-9065-85881ddee4c5"
	#found in addImpalaService, addZHKService
	OldTId="d352ffb7-03f3-4b81-8163-af06a0378634"

	# New hostIds (set variables)
	NewEId=$(cat $2/catchup/working/hostIds.txt | sed -n 1p | awk '{print $3}')
	NewHId=$(cat $2/catchup/working/hostIds.txt | sed -n 4p | awk '{print $3}')
	NewLId=$(cat $2/catchup/working/hostIds.txt | sed -n 7p | awk '{print $3}')
	NewMId=$(cat $2/catchup/working/hostIds.txt | sed -n 10p | awk '{print $3}')
	NewTId=$(cat $2/catchup/working/hostIds.txt | sed -n 13p | awk '{print $3}')
	
	# Update new json with correct hostIds
	sed -i "s/$OldEId1/$NewEId/g" $OUTPUT_FILE
	sed -i "s/$OldHId1/$NewHId/g" $OUTPUT_FILE
	sed -i "s/$OldLId1/$NewLId/g" $OUTPUT_FILE
	sed -i "s/$OldMId1/$NewMId/g" $OUTPUT_FILE
	sed -i "s/$OldTId1/$NewTId/g" $OUTPUT_FILE
	
	sed -i "s/$OldEId/$NewEId/g" $OUTPUT_FILE
	sed -i "s/$OldHId/$NewHId/g" $OUTPUT_FILE
	sed -i "s/$OldLId/$NewLId/g" $OUTPUT_FILE
	sed -i "s/$OldMId/$NewMId/g" $OUTPUT_FILE
	sed -i "s/$OldTId/$NewTId/g" $OUTPUT_FILE

	echo "Updating ip addresses."
		
	# Old IPs in deployment1.json template - UPDATED 20161027
	OldEIp1="10.0.0.61"
	OldTIp1="10.0.0.59"
	OldHIp1="10.0.0.60"
	OldMIp1="10.0.0.57"
	OldLIp1="10.0.0.68"	
	
	# Old IPs in all other source deployment#.json templates
	OldEIp="172.30.0.81"
	OldTIp="172.30.0.82"
	OldHIp="172.30.0.80"
	OldMIp="172.30.0.79"
	OldLIp="172.30.0.78"
	
	# New IPs  (set variables)
	NewEIp=$(cat $2/catchup/working/hostIds.txt | sed -n 2p | awk '{print $3}')
	NewHIp=$(cat $2/catchup/working/hostIds.txt | sed -n 5p | awk '{print $3}')
	NewLIp=$(cat $2/catchup/working/hostIds.txt | sed -n 8p | awk '{print $3}')
	NewMIp=$(cat $2/catchup/working/hostIds.txt | sed -n 11p | awk '{print $3}')
	NewTIp=$(cat $2/catchup/working/hostIds.txt | sed -n 14p | awk '{print $3}')

	# Update new json with correct IPs
	sed -i "s/$OldEIp1/$NewEIp/g" $OUTPUT_FILE
	sed -i "s/$OldTIp1/$NewTIp/g" $OUTPUT_FILE
	sed -i "s/$OldHIp1/$NewHIp/g" $OUTPUT_FILE
	sed -i "s/$OldLIp1/$NewLIp/g" $OUTPUT_FILE
	sed -i "s/$OldMIp1/$NewMIp/g" $OUTPUT_FILE
	
	sed -i "s/$OldEIp/$NewEIp/g" $OUTPUT_FILE
	sed -i "s/$OldTIp/$NewTIp/g" $OUTPUT_FILE
	sed -i "s/$OldHIp/$NewHIp/g" $OUTPUT_FILE
	sed -i "s/$OldLIp/$NewLIp/g" $OUTPUT_FILE
	sed -i "s/$OldMIp/$NewMIp/g" $OUTPUT_FILE

	echo "Updating role names."
	
	# IMPORTANT: KEEP THE DASHES
	# Old RoleName suffixes in deployment1.json template	- UPDATED 20161027
	hRNSuffix1="-31bba75e1a6a6ca2d1c21774c5627eba"		
	tRNSuffix1="-ffe8deea1116b9d84fb235ceaac16b46"	
	eRNSuffix1="-1be47b55fd3c27d34c232076e30942f0"	
	lRNSuffix1="-0f47f369283b5994b02feb0f827890ce"	
	mRNSuffix1="-225acba6836dbb50d0e23a6e8649601b"	

	# Old RoleName suffixes in all other deployment#.json templates
	hRNSuffix="-4cb419c64a872e50f7afa57cd6ab6863"
	tRNSuffix="-efab8ae640b9117c1ecf297b1ed25560"
	eRNSuffix="-814026d35bd67b44573c805843e63664"
	lRNSuffix="-935d1193dfb1fe44a3ee64477b8f10c2"
	mRNSuffix="-c838e0b3b26cd439ffd2442fc1047eb1"
	
	# THESE PROBABLY NEED UPDATING IN .JSON'S LATER THAN DEPLOYMENT1
	sparkRN="spar40365358-SPARK_YARN_HISTORY_SERVER-c838e0b3b26cd439ffd2442fc"
	sparkRN2="spark_on_yarn-GATEWAY-c838e0b3b26cd439ffd2442fc1047eb1"
	flumeRN="flume-AGENT-4cb419c64a872e50f7afa57cd6ab6863"
	flumeRN2="flume-AGENT-814026d35bd67b44573c805843e63664"

	# Update new json with correct role names
	sed -i "s/$hRNSuffix1/h/g" $OUTPUT_FILE
	sed -i "s/$tRNSuffix1/t/g" $OUTPUT_FILE
	sed -i "s/$eRNSuffix1/e/g" $OUTPUT_FILE
	sed -i "s/$lRNSuffix1/l/g" $OUTPUT_FILE
	sed -i "s/$mRNSuffix1/m/g" $OUTPUT_FILE
	
	sed -i "s/$hRNSuffix/h/g" $OUTPUT_FILE
	sed -i "s/$tRNSuffix/t/g" $OUTPUT_FILE
	sed -i "s/$eRNSuffix/e/g" $OUTPUT_FILE
	sed -i "s/$lRNSuffix/l/g" $OUTPUT_FILE
	sed -i "s/$mRNSuffix/m/g" $OUTPUT_FILE
	sed -i "s/$sparkRN/sparkHistServer1/g" $OUTPUT_FILE
	sed -i "s/$sparkRN2/sparkYarnGatway1/g" $OUTPUT_FILE
	sed -i "s/$flumeRN/flumeAGENT1/g" $OUTPUT_FILE
	sed -i "s/$flumeRN2/flumeAGENT2/g" $OUTPUT_FILE
	
	echo "Copying resulting JSON to cmhost."
	echo
	ssh training@cmhost mkdir -p $SCRIPTS_DIR/catchup/working
	scp $OUTPUT_FILE training@cmhost:$SCRIPTS_DIR/catchup/working/$1	
} 

##############################################################
## 				PUT JSON FUNCTION			 				##
##############################################################

putJson () {
	echo
	echo "***************************"
	echo "PUT JSON deployment with updated hostIds, IPs, and role names to /cm/deployment"
	echo "***************************"

	curl -X PUT -H "Content-Type:application/json" -u admin:admin \
	'http://cmhost:7180/api/v9/cm/deployment?deleteCurrentDeployment=true' \
	-d @$2/catchup/working/$SOURCE_DEPLOYMENT

	echo 
	echo "Finished PUT of JSON deployment with updated hostIds, IPs, and role names to /cm/deployment."
	echo "Waiting 10 seconds."
	sleep 10
}

##############################################################
## 				ACTIVATE PARCELS							##
##############################################################

activateParcels () {
	echo "***************************"
	echo "Downloading, distributing, and activating Parcels."
	echo "***************************"
	echo
	echo "Copying parcel to parcel-cache on cmhost"
	sudo cp /opt/cloudera/parcel-repo/$PARCEL_NAME \
	/opt/cloudera/parcel-cache/$PARCEL_NAME 2>&1 | sed -e 's/^/cmhost output> /' &
	echo
	echo "Copying parcel to parcel-cache on master-1"
	ssh training@master-1 -o StrictHostKeyChecking=no \
	sudo cp /opt/cloudera/parcel-repo/$PARCEL_NAME \
	/opt/cloudera/parcel-cache/$PARCEL_NAME 2>&1 | sed -e 's/^/master-1 output> /' &
	echo
	echo "Copying parcel to parcel-cache on master-2"
	ssh training@master-2 -o StrictHostKeyChecking=no \
	sudo cp /opt/cloudera/parcel-repo/$PARCEL_NAME \
	/opt/cloudera/parcel-cache/$PARCEL_NAME 2>&1 | sed -e 's/^/master-2 output> /' &
	echo
	echo "Copying parcel to parcel-cache on worker-1"
	ssh training@worker-1 -o StrictHostKeyChecking=no \
	sudo cp /opt/cloudera/parcel-repo/$PARCEL_NAME \
	/opt/cloudera/parcel-cache/$PARCEL_NAME 2>&1 | sed -e 's/^/worker-1 output> /' &
	echo
	echo "Copying parcel to parcel-cache on worker-2"
	ssh training@worker-2 -o StrictHostKeyChecking=no \
	sudo cp /opt/cloudera/parcel-repo/$PARCEL_NAME \
	/opt/cloudera/parcel-cache/$PARCEL_NAME 2>&1 | sed -e 's/^/worker-2 output> /' &
	echo 
	echo "Copying parcel to parcel-cache on worker-3"
	ssh training@worker-3 -o StrictHostKeyChecking=no \
	sudo cp /opt/cloudera/parcel-repo/$PARCEL_NAME \
	/opt/cloudera/parcel-cache/$PARCEL_NAME 2>&1 | sed -e 's/^/worker-3 output> /' &
	echo
	echo "Parcel copying in the classroom environment is local to each machine. This will only take about a minute to complete."
	echo
	#Run the above commands in parallel but wait for all to complete before proceeding
	wait
	echo
	echo "Parcel downloading done."
	
	echo
	echo "Waiting for parcel distribution and activation to complete."
	echo
	parcelStatus=""
	while [[ $parcelStatus != "ACTIVATED" ]]
		do
		parcelStatus=$(curl -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/clusters/cluster/parcels/products/CDH/versions/5.9.0-1.cdh5.9.0.p0.23' | grep stage | cut -d " " -f5-|sed 's/[",]//g')
		echo $parcelStatus
		sleep 10
	done
	echo 
	echo "Parcels now activated."		
}

##############################################################
## 				FIRST RUN									##
##############################################################	

firstRun () {
	echo "***********************************************************************************"
	echo "Calling First Run to prep a new cluster."
	echo $(ssh -o StrictHostKeyChecking=no training@cmhost date)
	echo "***********************************************************************************"
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/commands/firstRun POST
	#After calling this, you may see an error in the commands log related to
	#not creating the MR2 job history dir. We manually create this in the
	#configHDFS () function in this script.
}

##############################################################
## 				CM MANAGEMENT SERVICES						##
##############################################################
startCMMS () {
	echo ""
	echo "Starting the Cloudera Management Services"
	echo
	
	callCmApi http://cmhost:7180/api/v9/cm/service/commands/start POST
	
}

##############################################################
## 				HDFS FUNCTIONS								##
##############################################################

firstRunHDFS () {
	echo
	echo ""
	echo "Calling firstRun on HDFS."
	echo
	#this formats the NN and starts HDFS.
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands/firstRun POST
	
	#don't move on until HDFS has started.
	hdfsStat=""
	while [[ $hdfsStat != "STARTED" ]]
		do
		hdfsStat=$(curl -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/clusters/cluster/services/hdfs'|grep STARTED|cut -d " " -f5-|sed 's/[",]//g')
		echo $hdfsStat
		sleep 10
	done
}

updateDNPerms () {	
	echo
	echo "Updating DataNode Directory Permissions to match manual exercise completion and to avoid an Impala warning later."
	echo
	checkPending "hdfs"
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleConfigGroups/hdfs-DATANODE-1/config PUT "-d @$SCRIPTS_DIR/catchup/setDNperms.json"
	checkPending "hdfs"
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleConfigGroups/hdfs-DATANODE-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/setDNperms.json"
}

restartHDFS () {
	echo
	echo "***************************"
	echo "Restarting HDFS service"
	echo "***************************"
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands/restart POST
}

configHDFS () {	
	echo
	echo "***************************"
	echo "Configuring HDFS directories, permissions, and ownership..."
	echo "***************************"
	echo

	echo ""
	echo "If some directories are found to already be present, please ignore."
	echo ""
	#mapred user needs to be able to write to / in hdfs, otherwise YARN RM and JHS services won't start.
	sudo -u hdfs hdfs dfs -chmod 775 /
	
	sudo -u hdfs hdfs dfs -mkdir /user
	sudo -u hdfs hdfs dfs -chmod 755 /user
	
	#/user/history with user mapred group hadoop and permission 777
	sudo -u hdfs hdfs dfs -mkdir /user/history
	sudo -u hdfs hdfs dfs -chmod 777 /user/history
	sudo -u hdfs hdfs dfs -chown mapred:hadoop /user/history
	
	sudo -u hdfs hdfs dfs -mkdir /user/history/done
	sudo -u hdfs hdfs dfs -chmod 770 /user/history/done
	sudo -u hdfs hdfs dfs -chown mapred:hadoop /user/history/done
	sudo -u hdfs hdfs dfs -mkdir /user/history/done_intermediate
	sudo -u hdfs hdfs dfs -chmod 1777 /user/history/done_intermediate 
	sudo -u hdfs hdfs dfs -chown mapred:hadoop /user/history/done_intermediate
	
	sudo -u hdfs hdfs dfs -chmod 1777 /tmp
	
	sudo -u hdfs hdfs dfs -mkdir /tmp/logs
	sudo -u hdfs hdfs dfs -chmod 1777 /tmp/logs
	sudo -u hdfs hdfs dfs -chown mapred:hadoop /tmp/logs
	
	#These are specific to the install cluster exercise
	if [ ! -f /home/training/training_materials/admin/data/shakespeare.txt ]; then
			echo
			echo "Unzipping shakespeare.txt and placing in HDFS."
			echo
			cd /home/training/training_materials/admin/data
			gunzip shakespeare.txt.gz
			hdfs dfs -put shakespeare.txt /tmp
		else 
			echo
			echo "shakespeare.txt already unzipped. Placing in HDFS."
			echo
			hdfs dfs -put /home/training/training_materials/admin/data/shakespeare.txt /tmp
	fi
	
	#Restart ReportsManager to ensure the CM HDFS File Browser interface works
	callCmApi http://cmhost:7180/api/v9/cm/service/roleCommands/restart POST "-d @/home/training/training_materials/admin/scripts/catchup/reportsManager.json"
}

exerciseHDFS () {
	echo
	echo "Creating /user/training dir in HDFS."
	echo
	sudo -u hdfs hdfs dfs -mkdir -p /user/training
	sudo -u hdfs hdfs dfs -chown training /user/training

	echo
	echo "Creating /user/training/weblog dir in HDFS."
	echo
	sudo -u hdfs hdfs dfs -mkdir /weblogs
	sudo -u hdfs hdfs dfs -chown training /weblogs

	echo
	echo "Uploading access_log to weblog dir in HDFS."
	echo
	cd ~/training_materials/admin/data
	gunzip access_log.gz
	hdfs dfs -put ~/training_materials/admin/data/weblogs* /weblogs/

	echo
	echo "Uploading Google Ngrams Dataset *[a-e] to /tmp/ngrams dir in HDFS."
	echo
	hdfs dfs -mkdir /tmp/ngrams
	hdfs dfs -put /ngrams/unzipped/*[a-e] /tmp/ngrams/

}

##############################################################
## 				DEPLOY CLIENT CONFIGURATIONS				##
##############################################################
deployCC () {
	#Redeploy client config (I actually did this before formatting the namenode when it worked the first time
	echo 
	echo ""
	echo "Deploying client configurations"
	echo ""
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/commands/deployClientConfig POST

}

##############################################################
## 				 YARN/MR/SPARK								##
##############################################################

startYARN () {
	echo
	echo ""
	echo "Starting YARN service"
	echo ""
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/commands/start POST
	
}

restartYARN () {
	echo
	echo ""
	echo "Restarting YARN service"
	echo ""
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/commands/restart POST
	
}

runMRJobs1 () {

	echo
	echo "Try deleting files from HDFS in case this job was run before and no cleanup was done."
	echo
	hdfs dfs -rm -r counts
	
	#Commenting out this first MR job run because it is not really helpful for the catchup scripts and just makes this script take longer.
	#echo
	#echo "***************************"
	#echo "Running a WordCount MR job." 
	#echo "***************************"
	#echo
	#hadoop jar /opt/cloudera/parcels/CDH-5.5.2-1.cdh5.5.2.p0.4/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount /tmp/shakespeare.txt counts
	#echo
	#echo "Show the files now in HDFS."
	#echo
	#hdfs dfs -ls counts
	#echo
	#echo "Deleting the files from HDFS as done in the exercise."
	#echo
	#hdfs dfs -rm -r counts
	
	echo
	echo "***************************"
	echo "Running MR job with a log level argument."
	echo "***************************"
	echo
	# hadoop jar /opt/cloudera/parcels/CDH-5.5.2-1.cdh5.5.2.p0.4/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount -D mapreduce.reduce.log.level=DEBUG /tmp/shakespeare.txt counts
	hadoop jar /opt/cloudera/parcels/$PARCEL_SHORT_NAME/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount -D mapreduce.reduce.log.level=DEBUG /tmp/shakespeare.txt counts
	echo
	echo "Display the tail of one of the files now in HDFS."
	echo
	hdfs dfs -tail counts/part-r-00000
}

addSparkService () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addSparkService.json $SCRIPTS_DIR
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addSparkService.json"
	
	echo
	echo "Now configuring YARN memory settings so that the spark app will run successfully."
	echo
	
	#Adjust memory settings for YARN so that the spark interactive app will run
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-RESOURCEMANAGER-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/yarnspark1.json"
	#'{"items":[{"name":"yarn_scheduler_maximum_allocation_mb","value":"1536"}]}' 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-NODEMANAGER-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/yarnspark2.json"
	#'{"items":[{"name":"yarn_nodemanager_resource_memory_mb","value":"1536"}]}' 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-NODEMANAGER-1/config PUT "-d @$SCRIPTS_DIR/catchup/yarnspark2.json"
	#'{"items":[{"name":"yarn_nodemanager_resource_memory_mb","value":"1536"}]}' 
	
}

configSpark () {
	echo
	echo "***************************"
	echo "Configuring HDFS for Spark "
	echo "***************************"
	# create /user/spark dir with 0751 permissions aud spark:spark ownershipt
	sudo -u hdfs hdfs dfs -mkdir /user/spark
	sudo -u hdfs hdfs dfs -chmod 0751 /user/spark
	sudo -u hdfs hdfs dfs -chown spark:spark /user/spark

	# create /user/spark/applicationHistory dir with spark:spark owner and 1777 perms
	sudo -u hdfs hdfs dfs -mkdir /user/spark/applicationHistory
	sudo -u hdfs hdfs dfs -chmod 1777 /user/spark/applicationHistory
	sudo -u hdfs hdfs dfs -chown spark:spark /user/spark/applicationHistory

	sudo -u hdfs hdfs dfs -mkdir /user/spark/share
	sudo -u hdfs hdfs dfs -chmod 0755 /user/spark/share
	sudo -u hdfs hdfs dfs -chown spark:spark /user/spark/share

	sudo -u hdfs hdfs dfs -mkdir /user/spark/share/lib
	sudo -u hdfs hdfs dfs -chmod 0755 /user/spark/share/lib
	sudo -u hdfs hdfs dfs -chown spark:spark /user/spark/share/lib

	# upload spark jar to hdfs
	sudo -u hdfs hdfs dfs -put /opt/cloudera/parcels/$PARCEL_SHORT_NAME/lib/spark/lib/spark-assembly.jar /user/spark/share/lib/spark-assembly.jar
	sudo -u hdfs hdfs dfs -chown spark:spark /user/spark/share/lib/spark-assembly.jar
}

startSpark () {
	echo
	echo ""
	echo "Starting Spark service"
	echo ""
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/spark_on_yarn/commands/start POST
	
}

restartSpark () {
	echo
	echo ""
	echo "Starting Spark service"
	echo ""
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/spark_on_yarn/commands/restart POST
	
}

#deployCC called here deploys hdfs, spark, and one more service's ccs.

# run a spark on YARN app. In the exercise, students use spark-shell scala interactive mode,
# however here we run an app that writes the same files to hdfs but is written in python.
# spark gateway is on monkey only in the first spark exercise.

runSparkApps1 () {
	echo
	echo "Deleting sparkcount dir if it already exists in HDFS."
	echo
	sudo -u hdfs hdfs dfs -rm -r /tmp/sparkcount
	echo
	echo "***************************"
	echo "Running spark application on YARN."
	echo "***************************"
	echo "This will run in the background."
	ssh training@monkey -o StrictHostKeyChecking=no spark-submit \
	--master yarn-client ~/training_materials/admin/scripts/catchup/SparkApp.py </dev/null &>/dev/null &
	echo "Waiting 40 seconds."
	sleep 40
	echo
	echo "Verifying spark wrote results to HDFS (showing tail)."
	echo
	hdfs dfs -cat /tmp/sparkcount/part-00000 | tail

	echo
	echo "Displaying finished YARN applications."
	echo
	yarn application -list -appStates FINISHED
}

##############################################################
## 				 FLUME 										##
##############################################################
addFlumeService () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addFlumeService.json $SCRIPTS_DIR
	echo
	echo "Now adding Flume service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addFlumeService.json"
}

configFlume () {
	echo
	echo "***************************"
	echo "Configuring Flume HDFS dirs."
	echo "***************************"
	echo
	sudo -u hdfs hdfs dfs -mkdir /user/flume
	sudo -u hdfs hdfs dfs -chmod 0755 /user/flume
	sudo -u hdfs hdfs dfs -chown -R flume /user/flume
	
}

exerciseFlume () {
	echo
	echo "***************************"
	echo "Running through Flume exercise steps."    
	echo "***************************"  

	echo
	echo "Attempting to remove web simulator files that may have been generated earlier."
	echo
	rm -r /tmp/access*

	echo
	echo "Attempting to remove files that may have been placed in HDFS by Flume earlier."
	echo
	sudo -u hdfs hdfs dfs -rm -r /user/flume/collector1
	
	echo 
	echo "Starting the web server simulator which creates fake log files."
	echo 
	cd /home/training/training_materials/admin/scripts
	./accesslog-gen.sh /tmp/access_log &
	
	echo 
	echo "Giving the simulator 10 seconds to generate some data."
	echo 
	sleep 10
	echo
	echo "Confirming files are being generated."
	echo
	ls -l /tmp/access*

	echo
	echo "Starting flume agents."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/flume/commands/start POST
	
	echo
	echo "Waiting 20 seconds for flume agents to process data and write to HDFS."
	echo
	sleep 20

	echo
	echo "Showing data Flume wrote to HDFS."
	echo
	sudo -u hdfs hdfs dfs -ls /user/flume/collector1

	#Note: the deployment included the modifications students make to the agent at the end of the exercise so no need to add those and refresh the cluster.
	echo
	echo "Stopping the log generator started earlier."
	echo
	sudo kill $(sudo ps -ef|grep access|grep -v grep|awk '{print $2}')

	echo
	echo "Stopping both flume agents."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/flume/commands/stop POST
	
	echo
	echo "Removing the generator's files from the tmp dir."
	echo
	rm -rf /tmp/access_log*
}

##############################################################
## 						 SQOOP								##
##############################################################
addSqoopService () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addSqoopService.json $SCRIPTS_DIR
	echo
	echo "Now adding Sqoop service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addSqoopService.json"
	echo "Redeploying the Sqoop gateway config."
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/sqoop_client/commands/deployClientConfig POST "-d @$SCRIPTS_DIR/catchup/deploySqoopCC.json"
}

configSqoop () {
	#config sqoop gateway to find mysql
	sudo ln -s /usr/share/java/mysql-connector-java.jar /opt/cloudera/parcels/CDH/lib/sqoop/lib/
}

importTablesSqoop () {
	#import movie table into hadoop
	echo
	echo "Importing movie table into hadoop."
	echo
	hdfs dfs -mkdir /tmp/moviedata
	sqoop import \
	--connect jdbc:mysql://cmhost/movielens \
	--username training --password training \
	--table movie --fields-terminated-by '\t' \
	--target-dir /tmp/moviedata/movie
	
	#sqoop import \
	#--connect jdbc:mysql://localhost/movielens \
	#--table movie --fields-terminated-by '\t' \
	#--username training --password training 

	#verify command worked
	echo
	echo "Displaying end of movie table in HDFS."
	echo
	hdfs dfs -ls /tmp/moviedata/movie
	hdfs dfs -tail /tmp/moviedata/movie/part-m-00000

	#import movierating table into hadoop
	echo
	echo "Importing movierating table into hadoop."
	echo
	sqoop import \
    --connect jdbc:mysql://cmhost/movielens \
    --username training --password training \
    --table movierating --as-parquetfile \
    --target-dir /tmp/moviedata/movierating

	#sqoop import \
	#--connect jdbc:mysql://localhost/movielens \
	#--table movierating --fields-terminated-by '\t' \
	#--username training --password training 

	#verify command worked
	echo
	echo "Testing movierating table is now in hadoop."
	echo
	hdfs dfs -ls /tmp/moviedata/movierating
	
	#see apps finished (should include sqoop MR jobs)
	echo
	echo "Display finished yarn jobs."
	echo
	yarn application -list -appStates FINISHED
}
##############################################################
## 				 ZK HIVE IMPALA								##
##############################################################

addZKService () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addZKService.json $SCRIPTS_DIR
	echo
	echo "Now adding Zookeeper service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addZKService.json"
}

firstRunZK () {
	echo
	echo "*******************************"
	echo "Calling firstRun on Zookeeper."
	echo ""
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/zookeeper/commands/firstRun POST
}

addHiveService () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addHiveService.json $SCRIPTS_DIR
	echo
	echo "Now adding Hive service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addHiveService.json"
}

enableHiveOnSpark () {	
	#NEW2016-#turn on hive on spark
	#NOTE: be sure that a call to addSparkGateway for elephan precedes this
	echo
	echo "Enable hive on spark."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/config PUT "-d @$SCRIPTS_DIR/catchup/hiveonspark.json"
	
	echo
	echo "Set spark executor cores for hive."
	echo 
	#callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/roleConfigGroups/hive-HIVESERVER2-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/hivesparkex.json"
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/roleConfigGroups/hive-HIVESERVER2-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/hivesparkex.json"
}

firstRunHive () {		
	# create /user/hive dir with 1775 permissions aud hive:hive ownership
	sudo -u hdfs hdfs dfs -mkdir /user/hive
	sudo -u hdfs hdfs dfs -chmod 1775 /user/hive
	sudo -u hdfs hdfs dfs -chown hive:hive /user/hive
	
	sudo -u hdfs hdfs dfs -mkdir /user/hive/warehouse
	sudo -u hdfs hdfs dfs -chmod 1775 /user/hive/warehouse
	sudo -u hdfs hdfs dfs -chown hive:hive /user/hive/warehouse
	
	echo "Waiting 30 seconds before calling first run on Hive."
	sleep 30
	echo
	echo "*************************"
	echo "Calling firstRun on Hive."
	echo ""
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/commands/firstRun POST
}
#NEW 2016
restartHive () {
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/commands/restart POST
}

addImpalaService () {
	#These permission changes avoid an Impala warning 
	#sudo chmod 755 /dfs/dn
	#ssh training@tiger -o StrictHostKeyChecking=no sudo chmod 755 /dfs/dn
	#ssh training@horse -o StrictHostKeyChecking=no sudo chmod 755 /dfs/dn
	#ssh training@monkey -o StrictHostKeyChecking=no sudo chmod 755 /dfs/dn
	
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addImpalaService.json $SCRIPTS_DIR
	echo
	echo "Now adding Impala service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addImpalaService.json"
	echo
	echo "Configuring HDFS for Impala."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/config PUT "-d @$SCRIPTS_DIR/catchup/hdfsForImpala.json"
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roles/hdfs-DATANODE-1/config PUT "-d @$SCRIPTS_DIR/catchup/hdfsRoleForImpala.json"
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roles/hdfs-DATANODE-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/hdfsRoleForImpala.json"
	echo
	echo "Restarting HDFS."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands/restart POST
	echo
	echo "Deploying Hive client config after Impala added."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/commands/deployClientConfig POST "-d @$SCRIPTS_DIR/catchup/deployHiveCC.json"	
}

firstRunImpala () {
	echo
	echo "***************************"
	echo "Calling firstRun on Impala."
	echo ""
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/impala/commands/firstRun POST
	
}

startImpala () {
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/impala/commands/start POST
}

exerciseHive () {
	echo
	echo "***************************"
	echo "Dropping movierating table in Hive (if exists), then creating movierating table in Hive."
	echo "***************************"
	echo
	cd /home/training/training_materials/admin/scripts/catchup
	./movierating.exp
	
	#Then show the table and run a hive query against the new table...not really necessary in this script (skipping).
	echo
	echo "Verifying the Hive query ran as a YARN application (MR job)."
	echo
	yarn application -list -appStates FINISHED
}

exerciseImpala () {	
	echo
	echo "***************************"
	echo "Using the impala-shell to create the movierating table and then query it."
	echo "***************************"
	echo
	cd /home/training/training_materials/admin/scripts/catchup
	./movierating-imp.exp
	echo
	echo "Waiting 15 seconds."
	echo
	sleep 15
	
	echo
	echo "Showing Impala queries."
	echo
	curl -X GET -v -H "Content-Type:application/json" -u admin:admin \
	'http://cmhost:7180/api/v9/clusters/cluster/services/impala/impalaQueries?from=2015-05-03T18%3A07%3A22.189Z&to=2020-05-05T18%3A37%3A22.189Z'	
	echo ""
}

##############################################################
## 				 HUE										##
##############################################################
addHttpFs () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addHttpFs.json $SCRIPTS_DIR
	echo
	echo "Now adding the HTTP FS role to HDFS service."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roles/ POST "-d @$SCRIPTS_DIR/catchup/working/addHttpFs.json"
}

addSparkGateway () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addSparkGateway.json $SCRIPTS_DIR
	echo
	echo "Now adding Spark Gateway on Elephant."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/spark_on_yarn/roles/ POST "-d @$SCRIPTS_DIR/catchup/working/addSparkGateway.json"
	echo
	echo "Deploying Spark client configurations."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/spark_on_yarn/commands/deployClientConfig POST "-d @$SCRIPTS_DIR/catchup/deploySparkCCe.json"
}

addOozieService () {
	echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addOozieService.json $SCRIPTS_DIR
	echo
	echo "Now adding Oozie service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addOozieService.json"
}

addHueService () {
echo
	echo "Updating JSON with new hostIds prior to posting."
	echo 
	generateJson addHueService.json $SCRIPTS_DIR
	echo
	echo "Now adding Hue service to the cluster."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services POST "-d @$SCRIPTS_DIR/catchup/working/addHueService.json"
}

startHttpFs () {
	echo
	echo "Starting HttpFs."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleCommands/start POST "-d @$SCRIPTS_DIR/catchup/startHttpFs.json"
}

confirmHttpFS () {
	echo
	echo "***************************"
	echo "Testing that the HttpFS REST API is working."
	echo "***************************"
	echo
	curl -s "http://monkey:14000/webhdfs/v1/user/training?op=LISTSTATUS&user.name=training" | python -m json.tool
}

firstRunOozie () {	
	echo
	echo "Calling firstRun on Oozie."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/oozie/commands/firstRun POST
}

stopHue () {
	echo
	echo "Stopping Hue in case it was started when the service was added."
	echo "If this call fails because Hue is already stopped, ignore the error."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hue/commands/stop POST
	checkPending "hue"
}

firstRunHue () {
	echo "Waiting 60 seconds before calling first run on Hue."
	sleep 60
	echo
	echo "*************************"
	echo "Calling firstRun on Hue."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hue/commands/firstRun POST
}

#exerciseHue () {
	#echo
	#echo "Submitting a MR WordCount job subsequent to Hue being installed."
	#echo "Try deleting  files from HDFS in case this job was run before and no cleanup was done."
	#echo
	#hdfs dfs -rm -r test_output
	
	#echo
	#echo $MYHOST "Running the WordCount program." 
	#echo
	#hadoop jar /opt/cloudera/parcels/CDH-5.5.2-1.cdh5.5.2.p0.4/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount /tmp/shakespeare.txt test_output
	#echo
	#echo "Showing the files now in HDFS."
	#echo
	#hdfs dfs -ls test_output

	#Add Spark Gateway to elephant and deploy spark cc done in function above.
	
	#Run Spark interactively on elephant and keep it running
	#echo
	#echo "Starting a Spark interactive shell on elephant in the background. Will keep it running for 40 seconds then kill it."
	#echo
	#cd /home/training/training_materials/admin/scripts/catchup
	#./sparkjob.sh </dev/null &>/dev/null &
	
	#Let it run for 40 seconds then kill it
	#sleep 40
	#echo
	#echo "killing spark shell."
	#echo
	#kill $(sudo ps -ef|grep sparkjob |grep -v grep | awk '{print $2}')
	#sleep 10
	
	#Most of the steps in the exercise are explorations of what is possible in Hue (nothing really to script)
#}


##############################################################
## 				 HDFS HA									##
##############################################################
preHAConfigurations () {
	echo
	echo "Stopping Hue, Oozie, Impala, Hive."
	echo
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hue/commands/stop POST
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/oozie/commands/stop POST
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/impala/commands/stop POST
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/commands/stop POST
		
	echo 
	echo "Creating Journal Node directories."
	echo
	sudo mkdir /dfs/jn
	sudo chown hdfs:hadoop /dfs/jn
	ssh training@horse -o StrictHostKeyChecking=no sudo mkdir /dfs/jn
	ssh training@horse -o StrictHostKeyChecking=no sudo chown hdfs:hadoop /dfs/jn
	ssh training@tiger -o StrictHostKeyChecking=no sudo mkdir /dfs/jn
	ssh training@tiger -o StrictHostKeyChecking=no sudo chown hdfs:hadoop /dfs/jn
}

editHDFSHAJSON () {
	echo
	echo "Copying json template."
	echo
	#$1 is SCRIPTS_DIR
	OUTPUT_FILE=$1/catchup/working/setHDFSHA.json
	cp $1/catchup/setHDFSHA.json $OUTPUT_FILE
	
	echo
	echo "OUTPUT_FILE is " $OUTPUT_FILE
	echo 
	echo "Editing " $OUTPUT_FILE " for new environment"
	echo
	echo "Capturing the hostIds and ipAddresses of the current cluster"
	echo
	# Capture the hostId, ipAddress, and hostname from the new installation
	
	curl -X GET -H "Content-Type:application/json" -u admin:admin \
	'http://cmhost:7180/api/v9/hosts'|grep 'hostId\|ipAddress\|hostname' > /home/training/training_materials/admin/scripts/catchup/working/hostIds.txt
	
	# Strip out the quotes and commas
	sed -i 's/"//g' $1/catchup/working/hostIds.txt
	sed -i 's/,//g' $1/catchup/working/hostIds.txt
	echo
	echo "Here are the contents of the hostIds.txt file on elephant:"
	echo
	cat ~/training_materials/admin/scripts/catchup/working/hostIds.txt
	
	echo
	echo "Updating host ids of Journal Nodes."
	echo
	# Old hostIds of JournalNodes in setHDFSHA.json
	OldEJn="8b437d46-1806-4fc8-b837-ab8140b9390a"
	OldHJn="45f62175-8f66-4dd2-956c-a70df5076c4a"
	OldTJn="e8f321c6-efee-44ef-98c2-0d30398e3122"

	# New hostIds (set variables)
	NewEJn=$(cat $1/catchup/working/hostIds.txt | sed -n 1p | awk '{print $3}')
	NewHJn=$(cat $1/catchup/working/hostIds.txt | sed -n 4p | awk '{print $3}')
	NewTJn=$(cat $1/catchup/working/hostIds.txt | sed -n 13p | awk '{print $3}')
	
	# Update new json with correct hostIds
	sed -i "s/$OldEJn/$NewEJn/g" $OUTPUT_FILE
	sed -i "s/$OldHJn/$NewHJn/g" $OUTPUT_FILE
	sed -i "s/$OldTJn/$NewTJn/g" $OUTPUT_FILE
}

configHDFSHA () {
	#this call should add the second NN and journalnodes.
	echo ""
	echo "Enabling HDFS HA on the cluster."
	echo ""
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands/hdfsEnableNnHa POST "-d @$SCRIPTS_DIR/catchup/working/setHDFSHA.json"
	
	echo
	echo "Waiting for hdfsEnableNnHa and any other pending HDFS commands to complete."
	echo 

	hdfsCommands=$(curl -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands'|grep -C4 items|grep active|cut -d " " -f7- | sed 's/[,:"]//g')
	echo "HDFS Commands currently running? "$hdfsCommands

	while [[ $hdfsCommands == "true" ]];
		do
		echo "Commands still running? "$hdfsCommands
		sleep 10
		hdfsCommands=$(curl -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands'|grep -C4 items|grep active|cut -d " " -f7- | sed 's/[,:"]//g')
	done

	echo "The HDFS service has no more pending commands."
	echo
	echo "Showing GET results again."
	echo
	curl -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands'

	echo
	echo "Restarting HDFS to leave safemode and start Data Nodes."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands/restart POST
	
	echo
	echo "Updating Hive Metastore to point to NameNode's Nameservice name instead of hostname."
	echo
	# Hive metastore server should be stopped before running this.	 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hive/commands/hiveUpdateMetastoreNamenodes POST

}

#Not currently using this function
testHDFSHA () {
	echo
	echo "Verify automatic NameNode failover. Restarting NN on Elephant which should make Tiger the primary."
	echo	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleCommands/restart POST "-d @$SCRIPTS_DIR/catchup/namenodeE.json"
	
	echo
	echo "Restarting NN on Tiger which should make Elephant the active NN again."
	echo	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleCommands/restart POST "-d @$SCRIPTS_DIR/catchup/namenodeT.json"
}

##############################################################
## 				POOLS						 				##
##############################################################

exerciseFairSched () {
	echo 
	echo "Updating YARN container memory max to 3GB and vcores to 2 for yarn-NODEMANAGER-BASE role group."
	echo
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-NODEMANAGER-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/setPools.json"
	checkPending "yarn"
	
	echo
	echo "Updating YARN container memory max to 3GB for yarn-NODEMANAGER-1 role group."
	echo
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-NODEMANAGER-1/config PUT "-d @$SCRIPTS_DIR/catchup/setPools.json"
	checkPending "yarn"
	
	#echo
	#echo "Refreshing YARN to make changes take."
	#echo
	
	#callCmApi http://cmhost:7180/api/v9/clusters/cluster/commands/refresh POST

	#This creates a Dynamic Resource Pool named pool2 with weight 2, min memory of 2400MB and max memory of 5000MB
	echo
	echo "Configuring YARN for the dynamic resource pool named pool2."
	echo
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/config PUT "-d @$SCRIPTS_DIR/catchup/dynamicYarn.json "
	
	#the pool applies across both YARN and Impala
	echo
	echo "Configuring Impala for the dynamic resource pool named pool2."
	echo
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/impala/config PUT "-d @$SCRIPTS_DIR/catchup/dynamicImpala.json"
	
	#echo
	#echo "***Restarting HDFS, YARN, Spark, ZK to apply changes."
	#echo
	#callCmApi http://cmhost:7180/api/v9/clusters/cluster/commands/restart POST "-d @$SCRIPTS_DIR/catchup/restartStale.json"
	echo
	echo "Restarting YARN service to apply changes."
	echo 
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/commands/restart POST
}

##############################################################
## 				SNAPSHOTS, EMAIL, HEAP						##
##############################################################

exerciseSnapshot () {
	echo
	echo "Enabling snapshots on the /user/training dir."
	echo
	sudo -u hdfs hdfs dfsadmin -allowSnapshot /user/training

	echo
	echo "Deleting snapshot snap1 if it already exists."
	echo
	sudo -u hdfs hdfs dfs -deleteSnapshot /user/training snap1
	
	echo
	echo "Confirming weblog data is in hdfs and adding it now if not."
	echo
	hdfs dfs -test -f /user/training/weblog/access_log
	if [ $? -ne 0 ]; then
		hdfs dfs -mkdir /user/training/weblog
		gunzip -c /home/training/training_materials/admin/data/access_log.gz | hdfs dfs -put - /user/training/weblog/access_log
	fi
	
	echo
	echo "Showing contents of /user/training before snapshot."
	echo
	hdfs dfs -ls /user/training
	
	echo
	echo "Taking a snapshot of /user/training and naming it snap1."
	echo
	sudo -u hdfs hdfs dfs -createSnapshot /user/training snap1

	echo
	echo "Deleting /user/training/weblog from HDFS."
	echo
	hdfs dfs -rm -r weblog
	echo
	echo "Showing contents of /user/training."
	echo
	hdfs dfs -ls /user/training
	
	echo
	echo "Showing contents of snapshot taken earlier."
	echo
	#..but note that it is still available in the snapshot
	sudo -u hdfs hdfs dfs -ls /user/training/.snapshot/snap1
	
	echo
	echo "Restoring the data deleted."
	echo
	sudo -u hdfs hdfs dfs -cp /user/training/.snapshot/snap1/weblog /user/training/weblog
	
	echo
	echo "Confirming it is restored."
	echo
	hdfs dfs -ls /user/training
}

killDataNode () {
	echo
	echo "Killing the DataNode on elephant"
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleCommands/stop POST "-d @$SCRIPTS_DIR/catchup/datanodeE.json"
}

startDataNode () {
	echo
	echo "Checking if the datanode is stopped"
	status=$(curl -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roles/hdfs-DATANODEe | grep roleState | awk '{print $3}'| sed 's/[",]//g')
	echo "DataNode on elephant is "$status
	if [[ $status == "STOPPED" ]]; then
		echo "Starting DataNode on elephant"
		echo
		callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/roleCommands/start POST "-d @$SCRIPTS_DIR/catchup/datanodeE.json"
	fi
}

configEmail () {
	echo
	echo "Applying email configurations."
	echo

	callCmApi http://cmhost:7180/api/v9/cm/service/roleConfigGroups/mgmt-ALERTPUBLISHER-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/setEmail.json"

	echo
	echo "Restarting CM Management Services to apply email config."
	echo
	
	callCmApi http://cmhost:7180/api/v9/cm/service/commands/restart POST
	
	#this script does not send the test email. There is currently no way to do that from the CM API. OPSAPS-26674 opened.
	
	echo
	echo "Checking the mail. None expected from CM yet."
	echo
	ssh training@cmhost -o StrictHostKeyChecking=no ~/training_materials/admin/scripts/catchup/mail.exp
	sleep 5
}

heapOTrouble () {
	echo
	echo "Confirming shakespeare.txt is in HDFS, and if not, adding it now."
	echo
	hdfs dfs -stat /tmp/shakespeare.txt
	#shakespeare.txt may or may not have been unzipped and unzipping removes the original file
	if [ $? == 1 ]; then
		echo
		echo "File not found in HDFS."
		echo
		if [ ! -f /home/training/training_materials/admin/data/shakespeare.txt ]; then
			echo
			echo "Unzipping and placing in HDFS."
			echo
			cd /home/training/training_materials/admin/data
			gunzip shakespeare.txt.gz
			hdfs dfs -put shakespeare.txt /tmp
		else 
			echo
			echo "Already unzipped. Placing in HDFS."
			echo
			hdfs dfs -put /home/training/training_materials/admin/data/shakespeare.txt /tmp
		fi
	fi
	
	echo
	echo "Confirming weblog data is in HDFS, and if not, adding it now."
	echo
	hdfs dfs -test -f /user/training/weblog/access_log
	if [ $? == 1 ]; then
		echo
		echo "File not found in HDFS. Placing there now."
		echo
		hdfs dfs -mkdir /user/training/weblog
		gunzip -c /home/training/training_materials/admin/data/access_log.gz | hdfs dfs -put - /user/training/weblog/access_log
	fi
	
	#remove job output if it already exists
	hdfs dfs -rm -r /user/training/heapOfTrouble
	echo
	echo "Displaying the current YARN memory settings on the cluster."	
	echo
	curl -X GET -v -H "Content-Type:application/json" -u admin:admin \
	'http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-GATEWAY-BASE/config'
	
	echo
	echo "Running heap of trouble. No adjustments made, expected to fail assuming yarn memory configurations not already made."
	echo
	cd ~/training_materials/admin/java
	hadoop jar EvilJobs.jar HeapOfTrouble /tmp/shakespeare.txt heapOfTrouble
	echo
	echo "The job should have failed if the yarn memory configurations remained unchanged."
	echo
	sleep 5
	
	echo
	echo "Now configuring memory settings so that next time the job will run successfully."
	echo
	
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/yarn/roleConfigGroups/yarn-GATEWAY-BASE/config PUT "-d @$SCRIPTS_DIR/catchup/setHeap.json"
	
	
	echo
	echo "Restarting YARN to apply changes."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/hdfs/commands/restart POST 
	
	echo
	echo "Restarting Spark to apply changes."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/services/spark_on_yarn/commands/restart POST 
	
	echo
	echo "Deploying client configurations."
	echo
	callCmApi http://cmhost:7180/api/v9/clusters/cluster/commands/deployClientConfig POST
	
	echo
	echo "Removing output from last heapOfTrouble job attempt."
	echo
	hdfs dfs -rm -r /user/training/heapOfTrouble
	
	echo
	echo "Trying to run the HeapOfTrouble job again. This time it should succeed."
	echo
	cd ~/training_materials/admin/java
	hadoop jar EvilJobs.jar HeapOfTrouble /tmp/shakespeare.txt heapOfTrouble
	echo
	echo "This time the job should have succeeded."
	echo
	sleep 3
}


##############################################################
## 				CASES						 				##
##############################################################
#This script is typically called by scripts/reset_cluster.sh
SOURCE_DEPLOYMENT=""
BACKUP_FILE=""

case "$ACTION" in
	test)
		someFunc
		;;
	cmDeployment)
		echo "in case cmDeployment"
		SOURCE_DEPLOYMENT=$2
		BACKUP_FILE=$3
		backupDeployment $BACKUP_FILE $SCRIPTS_DIR
		generateJson $SOURCE_DEPLOYMENT $SCRIPTS_DIR
		putJson $SOURCE_DEPLOYMENT $SCRIPTS_DIR
		activateParcels
		checkPending "hdfs"
		checkPending "yarn"
		firstRun
		startCMMS
		updateDNPerms $SCRIPTS_DIR
		checkPending "hdfs"
		restartHDFS
		deployCC
		configHDFS
		;;
	exercise-hdfs)
		exerciseHDFS
		;;
	spark)
		runMRJobs1
		addSparkService $SCRIPTS_DIR
		restartYARN
		configSpark 
		restartSpark
		deployCC
		runSparkApps1
		;;
	flume)
		addFlumeService $SCRIPTS_DIR
		configFlume
		exerciseFlume
		;;
	sqoop)
		addSqoopService $SCRIPTS_DIR
		configSqoop
		importTablesSqoop
		;;
	hive-impala)
		addZKService $SCRIPTS_DIR
		checkPending "zookeeper"
		firstRunZK
		addHiveService $SCRIPTS_DIR
		addSparkGateway $SCRIPTS_DIR #this is moved up to here instead of in Hue exercise
		#enableHiveOnSpark #this is new
		checkPending "hdfs"
		checkPending "zookeeper"
		checkPending "hive"
		firstRunHive
		restartHive
		addImpalaService $SCRIPTS_DIR
		checkPending "hive"
		checkPending "impala"
		firstRunImpala
		exerciseHive
		exerciseImpala
		;;
	hue)
		addHttpFs $SCRIPTS_DIR
		#addSparkGateway $SCRIPTS_DIR
		addOozieService $SCRIPTS_DIR
		addHueService $SCRIPTS_DIR
		checkPending "hdfs"
		startHttpFs $SCRIPTS_DIR
		confirmHttpFS
		checkPending "oozie"
		firstRunOozie
		checkPending "hue"
		stopHue
		firstRunHue
		;;
	hdfs-ha)
		preHAConfigurations
		editHDFSHAJSON $SCRIPTS_DIR
		configHDFSHA $SCRIPTS_DIR
		#testHDFSHA $SCRIPTS_DIR
		;;
	scheduler)
		exerciseFairSched $SCRIPTS_DIR
		;;
	breaking)
		killDataNode $SCRIPTS_DIR
		;;
	healing)
		startDataNode $SCRIPTS_DIR
		;;
	snapshot)
		exerciseSnapshot
		;;
	email)
		configEmail $SCRIPTS_DIR
		;;
	heap)
		heapOTrouble $SCRIPTS_DIR
		;;
	*)
		usage $0
esac

##############################################################
## 				        MAINTENANCE						    ##
##############################################################
# SOURCE_DEPLOYMENT jsons captured after each exercise where service(s) added.
#
# Example  command used to capture deployment2 which captures cluster state after 
# completion of YARN/MR/Spark chapter. Leave this commented out in this script.
# curl -X GET -H "Content-Type:application/json" -u admin:admin \
# 'http://cmhost:7180/api/v9/cm/deployment' > $SCRIPTS_DIR/catchup/deployment2.json.
#
# If a new deployment#.json is captured from a new cluster, the numbers and processing 
# logic in the generateJson function above will need adjusting. 

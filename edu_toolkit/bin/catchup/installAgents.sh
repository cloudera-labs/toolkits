#!/bin/bash

CATCHUP_LOG_DIR=/home/training/training_materials/admin/scripts/catchup/logs
mkdir -p $CATCHUP_LOG_DIR
AgentInstallation_LOG="`date +%F`-InstallCMAgents.log"
exec 2> $CATCHUP_LOG_DIR/$AgentInstallation_LOG

if [ $HOSTNAME != "cmhost" ]; then
	echo "This script should only be run on cmhost. It appears you are running this on " $HOSTNAME
	echo "Exiting..."
	sleep 5
	exit 0
fi
echo "verified the hostname is cmhost. Continuing..."

#This SCRIPTS_DIR variable is used extensively throughout this script
SCRIPTS_DIR=/home/training/training_materials/admin/scripts

# Install CM agents to nodes
echo
echo "Installing CM Agent to all 6 machines in parallel."
echo
sudo yum install -y cloudera-manager-agent 2>&1 | sed -e 's/^/cmhost output> /' &
ssh training@master-1 -o StrictHostKeyChecking=no sudo yum install -y cloudera-manager-agent 2>&1 | sed -e 's/^/master-1 output> /' &
ssh training@master-2 -o StrictHostKeyChecking=no sudo yum install -y cloudera-manager-agent 2>&1 | sed -e 's/^/master-2 output> /' &
ssh training@worker-1 -o StrictHostKeyChecking=no sudo yum install -y cloudera-manager-agent 2>&1 | sed -e 's/^/worker-1 output> /' &
ssh training@worker-2 -o StrictHostKeyChecking=no sudo yum install -y cloudera-manager-agent 2>&1 | sed -e 's/^/worker-2 output> /' &
ssh training@worker-3 -o StrictHostKeyChecking=no sudo yum install -y cloudera-manager-agent 2>&1 | sed -e 's/^/worker-3 output> /' &
wait

echo
echo "Configuring all 6 agents to find the CM server" 
echo
sudo sed -i 's,server_host=localhost,server_host=cmhost,' /etc/cloudera-scm-agent/config.ini
ssh training@master-1 -o StrictHostKeyChecking=no sudo sed -i 's,server_host=localhost,server_host=cmhost,' /etc/cloudera-scm-agent/config.ini
ssh training@master-2 -o StrictHostKeyChecking=no sudo sed -i 's,server_host=localhost,server_host=cmhost,' /etc/cloudera-scm-agent/config.ini
ssh training@worker-1 -o StrictHostKeyChecking=no sudo sed -i 's,server_host=localhost,server_host=cmhost,' /etc/cloudera-scm-agent/config.ini
ssh training@worker-2 -o StrictHostKeyChecking=no sudo sed -i 's,server_host=localhost,server_host=cmhost,' /etc/cloudera-scm-agent/config.ini
ssh training@worker-3 -o StrictHostKeyChecking=no sudo sed -i 's,server_host=localhost,server_host=cmhost,' /etc/cloudera-scm-agent/config.ini

echo "Starting CM Agent on all 6 machines in parallel." 
sudo systemctl start cloudera-scm-agent 2>&1 | sed -e 's/^/cmhost output> /' &
ssh training@master-1 -o StrictHostKeyChecking=no sudo systemctl start cloudera-scm-agent 2>&1 | sed -e 's/^/master-1 output> /' &
ssh training@master-2 -o StrictHostKeyChecking=no sudo systemctl start cloudera-scm-agent 2>&1 | sed -e 's/^/master-2 output> /' &
ssh training@worker-1 -o StrictHostKeyChecking=no sudo systemctl start cloudera-scm-agent 2>&1 | sed -e 's/^/worker-1 output> /' &
ssh training@worker-2 -o StrictHostKeyChecking=no sudo systemctl start cloudera-scm-agent 2>&1 | sed -e 's/^/worker-2 output> /' &
ssh training@worker-3 -o StrictHostKeyChecking=no sudo systemctl start cloudera-scm-agent 2>&1 | sed -e 's/^/worker-3 output> /' &
wait

#### Yarn Queue Manager Fix ####
#ssh training@master-1 -o StrictHostKeyChecking=no 'sudo rm -rf /var/lib/hadoop-yarn; \
#sudo mkdir /var/lib/hadoop-yarn; sudo chmod 755 /var/lib/hadoop-yarn; sudo chown yarn:hadoop /var/lib/hadoop-yarn' & 

#sudo chown yarn:hadoop /var/lib/hadoop-yarn' &
###

echo 
echo "Verify CM Server is started." 
echo
cmApiTest=""
while [[ $cmApiTest != "false" ]]
	do
	cmApiTest=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v12/cm/version'|grep snapshot|cut -d " " -f5-|sed 's/[",]//g')
	sleep 10
done
echo 
echo "***************************"
echo ">>>Specifying we want the 60-day trial version of Cloudera Manager."
echo "***************************"
echo "Asking to start the trial..."
curl -s -X POST -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v12/cm/trial/begin'
sleep 10
echo "Asking to display the license..."
echo $(curl -s -X GET  -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/cm/license')
sleep 5
echo "***************************"
echo "Restarting CM server"
echo $(date)
echo "***************************"
sudo systemctl restart cloudera-scm-server

#don't move on until API is accessible.
echo 
echo "Waiting for CM Server to start... " 
# You may see curl errors until it does fully start. The couldn't connect to host messages are expected." 
echo
cmApiTest=""
while [[ $cmApiTest != "false" ]]
	do
	cmApiTest=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/cm/version'|grep snapshot|cut -d " " -f5-|sed 's/[",]//g')
	sleep 10
done

# Verify configured hosts
#hosts_configured=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/hosts'|grep 'hostId\|hostname' | grep -i hostname | wc -l)
# if [[ $hosts_configured != 6 ]];  then
#   echo "***************************"
#   echo "ERROR : CM agent did not get configured as should be, please do investigate and run the re-set script again!"
#   sleep 10
#   exit 1
# fi 

echo "printing out the host ids and hostnames of the hosts that now have CM agent installed."
curl -s -X GET -H "Content-Type:application/json" -u admin:admin 'http://cmhost:7180/api/v9/hosts'|grep 'hostId\|hostname'

echo
echo "***************************"
echo "Done Installing CM Agents."
echo $(date)
echo "***************************"



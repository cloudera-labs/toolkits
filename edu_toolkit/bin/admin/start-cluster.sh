#!/bin/bash

echo
echo "Started running start-cluster.sh at $(date '+%Y-%m-%d %T')"

nocheck="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error"

update_s3_creds() {
  # update AWS ec2 access credentials
  cd /home/training/config
  ./update-s3-creds.sh
}

cleanup_and_log() {
  #remove any logs from previous restart
  rm -f restart-cluster.log
  rm -f restart-clustererr.log

  #capture stout and sterr from restart to log files
  exec > >(tee -ia restart-cluster.log)
  echo "Started logging start-cluster.sh at $(date '+%Y-%m-%d %T')"

}

start_aws_instances() {
  region=$(sudo curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep '\"region\"' | cut -d\" -f4)

  if [ ! -f /home/training/.ngee-instances ]; then
      echo
      echo "/home/training/.ngee-instances file not found." 
      echo "This typically means that no cluster instances exists yet. Exiting." 
      exit 1
  else
      #find cluster node instance IDs
      m1Id=$(cat /home/training/.ngee-instances | grep m1instanceId | awk '{print $2}')
      m2Id=$(cat /home/training/.ngee-instances | grep m2instanceId | awk '{print $2}')
      w1Id=$(cat /home/training/.ngee-instances | grep w1instanceId | awk '{print $2}')
      w2Id=$(cat /home/training/.ngee-instances | grep w2instanceId | awk '{print $2}')
      w3Id=$(cat /home/training/.ngee-instances | grep w3instanceId | awk '{print $2}')
      gwId=$(cat /home/training/.ngee-instances | grep ginstanceId | awk '{print $2}')
  fi
  echo 
  echo "=================================================" 
  echo "Starting cluster instances"               
  echo "================================================="  

  echo "Starting master-1"  
  aws ec2 start-instances --region $region --instance-ids $m1Id --output json 2>/dev/null
  echo "Starting master-2"  
  aws ec2 start-instances --region $region --instance-ids $m2Id --output json 2>/dev/null
  echo "Starting worker-1"  
  aws ec2 start-instances --region $region --instance-ids $w1Id --output json 2>/dev/null
  echo "Starting worker-2"  
  aws ec2 start-instances --region $region --instance-ids $w2Id --output json 2>/dev/null
  echo "Starting worker-3"  
  aws ec2 start-instances --region $region --instance-ids $w3Id --output json 2>/dev/null
  echo "Starting gateway" 
  aws ec2 start-instances --region $region --instance-ids $gwId --output json 2>/dev/null

}

verify_instances_ready(){
  #verify status checks before continuing on
  vResp=0
  count=0
  echo "Instances launching. Waiting for them to pass all status checks..."
  echo
  echo "This step typically takes 3 or 4 minutes, sometimes longer. Please be patient..."
    while [ $vResp -eq 0 ] 
    do 
    currentStatus=$(aws ec2 describe-instance-status --instance-ids $m1Id $m2Id $w1Id $w2Id $w3Id $gwId --output json | grep -o '"Status": "[^"]*' | grep -o '[^"]*$')
    c1=$(echo $currentStatus | awk '{print $1}')
    c2=$(echo $currentStatus | awk '{print $2}')
    c3=$(echo $currentStatus | awk '{print $3}')
    c4=$(echo $currentStatus | awk '{print $4}')
    c5=$(echo $currentStatus | awk '{print $5}')
    c6=$(echo $currentStatus | awk '{print $6}')
    c7=$(echo $currentStatus | awk '{print $7}')
    c8=$(echo $currentStatus | awk '{print $8}')
    c9=$(echo $currentStatus | awk '{print $9}')
    c10=$(echo $currentStatus | awk '{print $10}')
    c11=$(echo $currentStatus | awk '{print $11}')
    c12=$(echo $currentStatus | awk '{print $12}')
    if [[ "$c1" == "ok" ]] && [[ "$c2" == "passed" ]] && [[ "$c3" == "ok" ]] && [[ "$c4" == "passed" ]] && \
       [[ "$c5" == "ok" ]] && [[ "$c6" == "passed" ]] && [[ "$c7" == "ok" ]] && [[ "$c8" == "passed" ]] && \
       [[ "$c9" == "ok" ]] && [[ "$c10" == "passed" ]] && [[ "$c11" == "ok" ]] && [[ "$c12" == "passed" ]]; then 
        printf "\n"
        echo "All instances now responsive, moving on..."
        vResp=1
    else
      #sleep 15 seconds
      count=0
      while [ $count -lt 15 ];
      do
        count=$(( $count + 1))
        printf "."
        sleep 1
      done
    fi
  done
}

start_scm_server_and_all_agents() {
  echo "================================================="
  echo "Restarting CM Server and CM Agents"              
  echo "================================================="
  #sudo service cloudera-scm-server restart 
  #echo "Waiting 45 seconds to allow CM server to fully start..."
  #sleep 45
  #count=0
  #while [ $count -lt 45 ];
  #do
  #  count=$(( $count + 1))
  #  printf "."
  #  sleep 1
  #done
  #printf "\n"

  status=$(sudo service cloudera-scm-server status | cut -d ' ' -f6)
  if [[ "$status" == "running..." ]]; then
    #echo "CM Server is running"
    sudo service cloudera-scm-server restart
  else
    sudo service cloudera-scm-server start
  fi
      
  # sleep 30
  count=0
  while [ $count -lt 30 ]; 
  do
    count=$(( $count + 1 ))
    printf "."
    sleep 1
  done
  printf "\n"

  #/home/training/config/restart-agents.sh
  echo "Restarting CM agent on cmhost"
  sudo service cloudera-scm-agent restart
  echo "Restarting CM agent on master-1"
  ssh $nocheck training@master-1 sudo service cloudera-scm-agent restart
  echo "Restarting CM agent on master-2"
  ssh $nocheck training@master-2 sudo service cloudera-scm-agent restart
  echo "Restarting CM agent on worker-1"
  ssh $nocheck training@worker-1 sudo service cloudera-scm-agent restart
  echo "Restarting CM agent on worker-2"
  ssh $nocheck training@worker-2  sudo service cloudera-scm-agent restart
  echo "Restarting CM agent on worker-3"
  ssh $nocheck training@worker-3  sudo service cloudera-scm-agent restart
  echo "Restarting CM agent on gateway"
  ssh $nocheck training@gateway  sudo service cloudera-scm-agent restart
  #sleep 15
  count=0
  while [ $count -lt 15 ];
  do
    count=$(( $count + 1))
    printf "."
    sleep 1
  done
  printf "\n"
}



get_cluster_name() {
  echo
  echo "Getting Cluster Name"               
  echo
  clusters=$(curl -X GET -u "admin:admin" -i http://localhost:7180/api/v12/clusters/)
  
  if [[ $? -ne 0 ]]; then
      #CM API non-responsive
      echo "The CM API is non responsive. Is CM server running?"
  
  else
      #success case
      clusterN=$(echo $clusters | cut -d '"' -f6)
      
      #no cluster case
      if [[ "$clusterN" == "" ]]; then
        echo "No existing clusters found."
        echo
        echo "Exiting"
        exit 1
      fi
  fi
}

deploy_stale_configs() {
  echo "================================================="
  echo "Restarting CDH Services"              
  echo "================================================="
  # Re-deploy stale configurations for oozie and hue
  curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v12/clusters/$clusterN/services/oozie/commands/restart 2>/dev/null
  curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v12/clusters/$clusterN/services/hue/commands/restart 2>/dev/null
}


start_kudu_roles() {
  #Start the kudu roles after reset the clocks
  #Restarting the clocks on these nodes is a workaround to a known
  #issue where Kudu gets an unsynchronized clock error message
  echo "Restarting ntpd on worker-3"
  ssh $nocheck -p 443 -t training@worker-3 sudo service ntpd restart 2>/dev/null
  echo "Restarting ntpd on master-2"
  ssh $nocheck -p 443 -t training@master-2 sudo service ntpd restart 2>/dev/null  

  #Restarting Kudu service is used to force the startup to roles for Kudu Master and Tablet Server
  curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v12/clusters/$clusterN/services/kudu/commands/restart 2>/dev/null
}


restart_ntpd() {
  #no harm in this and it reduces changes of clock offset issues
  echo
  echo "=================================================" 
  echo "Synching System Clocks"               
  echo "=================================================" 
  echo
  echo "Restarting ntpd on cmhost" 
  sudo service ntpd restart 2>/dev/null
  echo "Restarting ntpd on master-1"
  ssh $nocheck -p 443 -t training@master-1 sudo service ntpd restart 2>/dev/null
  echo "Restarting ntpd on worker-1"
  ssh $nocheck -p 443 -t training@worker-1 sudo service ntpd restart 2>/dev/null
  echo "Restarting ntpd on worker-2"
  ssh $nocheck -p 443 -t training@worker-2 sudo service ntpd restart 2>/dev/null
  echo "Restarting ntpd on gateway"
  ssh $nocheck -p 443 -t training@gateway sudo service ntpd restart 2>/dev/null
}

check_kudu_status(){
  #reset clock if kudu comes up unhealth
  echo 
  echo "=================================================="
  echo "Checking Kudu Status after start up"
  echo "=================================================="
  echo 
  status=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v12/clusters/$clusterN/services/kudu/roles/kudu-KUDU_TSERVER | grep healthSummary | cut -d '"' -f4)
  if [[ "$status" == "BAD" ]]; then
    echo "Resetting clocks again for Kudu"
    ./reset-clocks.sh
  else
    echo "Kudu is healthy" 
  fi
}

check_cluster_status() {
  #reset clock if cluster comes up unhealth
  echo 
  echo "=================================================="
  echo "Checking Cluster Status after start up"
  echo "=================================================="
  echo 

  echo "Waiting 45 seconds to allow cluster to fully start..."
  #sleep 45
  count=0
  while [ $count -lt 45 ];
  do
    count=$(( $count + 1))
    printf "."
    sleep 1
  done
  printf "\n"


  status=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v12/clusters/$clusterN | grep entityStatus | cut -d '"' -f4)
  if [[ "$status" == "BAD_HEALTH" ]]; then
    echo "Resetting clocks again"
    ./reset-clocks.sh
  elif [[ "$status" == "UNKNOWN_HEALTH" ]]; then
    #start up Cloudera Management Service
    status=$(curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v12/cm/service/commands/start)
  else
    echo "Cluster is healthy" 
  fi
  
}

complete(){
  
  echo
  echo "============================================================" 
  echo " NEXT STEPS:"
  echo "------------------------------------------------------------"
  echo "1. Exit all open terminal windows including the proxy window."
  echo
  echo "2. Exit any open Firefox sessions."
  echo
  echo "3. Run Applications > Training > Start Proxy Server and login to"
  echo "   Cloudera Manager."
  echo 
  echo "   IMPORTANT NOTE: Some health warnings may appear just after the "
  echo "   cluster was started. If you see health issues in Cloudera Manager,"
  echo "   click 'All Health Issues' and then 'Organize by Health Test'. "
  echo 
  echo "   If there are Clock Offset issues, go to Applications > Training >"
  echo "   Connect to CM Host and run the following command:"
  echo "       $ ./config/reset-clocks.sh"
  echo
  echo "   Allow any other health issues up to five minutes to resolve themselves."
  echo "============================================================" 
  echo "Finished running start-cluster.sh at $(date '+%Y-%m-%d %T')"          
}

update_s3_creds
cleanup_and_log
start_aws_instances
verify_instances_ready
start_scm_server_and_all_agents
get_cluster_name
start_scm_server_and_all_agents
deploy_stale_configs
start_kudu_roles
restart_ntpd
check_kudu_status
check_cluster_status
deploy_stale_configs
complete

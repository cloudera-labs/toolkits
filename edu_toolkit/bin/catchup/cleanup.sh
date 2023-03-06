#!/bin/bash

# -------------------------[ Documentation ]------------------------------
#
# (1) Check that the script is running on cmhost, if not exit.  
#    The cleanup script depends on named nodes and that it is homed on cmhost
#    
# (2) Echo's the hostname where the script is running
#
# (3) Kill all scm agents and servers on all nodes
#    killAllProcessesOnAllNodes = Kills all scm agents and server process on all nodes
#
# (4) Uninstall yum RPMS beginning with "cloudera*" on all nodes
#    uninstallRPMsOnAllNodes =  calls next and uninstalls all RPMS on all nodes
#        uninstallRPMsOnOneNode = Uninstalls yum RPMS named cloudera*
#   
# (5) Unmount the temporary file system used by cm_process on all nodes
#    unmountTmpfs = Unmounts cm_processes temporary file system on all nodes
#
# (6) Deletes a long list of common generated files on all nodes
#    deleteFilesOnAllNodes =  calls next and delets files on all nodes
#       deleteFilesOnOneNode =  deletes common files on one node
#   
# (7) Deletes the databases and users from MySQL on node cmhost
#     deleteDBsAndUsers = Deletes the four MySQL database on cmhost
# 
# (8) Configure command line tools to use CDH7.1.2 as default
#


CDH712_PARCEL_EL7="CDH-7.1.2-1.cdh7.1.2.p0.4253134-el7.parcel" #used
CDH713_PARCEL_EL7="CDH-7.1.3-1.cdh7.1.3.p0.4992530-el7.parcel" #used

CLEANUP_LOG_DIR=/home/training/training_materials/admin/scripts/catchup/logs
mkdir -p $CLEANUP_LOG_DIR
CLEANUP_LOG="`date +%F`-CM7.1.3-CleanUp.log"
exec 2> $CLEANUP_LOG_DIR/$CLEANUP_LOG

printf '%s %s\n' "$(date)" "$line"

echo "Running script on " $(date)
if [ $HOSTNAME != "cmhost" ]; then
    echo "This script should only be run on cmhost. It appears you are running this on " $HOSTNAME
    echo "Exiting..."
    sleep 5
    exit 0
fi

killAllProcessesOnAllNodes() {
# TBD ERROR here:
# The 'hard_stop_confirmed' command is not supported on systemd based distributions. Please separately invoke the 'next_stop_hard' and 'stop' commands instead.
# stop cloudera-scm-agent & cloudera-scm-supervisord
	echo
	echo "Stopping all agent processes across all machines in parallel. Give it some time."
	echo "Some 'unrecognized service' messages are to be expected."
	echo
	sudo systemctl stop cloudera-scm-agent 2>&1 | sed -e 's/^/cmhost output> /' &
	ssh training@master-1 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-agent 2>&1 | sed -e 's/^/master-1 output> /' &
	ssh training@master-2 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-agent 2>&1 | sed -e 's/^/master-2 output> /' &
	ssh training@worker-1 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-agent 2>&1 | sed -e 's/^/worker-1 output> /' &
	ssh training@worker-2 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-agent 2>&1 | sed -e 's/^/worker-2 output> /' &
	ssh training@worker-3 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-agent 2>&1 | sed -e 's/^/worker-3 output> /' &
	wait
	 
  sudo systemctl stop cloudera-scm-supervisord 2>&1 | sed -e 's/^/cmhost output> /' &
  ssh training@master-1 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-supervisord 2>&1 | sed -e 's/^/master-1 output> /' &
  ssh training@master-2 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-supervisord 2>&1 | sed -e 's/^/master-2 output> /' &
  ssh training@worker-1 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-supervisord 2>&1 | sed -e 's/^/worker-1 output> /' &
  ssh training@worker-2 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-supervisord 2>&1 | sed -e 's/^/worker-2 output> /' &
  ssh training@worker-3 -o StrictHostKeyChecking=no sudo systemctl stop cloudera-scm-supervisord 2>&1 | sed -e 's/^/worker-3 output> /' &
  wait
 	echo
	echo "Stop CM server - try across all machines in case it was installed on the wrong machine."
	echo "Some 'unrecognized systemctl' messages are to be expected."
	echo
	sudo systemctl stop cloudera-scm-server  2>&1 | sed -e 's/^/cmhost output> /' &
	ssh training@master-1 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server 2>&1 | sed -e 's/^/master-1 output> /' &
	ssh training@master-2 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server 2>&1 | sed -e 's/^/master-2 output> /' &
	ssh training@worker-1 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server 2>&1 | sed -e 's/^/worker-1 output> /' &
	ssh training@worker-2 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server 2>&1 | sed -e 's/^/worker-2 output> /' &
	ssh training@worker-3 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server 2>&1 | sed -e 's/^/worker-3 output> /' &
	
#	sudo systemctl stop  cloudera-scm-server-db stop 2>&1 | sed -e 's/^/cmhost output> /' &
#	ssh training@master-1 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server-db 2>&1 | sed -e 's/^/master-1 output> /' &
#	ssh training@master-2 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server-db 2>&1 | sed -e 's/^/master-2 output> /' &
#	ssh training@worker-1 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server-db 2>&1 | sed -e 's/^/worker-1 output> /' &
#	ssh training@worker-2 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server-db 2>&1 | sed -e 's/^/worker-2 output> /' &
#	ssh training@worker-3 -o StrictHostKeyChecking=no sudo systemctl stop  cloudera-scm-server-db 2>&1 | sed -e 's/^/worker-3 output> /' &
	wait
}
	
unmountTmpfs() {
    echo
	echo "Unmounting cm_processes on cmhost"
    sudo umount -f cm_processes    
    echo "Unmounting cm_processes on master-1"
    ssh training@master-1 -o StrictHostKeyChecking=no sudo umount -f cm_processes 
    echo "Unmounting cm_processes on master-2"
    ssh training@master-2 -o StrictHostKeyChecking=no sudo umount -f cm_processes
    echo "Unmounting cm_processes on worker-1"
    ssh training@worker-2 -o StrictHostKeyChecking=no sudo umount -f cm_processes
    echo "Unmounting cm_processes on worker-2"
    ssh training@worker-3 -o StrictHostKeyChecking=no sudo umount -f cm_processes
    echo "Unmounting cm_processes on worker-3"
    ssh training@worker-1 -o StrictHostKeyChecking=no sudo umount -f cm_processes
    # if umount fails, sudo lsof | grep /var/run/cloudera will show what process is locking it up.
}

uninstallRPMsOnOneNode() {
  $1 sudo yum remove --assumeyes cloudera*
  $1 sudo yum clean all
}

uninstallRPMsOnAllNodes() {
  echo 
  echo "******************************************************************"
  echo ">>>Uninstalling all Hadoop and ecosystem RPMs on cmhost."
  echo "******************************************************************"
  echo 
  uninstallRPMsOnOneNode "" 

  echo 
  echo "******************************************************************"
  echo ">>>Uninstalling all Hadoop and ecosystem RPMs on master-1."
  echo "******************************************************************"
  echo 
  uninstallRPMsOnOneNode "ssh training@master-1 -o StrictHostKeyChecking=no"

  echo 
  echo "******************************************************************"
  echo ">>>Uninstalling all Hadoop and ecosystem RPMs on master-2."
  echo "******************************************************************"
  echo 
  uninstallRPMsOnOneNode "ssh training@master-2 -o StrictHostKeyChecking=no"

  echo 
  echo "******************************************************************"
  echo ">>>Uninstalling all Hadoop and ecosystem RPMs on worker-1."
  echo "******************************************************************"
  echo 
  uninstallRPMsOnOneNode "ssh training@worker-1 -o StrictHostKeyChecking=no"

  echo 
  echo "******************************************************************"
  echo ">>>Uninstalling all Hadoop and ecosystem RPMs on worker-2."
  echo "******************************************************************"
  echo 
  uninstallRPMsOnOneNode "ssh training@worker-2 -o StrictHostKeyChecking=no"

  echo
  echo "******************************************************************" 
  echo ">>>Uninstalling all Hadoop and ecosystem RPMs on worker-3."
  echo "******************************************************************"
  echo 
  uninstallRPMsOnOneNode "ssh training@worker-3 -o StrictHostKeyChecking=no"

}

deleteFilesOnOneNode() {
  $1 sudo rm -rf /disk1
  $1 sudo rm -rf /disk2
  $1 sudo rm -rf /dfs
  $1 sudo rm -rf /mapred
  $1 sudo rm -rf /etc/cloudera*
  $1 sudo rm -rf /etc/default/impala
  $1 sudo rm -rf /etc/flume-ng
  $1 sudo rm -rf /etc/hadoop
  $1 sudo rm -rf /etc/hbase*
  $1 sudo rm -rf /etc/hive*
  $1 sudo rm -rf /etc/hue
  $1 sudo rm -rf /etc/impala
  $1 sudo rm -rf /etc/llama
  $1 sudo rm -rf /etc/oozie
  $1 sudo rm -rf /etc/pig
  $1 sudo rm -rf /etc/solr
  $1 sudo rm -rf /etc/spark
  $1 sudo rm -rf /etc/sqoop*
  $1 sudo rm -rf /etc/zookeeper
  $1 sudo rm -rf /etc/alternatives/flume*
  $1 sudo rm -rf /etc/alternatives/hadoop*
  $1 sudo rm -rf /etc/alternatives/hbase*
  $1 sudo rm -rf /etc/alternatives/hive*
  $1 sudo rm -rf /etc/alternatives/hue*
  $1 sudo rm -rf /etc/alternatives/impala*
  $1 sudo rm -rf /etc/alternatives/llama*
  $1 sudo rm -rf /etc/alternatives/oozie*
  $1 sudo rm -rf /etc/alternatives/pig*
  $1 sudo rm -rf /etc/alternatives/solr*
  $1 sudo rm -rf /etc/alternatives/spark*
  $1 sudo rm -rf /etc/alternatives/sqoop*
  $1 sudo rm -rf /etc/alternatives/zookeeper*
  $1 sudo rm -rf /home/training/backup_config
  $1 sudo rm -rf /opt/cloudera/parcels/*
  $1 sudo rm -rf /opt/cloudera/parcel-cache/*
  $1 sudo rm -rf /tmp/*scm*
  $1 sudo rm -rf /tmp/.*scm*
  $1 sudo rm -rf /tmp/hadoop*
  $1 sudo rm -rf /var/cache/yum/cloudera*
  $1 sudo rm -rf /usr/lib/hadoop*
  $1 sudo rm -rf /usr/lib/hive*
  $1 sudo rm -rf /usr/lib/hue
  $1 sudo rm -rf /usr/lib/oozie
  $1 sudo rm -rf /usr/lib/parquet
  $1 sudo rm -rf /usr/lib/spark
  $1 sudo rm -rf /usr/lib/sqoop
  $1 sudo rm -rf /usr/share/cmf
  $1 sudo rm -rf /usr/share/hue
  $1 sudo rm -rf /var/lib/cloudera*
  $1 sudo rm -rf /var/lib/flume-ng
  $1 sudo rm -rf /var/lib/hadoop*
  $1 sudo rm -rf /var/lib/hdfs
  $1 sudo rm -rf /var/lib/hive*
  $1 sudo rm -rf /var/lib/hue
  $1 sudo rm -rf /var/lib/impala
  $1 sudo rm -rf /var/lib/oozie
  $1 sudo rm -rf /var/lib/sqoop*
  $1 sudo rm -rf /var/lib/spark
  $1 sudo rm -rf /var/lib/solr
  $1 sudo rm -rf /var/lib/zookeeper
  $1 sudo rm -rf /var/lib/alternatives/flume*
  $1 sudo rm -rf /var/lib/alternatives/hadoop*
  $1 sudo rm -rf /var/lib/alternatives/hbase*
  $1 sudo rm -rf /var/lib/alternatives/hive*
  $1 sudo rm -rf /var/lib/alternatives/hue*
  $1 sudo rm -rf /var/lib/alternatives/impala*
  $1 sudo rm -rf /var/lib/alternatives/llama*
  $1 sudo rm -rf /var/lib/alternatives/oozie*
  $1 sudo rm -rf /var/lib/alternatives/pig*
  $1 sudo rm -rf /var/lib/alternatives/solr*
  $1 sudo rm -rf /var/lib/alternatives/spark*
  $1 sudo rm -rf /var/lib/alternatives/sqoop*
  $1 sudo rm -rf /var/lib/alternatives/zookeeper*
  $1 sudo rm -rf /var/lock/subsys/cloudera*
  $1 sudo rm -rf /var/lock/subsys/flume-ng*
  $1 sudo rm -rf /var/lock/subsys/hadoop*
  $1 sudo rm -rf /var/lock/subsys/hbase*
  $1 sudo rm -rf /var/lock/subsys/hdfs*
  $1 sudo rm -rf /var/lock/subsys/hive*
  $1 sudo rm -rf /var/lock/subsys/hue*
  $1 sudo rm -rf /var/lock/subsys/impala*
  $1 sudo rm -rf /var/lock/subsys/llama*
  $1 sudo rm -rf /var/lock/subsys/oozie*
  $1 sudo rm -rf /var/lock/subsys/solr*
  $1 sudo rm -rf /var/lock/subsys/spark*
  $1 sudo rm -rf /var/lock/subsys/sqoop*
  $1 sudo rm -rf /var/lock/subsys/zookeeper*
  $1 sudo rm -rf /var/log/cloudera*
  $1 sudo rm -rf /var/log/flume-ng
  $1 sudo rm -rf /var/log/hadoop*
  $1 sudo rm -rf /var/log/hbase*
  $1 sudo rm -rf /var/log/hive*
  $1 sudo rm -rf /var/log/hue
  $1 sudo rm -rf /var/log/impala*
  $1 sudo rm -rf /var/log/llama
  $1 sudo rm -rf /var/log/oozie
  $1 sudo rm -rf /var/log/solr
  $1 sudo rm -rf /var/log/sqoop2
  $1 sudo rm -rf /var/log/spark
  $1 sudo rm -rf /var/log/zookeeper
  $1 sudo rm -rf /var/run/cloudera*
  $1 sudo rm -rf /var/run/flume-ng
  $1 sudo rm -rf /var/run/hadoop*
  $1 sudo rm -rf /var/run/hbase*
  $1 sudo rm -rf /var/run/hdfs*
  $1 sudo rm -rf /var/run/hive
  $1 sudo rm -rf /var/run/impala
  $1 sudo rm -rf /var/run/llama
  $1 sudo rm -rf /var/run/oozie
  $1 sudo rm -rf /var/run/solr
  $1 sudo rm -rf /var/run/spark
  $1 sudo rm -rf /var/run/sqoop2
  $1 sudo rm -rf /var/run/zookeeper
  $1 sudo rm -rf /yarn
  $1 sudo rm -rf /var/log/nifi
  $1 sudo rm -rf /var/log/yarn
  $1 sudo rm -rf /var/local/kafka/data/meta.properties
  $1 sudo rm -rf /etc/kafka
  $1 sudo rm -rf /etc/kafka_connect_ext
  $1 sudo rm -rf /var/lib/hadoop-yarn
}

deleteFilesOnAllNodes() {
  echo 
  echo "Deleting files on cmhost."
  echo 
  deleteFilesOnOneNode "" 

  echo 
  echo "Deleting files on master-1."
  echo 
  deleteFilesOnOneNode "ssh training@master-1 -o StrictHostKeyChecking=no"

  echo 
  echo "Deleting files on master-2."
  echo 
  deleteFilesOnOneNode "ssh training@master-2 -o StrictHostKeyChecking=no"

  echo 
  echo "Deleting files on worker-1."
  echo 
  deleteFilesOnOneNode "ssh training@worker-1 -o StrictHostKeyChecking=no"

  echo 
  echo "Deleting files on worker-2."
  echo 
  deleteFilesOnOneNode "ssh training@worker-2 -o StrictHostKeyChecking=no"

  echo 
  echo "Deleting files on worker-3."
  echo 
  deleteFilesOnOneNode "ssh training@worker-3 -o StrictHostKeyChecking=no"
}

deleteDBsAndUsers() {
  echo
  echo "Deleting the four databases and users from MySQL on cmhost."
  echo
  echo "This script will make a few attempts to delete the tables and users in the database."
  echo "Give it time and let it run without assistance, ignoring initial errors."
  echo "You should eventually see Query OK messages."
  echo ""

  #One of these three scripts will work depending on the current mysql root password
  ssh training@cmhost -o StrictHostKeyChecking=no /home/training/training_materials/admin/scripts/catchup/setMysqlPwd.sh
  ssh training@cmhost -o StrictHostKeyChecking=no /home/training/training_materials/admin/scripts/catchup/setMysqlPwd2.exp
  ssh training@cmhost -o StrictHostKeyChecking=no /home/training/training_materials/admin/scripts/catchup/setMysqlPwd3.exp

  #Drop users and tables
  ssh training@cmhost -o StrictHostKeyChecking=no /home/training/training_materials/admin/scripts/catchup/dropDBsAndUsers.exp 
  sleep 5

  #Reset root password to 'training'
  ssh training@cmhost -o StrictHostKeyChecking=no mysqladmin --user=root password "training"

}

cleanCmdlineDefaults() {
	# Use Alternatives uitlity command to reset commnad line defaults.

	# Reset hdfs
	#sudo alternatives --remove hdfs /opt/cloudera/parcels/CDH-5.14.4-1.cdh5.14.4.p0.3/bin/hdfs
    #sudo alternatives --remove hdfs /opt/cloudera/parcels/CDH-5.15.2-1.cdh5.15.2.p0.3/bin/hdfs
    sudo alternatives --remove hdfs /opt/cloudera/parcels/CDH-7*/bin/hdfs

	# Reset yarn
	#sudo alternatives --remove yarn /opt/cloudera/parcels/CDH-5.14.4-1.cdh5.14.4.p0.3/bin/yarn
	#sudo alternatives --remove yarn /opt/cloudera/parcels/CDH-5.15.2-1.cdh5.15.2.p0.3/bin/yarn
    sudo alternatives --remove yarn /opt/cloudera/parcels/CDH-7*/bin/yarn

	# Reset beeline
	#sudo alternatives --remove beeline /opt/cloudera/parcels/CDH-5.14.4-1.cdh5.14.4.p0.3/bin/beeline
	#sudo alternatives --remove beeline /opt/cloudera/parcels/CDH-5.15.2-1.cdh5.15.2.p0.3/bin/beeline
    sudo alternatives --remove beeline /opt/cloudera/parcels/CDH-7*/bin/beeline

	# Reset mapred
	#sudo alternatives --remove mapred /opt/cloudera/parcels/CDH-5.14.4-1.cdh5.14.4.p0.3/bin/mapred
	#sudo alternatives --remove mapred /opt/cloudera/parcels/CDH-5.15.2-1.cdh5.15.2.p0.3/bin/mapred
    sudo alternatives --remove mapred /opt/cloudera/parcels/CDH-7*/bin/mapred
}

setCmdlineDefaults712() {

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

  #Configure mapred to C5.14
  expect -c "set timeout -1
spawn sudo alternatives --config mapred
expect -re \"Enter *\"
send \"1\r\"
expect eof"

}


#setOwnership() {
#}



MYHOST="`hostname`: "
echo
echo $MYHOST "Running " $0"."
echo

killAllProcessesOnAllNodes $1 | dialog --title "Stop all Processes on all nodes" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
uninstallRPMsOnAllNodes $1 | dialog --title "Un-install all RPMs from all nodes" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
unmountTmpfs $1 |  dialog --title "Un-mount Cloudera Agent tmpfs" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
deleteFilesOnAllNodes $1 | dialog --title "Files clean up on all nodes" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
deleteDBsAndUsers $1 | dialog --title "Clean up configuration DBs and Users" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
cleanCmdlineDefaults | dialog --title "Clean up Cmdline defaults" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
setCmdlineDefaults712 | dialog --title "Setup Cmdline defaults" --backtitle "Cluster Clean Up" --no-collapse --progressbox 20 100
#setOwnership

echo
echo $MYHOST $0 "done."
echo

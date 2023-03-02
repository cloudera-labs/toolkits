#! /bin/sh

LOG_DIR=/home/training/training_materials/admin/scripts/logs
mkdir -p $LOG_DIR
#CLEANUP_LOG="`date +%Y-%m-%d_%H-%M-%S`-CM7.1.3-CleanUp.log"
LOG_FILE="`date +%Y-%m-%d-%H:%M:%S`-CM-PreUpgrade.log"
exec 2> $LOG_DIR/$LOG_FILE

echo "---- Starting pre-upgrade backup script for upgrading CDH 7.1.2 to CDP Cloudera Runtime 7.1.3"
echo "---- Disregard tar warnings below --------"

# echo "-- Shutting down Cloudera Manager on cmhost"
# sudo systemctl stop cloudera-scm-server

# Back up Cloudera Manager data
export CM_BACKUP_DIR="`date +%F`-CM7.1.3"

echo "---- Saving agent files and yum repos on cmhost"
mkdir -p /tmp/$CM_BACKUP_DIR 
sudo -E tar -cf /tmp/$CM_BACKUP_DIR/cloudera-scm-agent.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
sudo -E tar -cf /tmp/$CM_BACKUP_DIR/repository.tar /etc/yum.repos.d

echo "---- Saving agent files and yum repos on worker-1"
ssh worker-1 mkdir -p /tmp/$CM_BACKUP_DIR 
ssh worker-1 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/cloudera-scm-agent.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
ssh worker-1 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/repository.tar /etc/yum.repos.d

echo "---- Saving agent files and yum repos on worker-2"
ssh worker-2 mkdir -p /tmp/$CM_BACKUP_DIR 
ssh worker-2 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/cloudera-scm-agent.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
ssh worker-2 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/repository.tar /etc/yum.repos.d

echo "---- Saving agent files and yum repos on worker-3"
ssh worker-3 mkdir -p /tmp/$CM_BACKUP_DIR 
ssh worker-3 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/cloudera-scm-agent.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
ssh worker-3 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/repository.tar /etc/yum.repos.d

echo "---- Saving agent files and yum repos on master-1"
ssh master-1 mkdir -p /tmp/$CM_BACKUP_DIR 
ssh master-1 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/cloudera-scm-agent.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
ssh master-1 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/repository.tar /etc/yum.repos.d

echo "---- Saving agent files and yum repos on master-2"
ssh master-2 mkdir -p /tmp/$CM_BACKUP_DIR 
ssh master-2 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/cloudera-scm-agent.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
ssh master-2 sudo -E tar -cf /tmp/$CM_BACKUP_DIR/repository.tar /etc/yum.repos.d


# Back up CDH databases
echo "---- Backing up MySQL databases oozie, hue, and metastore"
export CDH_BACKUP_DIR="`date +%F`-CDH7.1.2"
mkdir -p /tmp/$CDH_BACKUP_DIR
mysqldump -u root -ptraining --databases oozie hue metastore > /tmp/$CDH_BACKUP_DIR/backup.sql

# Back up zookeeper data
echo "---- Backing up zookeeper directories"
cp -rp /var/lib/zookeeper/ /tmp/CDH7.1.2-zookeeper-backup
ssh master-1 cp -rp /var/lib/zookeeper/ /tmp/CDH7.1.2-zookeeper-backup
ssh master-2 cp -rp /var/lib/zookeeper/ /tmp/CDH7.1.2-zookeeper-backup

# Back up Journal Node data
echo "---- Backing up Journal Node data on master-1, worker-2, and worker-3"
echo "---- Note that these commands are expected to fail if HDFS is not configured for high availability"
ssh root@master-1 cp -rp /dfs/jn /tmp/CDH7.1.2-dfsjn-backup
ssh root@worker-2 cp -rp /dfs/jn /tmp/CDH7.1.2-dfsjn-backup
ssh root@worker-3 cp -rp /dfs/jn /tmp/CDH7.1.2-dfsjn-backup

# Create rollback directories on all NameNode hosts
echo "---- Creating NameNode rollback directories on master-1"
ssh root@master-1 mkdir -p /etc/hadoop/conf.rollback.namenode
ssh root@master-1 'cp -rpf /var/run/cloudera-scm-agent/process/`ls -t1 /var/run/cloudera-scm-agent/process  | grep -e "-NAMENODE\$" | head -1`/* /etc/hadoop/conf.rollback.namenode/'
ssh root@master-1 rm /etc/hadoop/conf.rollback.namenode/log4j.properties

echo "---- Creating NameNode rollback directories on master-2"
ssh root@master-2 mkdir -p /etc/hadoop/conf.rollback.namenode
ssh root@master-2 'cp -rpf /var/run/cloudera-scm-agent/process/`ls -t1 /var/run/cloudera-scm-agent/process  | grep -e "-NAMENODE\$" | head -1`/* /etc/hadoop/conf.rollback.namenode/'
ssh root@master-2 rm /etc/hadoop/conf.rollback.namenode/log4j.properties

# Create rollback directories on all DataNode hosts
echo "---- Creating DataNode rollback directories on worker-1"
ssh root@worker-1 mkdir -p /etc/hadoop/conf.rollback.datanode/
ssh root@worker-3 'cp -rpf /var/run/cloudera-scm-agent/process/`ls -t1 /var/run/cloudera-scm-agent/process  | grep -e "-DATANODE\$" | head -1`/* /etc/hadoop/conf.rollback.datanode/'
#ssh root@worker-1 rm /etc/hadoop/conf.rollback.datanode/log4j.properties
ssh root@worker-1 cp -pf /etc/hadoop/conf.cloudera.hdfs/log4j.properties /etc/hadoop/conf.rollback.datanode/

echo "---- Creating DataNode rollback directories on worker-2"
ssh root@worker-2 mkdir -p /etc/hadoop/conf.rollback.datanode/
ssh root@worker-2 'cp -rpf /var/run/cloudera-scm-agent/process/`ls -t1 /var/run/cloudera-scm-agent/process  | grep -e "-DATANODE\$" | head -1`/* /etc/hadoop/conf.rollback.datanode/'
#ssh root@worker-2 rm /etc/hadoop/conf.rollback.datanode/log4j.properties
ssh root@worker-2 cp -pf /etc/hadoop/conf.cloudera.hdfs/log4j.properties /etc/hadoop/conf.rollback.datanode/

echo "---- Creating DataNode rollback directories on worker-3"
ssh root@worker-3 mkdir -p /etc/hadoop/conf.rollback.datanode/
ssh root@worker-3 'cp -rpf /var/run/cloudera-scm-agent/process/`ls -t1 /var/run/cloudera-scm-agent/process  | grep -e "-DATANODE\$" | head -1`/* /etc/hadoop/conf.rollback.datanode/'
#ssh root@worker-3 rm /etc/hadoop/conf.rollback.datanode/log4j.properties
ssh root@worker-3 cp -pf /etc/hadoop/conf.cloudera.hdfs/log4j.properties /etc/hadoop/conf.rollback.datanode/

# Back up Hue Server registry file on cmhost
echo "---- Backing up Hue Server registry file on cmhost"
sudo mkdir -p /opt/cloudera/parcels_backup/
sudo cp -p /opt/cloudera/parcels/CDH/lib/hue/app.reg /opt/cloudera/parcels_backup/app.reg-CDH7.1.2

echo "---- $CM_BACKUP_LOG log file has been generated."
echo "---- Backup script complete.  You can upgrade the cluster now."

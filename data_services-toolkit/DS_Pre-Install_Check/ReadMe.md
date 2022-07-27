# CDP PvC Data Services Pre-Req Checker

## Utilize this Script to Determine if the Base Cluster & ECS Compute Node Pre-Requisites are Met

### The script will generate separate sheets in the Excel workbook titled:
   * Status Summary
   * Incompatible Versions Error Log
   * TLS Service Level Info
   * Kerberos Information


1. Status Summary
    * Base Cluster Nodes Check:
      * Database Version Installed Supported?
      * Postgres DB Encrypted?  
      * Kerberos Enabled?
      * All nodes have enough space to accommodate the CDP Parcel (20GB)?
      * All nodes are running the supported version of Linux?
      * All nodes are running the supported version of Java?
      * All Nodes are running the supported version of Python?
      * Base Cluster Database Version Supported?
    * ECS Compute Node Check:    
      * All nodes are not running firewalld
      * All nodes are running either NTP or Chronyd
      * All nodes have vm.swappiness=1
      * All nodes have nfs utils installed
      * All nodes have SE Linux disabled
      * All nodes have SCSI Devices
      * All nodes have devices with ftype=1


2. Incompatible Versions Error Log
   * This sheet will list out all the hosts that do not adhere to the requirements along with the necessary fix


3. TLS Settings for the Following Services/Role Configuration Groups:
    * Hive Server 2
    * Hive Metastore Server
    * Atlas
    * Ranger Admin
    * Ranger Tag-Sync
    * Ozone Datanode
    * Ozone Manager
    * Ozone Recon
    * Ozone Gateway
    * Ozone Storage Container Manager
    * Solr
    * HBase Rest Server
    * HBase Thrift Server
    * Zookeeper
    * Impala
    * Kafka Broker
    * Kafka Connect
    * Solr
    * HDFS
    * Hue
    * Ranger RMS
   

4. Kerberos Settings for the Following Services:
   * Atlas
   * Ozone
   * Solr
   * HBase
   * Zookeeper
   * Zookeeper
   * Kafka
   * HDFS
   * Ranger RMS
 

## Requirements
1. Execute preinstall_check.py from a host with passwordless ssh access to all Base Cluster & ECS Compute Hosts
2. Clone entire repository including the bash scripts to the master host used for execution   
3. python3 with the below packages
```python
import os
import subprocess
import requests
import re
import json
import sys
import cm_client

```

## Configure:
* cm_user (Cloudera Manager Username)
* cm_pass (Cloudera Manager Passowrd)
* cm_host_name (Cloudera Manager Host)
* ecs_hosts (ECS Compute Hosts)
* postgres_host (ECS Postgres DB Host)

```bash
cm_client.configuration.username = 'admin'
cm_client.configuration.password = 'admin'
cm_host_name = 'cm_url'

# Define ECS Hosts
ecs_hosts = ["ecs-1.company.com",
             "ecs-2.company.com",
             "ecs-3.company.com",
             "ecs-4.company.com",
             "ecs-5.company.com"]

# Define Postgres ECS DB Host
postgres_host = "ecs-db-host.company.com"
```

## Example Execution

```bash
pip3 install requests, xlsxwriter, cm_client
cd /toolkits/data_services-toolkit/DS_Pre-Install_Check
python3 preinstall_check.py
```

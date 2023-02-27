# CDP Toolkits

## CDP Educational Toolkit

### Summary
This toolkit consists of administrative scripts, data, ddl, notebooks, and tutorials used in classes taught by Cloudera Educational Services. This toolkit is intended for educational purposes only.


## CDP Upgrade Toolkit

### Summary
This toolkit can be used to migrate an existing CDH cluster to CDP. There are multiple directories each of which represent 
a separate artifact that make up the toolkit. Each individual subdirectory contains a ReadME with directions on execution. 

### Disclaimer
The CDP Upgrade toolkit is offered as a free utility from Cloudera, is open sourced under the Apache License version 2.0, is not warranted, and does not fall under the purview of Cloudera support. For any questions/issues in implementation, Cloudera recommends you contact your account team and/or engage professional services.
### CDP Upgrade Flow
 1. CDH Cluster Inventory  
 2. CDP Version Check
 3. Hive Code Scanner   
 4. Backup Playbooks
 5. CDP Upgrade 
 6. Rollback (if necessary) 
 7. CDP Upgrade 
 8. CDP Configuration Push 
 9. CDP Smoke Test 

### CDH Cluster Inventory

#### This script will generate an excel file with the following sheets:
> 1. Host Information
> 2. Cloudera Version Information

#### A sheet will be created for every cluster that is managed within the CM env specified that contains:
> 1. Service Type 
> 2. Service Name

Please see the ReadME in the CDH Cluster Inventory directory for more information

### CDP Version Check
This script should be run prior to the CDP Upgrade to determine if the versions of critical components present in the cluster will pose any risks to the upgrade. The script will compare versions installed against the CDP Support matrix that can be found at: https://supportmatrix.cloudera.com/

#### This script will generate an excel file with the following sheets:
> 1. Status Summary
>2. Incompatible Versions Error Log 

Please see the ReadME in the CDP Version Check directory for more information.

# Hive Code Scanner

Utilize this code scanner to scan hql files and property files to assess changes that need to be made after upgrade to CDP which utilizes Hive 3


### Ansible Hostfile Generation

The nodes.py script will generate an ansible formatted hostfile for the cluster given as an input. 

Please see the ReadME in the utilities directory for more information.

### Backup Playbooks
These playbooks will collect backups of all services and databases prior to a CDP Upgrade.  
You may have to edit some paths in the playbooks to point to your specific configuration.

Please see the ReadME in the Backup Playbooks directory for more information.

### CDP In-Place Upgrade
Utilize the Cloudera Manager wizard to complete the CDP Upgrade

### Rollback
This set of playbooks and scripts can utilized to rollback a CDP Upgrade back to CDH. The directions to complete a full 
rollback are detailed in the ReadME file found in the Rollback Playbook directory.

### CDP Configuration Push

Utilize the apply_properties.py script and json objects to push CM Configurations for the new services added after the CDP Upgrade as well as configurations for existing key services. Sample JSON templates have been provided for the following services:
* Ranger
* Ranger RMS
* Ranger KMS KTS
* Atlas
* Hive
* Hive on Tez
* HDFS
* Kafka
* CDP Infra SOLR

Please see the ReadMe in the CDP Configuration Push directory for more information.

### CDP Smoke Test
This script should be run after the CDP Upgrade to ensure functionality of all services on the newly upgraded CDP Cluster.
This script will generate an output displaying the status of each service test.

Please see the ReadMe in the CDP Smoke Test directory for more information.

### CDP PvC DS Pre-Req Check
This script should be run prior to a Data Services Installation to verify that all nodes have the necessary packages and utilities installed.

Please see the ReadMe in the data_services-toolkit directory for more information.


### CDH-Discovery-Tool
This Discovery Tool is a lightweight automation package can run against a CDH or CDP cluster to produce a "Discovery Bundle" that is useful for CDP migration planning.

Please see the ReadMe in the CDH-Discovery-Tool directory for more information.


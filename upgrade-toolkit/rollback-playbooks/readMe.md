# Rollback Playbook



## Limitations

- HDFS – If you have finalized the HDFS upgrade, you cannot roll back your cluster.
- Compute clusters – Rollback for Compute clusters is not currently supported.
- Configuration changes, including the addition of new services or roles after the upgrade, are not retained after rolling back Cloudera Manager.
- Cloudera recommends that you not make configuration changes or add new services and roles until you have finalized the HDFS upgrade and no longer require the option to roll back your upgrade.
- HBase – If your cluster is configured to use HBase replication, data written to HBase after the upgrade might not be replicated to peers when you start your rollback.
- Sqoop 2 – As described in the upgrade process, Sqoop2 had to be stopped and deleted before the upgrade process and therefore will not be available after the rollback.
- Kafka – Once the Kafka log format and protocol version configurations (the inter.broker.protocol.version and log.message.format.version properties) are set to the new version (or left blank, which means to use the latest version), Kafka rollback is not possible.


## HBase Considerations
The HBase Master procedures changed between the two versions, so if a procedure was started by HBase 2.2 (CDP 7.x) then the older HBase 2.1 won't be able to continue the procedure after the rollback. For this reason the Procedure Store in HBase Master must be cleaned before the rollback.
To avoid this problem, you should try to verify that no unfinished procedure is present before stopping HBase Master on the CDP 7.x Cluster.
```sh
ssh hbase-master-host
sh hbase_change.sh
exit
```
Log into Cloudera Manager and stop the HBase Service

Navigate to YARN Service and Select “Clean NodeManager Recovery Directory” from the Actions dropdown

## Stop Cluster for Downgrade
Stop the Cluster (Actions → Stop Cluster)

## Downgrade CDH Parcel
Activate CDH 6.2.1 Parcel
> Note: Select "Activate Only"

## Shutdown Cloudera Manager Server and Agents
```sh
ansible-playbook rollback-playbook/stop_cluster.yml -i environments/env/hosts
```
> This will stop the cloudera-scm-server as well as hard stop the cloudera-scm-agent on all hosts in the cluster

## Shutdown Cloudera Management Services & Restore Backups
Stop Cloudera Management Services
```sh
ansible-playbook rollback-playbook/cm_databases_rollback.yml -i environments/env/hosts 
```
> This will restore /etc/cloudera-scm-agent ; /var/lib/cloudera-scm-agent ; /etc/default/cloudera-scm-agent

```sh
ansible-playbook rollback-playbook/cm_server_restore.yml -i environments/env/hosts 
```
> This will rollback Host Monitor, Reports Manager, Service Monitor, Event Server, Navigator Audit Server, and Navigator Metadata Server

## Start Cloudera Manager Server & Cloudera Manager Agents
```sh
ansible-playbook rollback-playbook/start_cluster.yml -i environments/env/hosts 
```
> This will start cloudera-scm-server and cloudera-scm-agent on all hosts in the cluster. Some services may show up unhealthy on the UI, this is expected behavior.

## Rollback Zookeeper
```sh
ansible-playbook rollback-playbook/zk_rollback.yml -i environments/env/hosts 
```
> This will rollback the zookeeper data directory

Start Zookeeper from Cloudera Manager (Actions --> Start )

## Edit scripts for HDFS TLS Restore
For nn_edits.sh
```shell
sed '/<name>ssl.server.keystore.password<\/name>/!b;n;c<value>changeme</value>'
```
> Replace "changeme" with the ssl keystore value throughout the script 

For dn_edits.sh
```shell
sed '/<name>ssl.server.keystore.password<\/name>/!b;n;c<value>changeme</value>' ssl-server.xml
```
> Replace "changeme" with the ssl keystore value throughout the script

## Rollback HDFS Journal Nodes
```sh
ansible-playbook rollback-playbook/jn_rollback.yml -i environments/env/hosts 
```
> This will rollback the journal node edits directory on all journal nodes

Start All Journal Node Instances from Cloudera Manager

## Rollback HDFS Name Nodes
```sh
ansible-playbook rollback-playbook/nn_rollback.yml -i environments/env/hosts 
```
> This will rollback the name node edits directory on all namenodes

Connect to each name node
``` sh
kinit -kt /etc/hadoop/conf.rollback.namenode/hdfs.keytab hdfs/$HOSTNAME
sudo -u hdfs hdfs --config /etc/hadoop/conf.rollback.namenode namenode -rollback 
```
Restart All Name Nodes and Journal Nodes from Cloudera Manager

## Rollback HDFS Data Nodes
```sh
ansible-playbook rollback-playbook/dn_rollback.yml -i environments/env/hosts 
```
> This will rollback previous Data Node configuration on all Data Nodes

Restart Entire HDFS Service from Cloudera Manager

## Rollback HBase
Connect to a HBase Gateway Host
```sh
zookeeper-client -server  zookeeper_ensemble
```
> To find the value to use for zookeeper_ensemble, open the /etc/hbase/conf.cloudera.<HBase service name>/hbase-site.xml file on any HBase gateway host. Use the value of the hbase.zookeeper.quorum property.

```sh
rmr /hbase
quit
```
Wait for HBase to become healthy
```sh
sh hbase_recover.sh
```
> This will ensure that all the CDP HBase features are toggled off

## Restore CDH Databases
```sh
ansible-playbook rollback-playbook/db_restore.yml -i environments/env/hosts 
```
> This will restore the hive metastore, hue, oozie, and sentry server databases

## Start Sentry
From Cloudera Manager, start the Sentry Service

## Rollback SOLR Service
```sh
ansible-playbook rollback-playbook/solr_rollback.yml -i environments/env/hosts 
```
> This will remove the solr instance directory local FS Template on solr_server hosts
> Note: If the state of one or more Solr core is down and the Solr log contains an org.apache.lucene.store.LockObtainFailedException: Lock obtain timed out: org.apache.solr.store.hdfs.HdfsLockFactory error message, it is necessary to clean up the HDFS locks in the index directories.

## Rollback Hue
```sh
ansible-playbook rollback-playbook/hue_rollback.yml -i environments/env/hosts 
```
> This will restore the hue app.reg file on all hue server hosts

## Rollback Kafka
Activate the previos CDH 6 parcel

Remove the following properties from the Kafka Broker Advanced Configuration Snippet (Safety Valve) configuration property.
- Inter.broker.protocol.version
- Log.message.format.version

## Deploy Client Configuration
From Cloudera Manager, deploy the client configuration for the entire Cluster

## Restart the Cluster from Cloudera Manager
Actions -->   Restart

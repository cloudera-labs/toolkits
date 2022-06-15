# Backup Playbook

These playbooks will collect backups of all services and databases prior to a CDP Upgrade.  
You may have to edit some paths in the playbooks to point to your specific configuration, they should not be run blindly.

## Stop Cluster 
Stop the Cluster (Actions → Stop Cluster)

Stop Cloudera Management Services
## Shutdown Cloudera Manager Server and Agents
```sh
ansible-playbook rollback-playbook/stop_cluster.yml -i environments/env/hosts
```
> This will stop the cloudera-scm-server as well as hard stop the cloudera-scm-agent on all hosts in the cluster

## Collect Database Backups

```sh
ansible-playbook rollback-playbook/mysql_bkup.yml -i environments/env/hosts 
```
> This will backup all mysql databases on the specified database host

## Collect CDH Backups

```sh
ansible-playbook rollback-playbook/cdh_bkup.yml -i environments/env/hosts 
```
> This will backup all cdh services 

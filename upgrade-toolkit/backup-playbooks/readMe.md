# Backup Playbook

These playbooks will collect backups of all services and databases prior to a CDP Upgrade.
You may have to edit some paths in the playbooks to point to your specific configuration, they should *not be run blindly*

## Stop Cluster 
Stop the Cluster (Actions → Stop Cluster)

Stop Cloudera Management Services
## Shutdown Cloudera Manager Server and Agents
```sh
ansible-playbook rollback-playbook/stop_cluster.yml -i environments/env/hosts
```
> This will stop the cloudera-scm-server as well as hard stop the cloudera-scm-agent on all hosts in the cluster

## Collect Database Backups

If you are using **MySQL** database, follow the steps in the below section
#### MySQL database
```sh
ansible-playbook rollback-playbook/mysql_bkup.yml -i environments/env/hosts 
```
> This will backup all mysql databases on the specified database host



If you are using **PostgreSQL** database, follow the steps in the below section
#### PostgreSQL database

1.  Review and update the list of databases to backup in _vars.yml_
2.  Update hosts field in _pgsql_bkp.yml_ file to point to the ansible section that points to the PostgreSQL database host
3.  If you want to pull the database backups to your local server, set _fetch_local_ to true in vars.yml
```sh
ansible-playbook -uroot -k rollback-playbook/pgsql_bkup.yml -i <ansible hosts file generated using utilities/nodes.py>
```
> This will backup databases specified in vars.yml on the PostgreSQL database server

## Collect CDH Backups

```sh
ansible-playbook rollback-playbook/cdh_bkup.yml -i environments/env/hosts 
```
> This will backup all cdh services 

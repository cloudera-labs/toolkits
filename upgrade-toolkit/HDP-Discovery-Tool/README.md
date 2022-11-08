# mac-hdp-discovery-bundle-builder

## Overview

This HDP Discovery Tool is a lightweight automation package that can run against a HDP cluster and produce a "Discovery Bundle" that is useful for planning and scoping migrations to CDP. It uses ambari/cluster APIs to gather the following data:
 - Cluster specs & layout
 - Cluster configurations 
 - Data & table details 
 - Resource usage across components (via metrics)
 - Workload logs (in a format ready for WXM direct upload)

build the report in the excel format and uploads the workloads into the CDP workload manager.

## Prerequisites

In order to execute the discovery bundle tool following prerequisites have to be met:
- Deploy the project to one of the cluster nodes
- If the node does not have access first download the project to a temporary place where you execute the steps detailed below
- Ambari server, Ranger Admin UI, Hive Metastore database should be reachable from the node
- Credential for Ambari Server for API calls
- Hadoop clients (hdfs cli) needs to be installed on the node
- Kerberos libs (kinit) needs to be installed if the cluster is kerberos is enabled on cluster
- HDFS supergroup member principal is needed for kini
- Python >= 3.6.8 needs to be installed
- virtualenv needs to be installed
- Java needs to be installed for hive metastore extraction from jaydebeapi 

## Steps:

 ### Download the project:

To download the project dependencies internet access is needed.

If the node where you plan to execute the script has internet access, download the project directly.
If you plan to execute the script in an air-gaped environment, first download the project and its dependencies to a temporary node with internet access, than deploy them to the final destination.


Install Python 3.8 and virtual env if not available on cluster node(Tested with python 3.6.8 and 3.7.1 as well): 

```shell
yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel && 
cd /usr/src && 
wget https://www.python.org/ftp/python/3.8.1/Python-3.8.1.tgz && 
tar xzf Python-3.8.1.tgz && 
cd Python-3.8.1 && 
./configure --enable-optimizations && 
make altinstall && 
rm -f /usr/src/Python-3.8.1.tgz && 
python3.8 -V &&
cd &&
echo "Python installation successfully finished"

```
### Node with internet access

Download the project under /opt directory:

```
cd /opt
# Use git if the environment is not air gaped
yum -y install git
git clone <repo_url>
```

### Node without internet access

Login to a node with internet access, and download the project

```
cd /tmp
yum -y install git
git clone <repo_url>
cd /tmp/mac-cdh-discovery-bundle-builder/
```

**Important** same version of pythons should be used to resolve the dependencies on the temporary location.

Download the project dependencies, wheelhouse.tar.gz is createad as a result

```
python3.8 -m venv .venv
source .venv/bin/activate
chmod +x download_dependencies.sh
./download_dependencies.sh
```

Copy the project to the final destination

```commandline
rsync  -Paz --exclude={'.git','.venv'}  /tmp/mac-cdh-discovery-bundle-builder <target-node>:/opt
```

### On the target node

Go to the project directory:

```
cd /opt/mac-hdp-discovery-bundle-builder/
```

Create a new virtual environment inside the project directory:

```
python3.8 -m venv .venv
source .venv/bin/activate
```

Install the dependencies for the project:

- For environments with internet access:

```commandline
pip install --upgrade pip
pip install -r requirements.txt
```

- For environments without internet access use the prepacked dependencies:

```commandline
tar -zxf wheelhouse.tar.gz
 pip install -r wheelhouse/requirements.txt --no-index --find-links wheelhouse
```

Set the credentials in config.ini

Provide the path the JDBC driver for the Hive MetaStore. Usually it is located under **/usr/share/java/**

```commandline
vi /opt/mac-hdp-discovery-bundle-builder/mac-discovery-bundle-builder/conf/config.ini

[ambari_config]
ambari_server_host = 
ambari_server_port = 
ambari_user = 
ambari_pass = 
ambari_http_protocol = http
ambari_server_timeout = 30
output_dir = /tmp/output
[hive_config]
hive_metastore_type = mysql
hive_metastore_server = 
hive_metastore_server_port = 3306
hive_metastore_database_name = 
hive_metastore_database_user = 
hive_metastore_database_password = 
hive_metastore_database_driver_path = 
[ranger_config]
ranger_admin_user =
ranger_admin_pass =
ranger_ui_protocol = http
ranger_ui_server_name =
ranger_ui_port = 6080
```

In a kerberized environment you should kinit with principal who is member of HDFS supergroup:

```commandline
kinit -kt   <PATH_TO_HDFS_SUPERGROUP_KEYTAB> <HDFS_PRINCIPAL>
```

In a NON kerberized environment you should use a username who is member of HDFS supergroup:
```shell
export HADOOP_USER_NAME=hdfs
```


```
Usage: discovery_bundle_builder.py [options]

Options:
  -h, --help            show this help message and exit
  --module=<module>     all for building full disrocery bundle, cm_metrics for
                        CM metrics extraction, diagnostic_bundle for
                        diagnostic bundle extraction, hive_metastore for
                        collecting hive metastore info. Defaults to all
```
  
## Run the discovery bundle tool

```shell
chmod +x discovery_bundle_builder.sh
./discovery_bundle_builder.sh
```

To execute a selected module:
```shell
chmod +x discovery_bundle_builder.sh
./discovery_bundle_builder.sh --module hive_metastore
```

Available modules:
  
- ambari_api
  - Fetches service specific metrics from Ambari
  
- hive_metastore
  - Fetches information about the workload cluster
  
- extract_metrics
  - Fetches the metrics from the cluster

- mapreduce_extractor
  - Fetches all the workload of mapreduce by downloading the mr history logs from hdfs.
  
- spark_extractor
  - Fetched all the workload of spark by downloading the spark history logs from hdfs

- Tez_extractor
  - Fetched all the workload of tez by downloading the tez history logs from hdfs
  
- ranger_policy_extractor
  - Fetched all the policies from ranger admin rest API
  
- hdfs_report
  - collect all the file details from fsimage of namenode.
  
- **all**
  - default module, executes all the modules above.

## Configurable parameters:

```commandline
Options:
  -h, --help            show this help message and exit
  --module=<module>     Select a module to be executed. Defaults to all
  --output-dir=<output_dir>
                        Output of the discovery bundle.
```


# Discovery Bundle builder

## Overview

This Discovery Tool is a lighweight automation package that can run against a CDH or CDP cluster to produce a "Discovery Bundle" that is useful for CDP migration planning. It uses CM/cluster APIs to gather the following data:
 - Cluster specs & layout
 - Cluster configurations 
 - Data & table details 
 - Resource usage across components (via metrics)
 - Workload logs (in a format ready for WXM direct upload)
 
## Prerequisites
In order to execute the discovery bundle tool following prerequisites have to be met:
- Deploy the project to one of the cluster nodes
- If the node does not have access first download the project to a temporary place where you execute the steps detailed [below]()
- Cloudera Manager server, Sentry database, Hive Metastore database should be reachable from the node
- Credential for Cloudera Manager which is able to call CM API endpoints
- Hadoop clients (hdfs cli) needs to be installed on the node
- Kerberos libs (kinit) needs to be installed if the cluster is kerberos is enabled on cluster
- HDFS supergroup member principal is needed for kinit
- Python >= 3.6.8 and virtualenv needs to be installed

## Steps to run the project

### Download the project
To download the project dependencies internet access is needed. 
- If the node where you plan to execute the script has internet access, download the project directly. 
- If you plan to execute the script in an air-gaped environment, first download the project and its dependencies to a temporary node with internet access, than deploy them to the final destination.

Install Python 3.7 and virtual env if not available on cluster node. (Python 3.6.8 is also tested)
```shell
yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel && 
cd /usr/src && 
wget https://www.python.org/ftp/python/3.7.11/Python-3.7.11.tgz && 
tar xzf Python-3.7.11.tgz && 
cd Python-3.7.11 && 
./configure --enable-optimizations && 
make altinstall && 
rm -f /usr/src/Python-3.7.11.tgz && 
python3.7 -V &&
cd &&
echo "Python installation successfully finished" &&
python3.7 -m pip install --user virtualenv
```

### Node with internet access

Download the project to **/opt**
```shell
cd /opt
yum -y install git
git clone <repo_url>
```

### Node without internet access

Login to a node with internet access, and download the project
```shell
cd /tmp
yum -y install git
git clone <repo_url>
cd /tmp/mac-cdh-discovery-bundle-builder/
```

**Imporant** same version of pythons should be used to resolve the dependencies on the temporary location.

Download the project dependencies, **wheelhouse.tar.gz** is createad as a result
```shell
python3.7 -m venv .venv
source .venv/bin/activate
./download_dependencies.sh
```

Copy the project to the final destination
```shell
rsync  -Paz --exclude={'.git','.venv'}  /tmp/mac-cdh-discovery-bundle-builder <target-node>:/opt
```

### On the target node

Go to the project directory:
```shell
cd /opt/mac-cdh-discovery-bundle-builder/
```

Create a new virtual environment inside the project directory:
````shell
python3.7 -m venv .venv
source .venv/bin/activate
````

Install the dependencies for the project:
- For environments with internet access:
```shell
pip install -r requirements.txt
```

- For environments without internet access use the prepacked dependencies:
```shell
 tar -zxf wheelhouse.tar.gz
 pip install -r wheelhouse/requirements.txt --no-index --find-links wheelhouse
```

- Set the Cloudera Manager credentials in [config.ini](./mac-discovery-bundle-builder/config/config.ini). 
- Provide the path the JDBC driver for the HMS and Sentry databases. Usually it is located under **/usr/share/java/**
```shell
vi /opt/mac-cdh-discovery-bundle-builder/mac-discovery-bundle-builder/config/config.ini

#Edit the file
[credentials]
cm_user=<cm_admin_username>
cm_password=<cm_admin_password>
db_driver_path=<jdbc-connector-path>
```

In a kerberized environment you should kinit with principal who is member of HDFS supergroup:
```shell
kinit -kt <PATH_TO_HDFS_SUPERGROUP_KEYTAB> <HDFS_PRINCIPAL>
```

In a NON kerberized environment you should use a username who is member of HDFS supergroup:
```shell
export HADOOP_USER_NAME=hdfs
```

## Run the discovery bundle tool

Use the following command to execute the collection:

```shell
./discovery_bundle_builder.sh --cm-host https(s)://<cm-hostname>:<cm-port> --time-range=7 --output-dir /tmp/discovery_bundle
```

To execute a selected module:
```shell
./discovery_bundle_builder.sh --cm-host http(s)://<cm-hostname>:<cm-port> --time-range=7 --module cm_api --output-dir /tmp/discovery_bundle
```

Available modules:
- cm_metrics
  - Fetches service specific metrics from CM
- cm_api
  - Fetches information about the workload cluster
- diagnostic_bundle
  - Downloads the diagnostic bundle, and fetches hardware related information from it
- hdfs_report
  - Downloads the FS image, creates a report of the directories
- hive_metastore
  - Communicates with the hive metastore, fetches the table information
- sentry_extractor
  - Collects information about the sentry policies
- mapreduce_extractor
  - Fetches the mapreduce job history logs from hdfs. if the cluster is secured you must kinit with a hdfs superusergroup member (or a user with permission to access the mapreduce job history logs in HDFS) before executing the script. HIVE queries are collected as part of the mapreduce jobs. Results are collected in a WXM compatible format.
- spark_extractor
  - Fetches the spark job history logs from hdfs. if the cluster is secured you must kinit with a hdfs superusergroup member (or a user with permission to access the spark event log directory in HDFS) before executing the script. Results are collected in a WXM compatible format.
- impala_profiles
  - diagnostic_bundle module must be executed before it. The module collects the impala profiles from the diag bundles in a WXM compatible format
- **all**
  - default module, executes all the modules above.


### Configurable parameters:
```shell
Options:
  -h, --help            show this help message and exit
  --module=<module>     Select a module to be executed. Defaults to all
  --cm-host=<cm_host>   Cloudera Manager host.
  --output-dir=<output_dir>
                        Output of the discovery bundle. Defaults to
                        /tmp/discovery_bundle
  --time-range=<time_range_in_days>
                        Time range in days to collect metrics. Defaults to 45
                        days.
  --disable-redaction   Option to disable redaction. If option not set, it
                        defaults to redacting sensitive values.
```

### About redaction
Redaction is a process that obscures data. It helps organizations to comply with government and industry regulations, such as PCI (Payment Card Industry) and HIPAA, by making personally identifiable information (PII) unreadable except to those whose jobs require such access. With regards to Cloudera Manager API, the exported configuration may contain passwords and other sensitive information.  Cloudera clusters implement some redaction features by default, while some features are configurable and require administrators to specifically enable them. For more information, see [How to Enable Sensitive Data Redaction](https://docs.cloudera.com/documentation/enterprise/latest/topics/sg_redaction.html).

**By default, the Discovery Bundle toolkit enables redaction**, even if your cluster configuration has not been [set up in this way](https://docs.cloudera.com/documentation/enterprise/latest/topics/cm_intro_api.html#concept_dnn_cr5_mr__section_ogy_zrd_gw). This guarantess that API calls to Cloudera Manager for configuration data do not include the sensitive information.

If you prefer to switch off redaction, you can set the `--disable-redaction` parameter.

# Push Configurations to CM via API
Utilize this script and json objects to push CM Configurations for the new services added after the CDP Upgrade as well as configurations for existing key services. Sample JSON templates have been provided for the following services:
* Ranger
* Ranger RMS
* Ranger KMS KTS
* Atlas
* Hive
* Hive on Tez
* HDFS
* Kafka
* CDP Infra SOLR

## Requirements
In order to run this application install python 3 and install the below packages

```bash
pip install cm-client
import json
import sys
import cm_client
from cm_client.rest import ApiException
import logging
```

Configure your cluster name, user, pass, and cloudera manager URl

```python
cm_user = 'admin'
cm_pass = 'admin'
cm_api_version = 'v41'
cm_host_name = 'cm_url'
cluster_name = 'cluster_name'
```

## Example Execution

Execute the script and pass in a json file as the first parameter.
> Note: The json objects must be modified and adapted to the target environment prior to execution.

```bash
python apply_properties.py example.json
```

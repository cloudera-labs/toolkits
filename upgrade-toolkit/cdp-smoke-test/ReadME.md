# Smoke Test

This script should be run after the CDP Upgrade to ensure functionality of all services on the newly upgraded CDP Cluster

### This script will generate an output displaying the status of each service test

## Requirements:
* CM user and password must have Read privileges on Cloudera Manager
* python3 must be installed
* Run Script from Hive Gateway
* Ensure that a valid keytab is present before execution

```shell
kinit -kt example.keytab hive/$HOSTNAME
klist
```

## Import the following packages

```sh
import cm_client
from cm_client.rest import ApiException
import os
import requests
```



## Modify the below lines for the Environment

```shell
    # Configure HTTPS authentication
    cm_client.configuration.username = "username"
    cm_client.configuration.password = "password"
    cm_host = ''
    cm_client.configuration.verify_ssl = False
    api_host = 'https://' + cm_host
    port = '7183'
    api_version = 'v31'
```

## Directions to Execute

```shell
python3 smoke_test.py
```
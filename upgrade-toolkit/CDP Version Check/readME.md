# CDP Version Checker

This script should be run prior to the CDP Upgrade to determine if the versions of critical components present in the cluster will pose any risks to the upgrade. The script will compare versions installed against the CDP Support matrix that can be found at: https://supportmatrix.cloudera.com/

### This script will generate an excel file with the following sheets:
> 1. Status Summary
>2. Incompatible Versions Error Log

### The Status Summary sheet will display the following information on the environment:
>1. Is the Version of the backend database supported?
>2. Is Kerberos Enabled?
>3. Do all nodes run the supported OS version of python?
>4. Do all nodes have enough space in the parcel directory to accommodate the new CDP parcel?
> 5. Do all nodes run a supported version of Linux?
>6. Do all nodes run a supported version of Java?
>7. What is the Cloudera Manager Database Type Used?
>8. Is the cluster TLS Secured?

#### The Incompatible Versions Error Log will gather the following information for all hosts that are running incompatible versions:
>1. Hostname
>2. Error on host


## Requirements:
>1. CM user and password must have Read privileges on Cloudera Manager
>2. The script must be run from a node that has password-less ssh acess to all hosts in the cluster
>3. python3 must be installed
> 4. Import the following packages

```sh
import cm_client
import subprocess
import cm_client
import requests
import json
import xlsxwriter
```

## Directions to Execute

### Modify the below lines for the Environment to Analyze

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

```shell
python3 version_check.py
```
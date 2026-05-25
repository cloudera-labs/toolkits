# Inventory CSV Generator

### This script will generate an excel file with the following sheets: 
> 1. Host Information
> 2. Cloudera Version Information

### A sheet will be created for every cluster that is managed within the CM env specified that contains:
> 1. Service Type
> 2. Service Name


### The Host Information sheet will gather the following information on all hosts in a given environment:
> 1. Hostname
> 2. Roles on the Host
> 3. Number of roles present on host
> 4. Environment the host belongs to
> 5. Cluster the host belongs to
> 6. Linux version present on host
> 7. Model Number of the host
> 8. Number of cores
> 9. Total Memory
> 10. Java Version
> 11. System Python Version

#### The Cloudera Version Information Sheet will gather the following information:
> 1. CM Version
> 2. CDH Version (for each cluster)
> 3. Backend DB Type


## Requirements: 
> 1. CM user and password must have Read privileges on Cloudera Manager
> 2. The script must be run from a node that has password-less ssh acess to all hosts in the cluster
> 3. python3 must be installed
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
python3 hostroles.py
```
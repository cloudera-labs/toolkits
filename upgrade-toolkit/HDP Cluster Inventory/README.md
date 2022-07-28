# Inventory CSV Generator

### This script will generate an excel file with the following sheets: 
> 1. Host Information
> 2. HDP_Version_Information


### The Host Information sheet will gather the following information on all hosts in a given environment:
> 1. Hostname
> 2. Roles on the Host
> 3. Number of roles present on host
> 4. Environment the host belongs to
> 5. Cluster the host belongs to
> 6. Linux version present on host
> 7. Model Number of the host
> 8. Number of cores
> 9. Java Version
> 10. System Python Version

#### The Cloudera Version Information Sheet will gather the following information:
> 1. HDP Version
> 2. Cluster Name
> 3. Backend DB Type


## Requirements: 
> 1. AMBARI user and password must have Read privileges on AMBARI API
> 2. The script must be run from a node that has password-less ssh acess to all hosts in the cluster
> 3. python3 must be installed
> 4. Import the following packages
> 5. Ambari_domain is inout to python script



## Directions to Execute

### Modify the below lines for the Environment to Analyze

```shell
    # Configure HTTPS authentication
    AMBARI_USER_ID = "username"
    AMBARI_USER_PW = "password"
    AMBARI_DOMAIN =  "Comes as input to python"
    AMBARI_PORT = '8443'
    api_version = 'v1'
```

```shell
python3 hdp_hostroles.py $AMBARI_DOMAIN
example of ambari_domain
ambari_domain = '172.27.54.3' or ambari_domain='ccycloud-1.tkreutzer2.root.hwx.site'

```

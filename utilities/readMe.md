# Utility Scripts
 

## Inventory Script
This python script will generate an ansible hostfile given Cloudera Manager Hostname, User, and Password

### Limitations of the Script
All Cloudera Management Services Hosts as well as backend database host need to be manually inputted into the hostfile

Prior to running the script, some python libraries will need to be installed
```shell
pip install cm-client
pip install requests
```

Generate a base64 password file
```shell
base64 pass.txt > /tmp/encoded.txt
```

Replace the below lines in ``nodes.py`` with the correct ```username``` and ```lab``` environment name and path to 
encoded password file 
```shell
f = open('/tmp/encoded.txt', "r")
passwd = base64.b64decode(f.read()).decode("utf-8").strip()
hosts(env="lab", username="admin", pwd=passwd)
```

Modify the below line in ``nodes.py`` environments array with correct cloudera manager URLs 
```shell
environments = {'lab': 'lab-cm', 'dev': 'dev-cm', 'pre-prod': 'pre-prod-cm', 'prod': 'cm'}
```

Modify the below line in ``nodes.py`` cmservers array with correct cloudera manager (load balanced) URLs  
```shell
cmservers = {'lab': 'lab_cm_url', 'dev': 'dev_cm_url', 'pre-prod': 'pre_prod_cm_url', 'prod': 'prod_cm_url'}
```

To Run the Script:
```shell
python3 nodes.py 
```

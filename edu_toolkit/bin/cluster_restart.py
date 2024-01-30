#!/usr/bin/python

import ConfigParser
from cm_api.api_client import ApiResource
from cm_api.endpoints.services import ApiService


# Setup to read from config file
CONFIG = ConfigParser.ConfigParser()
CONFIG.read("/home/training/config/cluster.ini")

# Assign environment vars
CM_HOST = CONFIG.get("CM", "cm.host")

# Assign account info
ADMIN_USER = CONFIG.get("CM", "admin.name")
ADMIN_PASSWORD = CONFIG.get("CM", "admin.password")

# Assign Clustername
CLUSTER_NAME = CONFIG.get("CM", "cluster.name")
CDH_VERSION = "CDH6"

# Main Function
def main():
    API = ApiResource(CM_HOST, version=6, username=ADMIN_USER, password=ADMIN_PASSWORD)
    print "Connect to CM host on " + CM_HOST

    CLUSTER = API.get_cluster(CLUSTER_NAME)

    print "About to restart cluster."
    CLUSTER.restart().wait()
    print "Restart complete."

if __name__ == "__main__":
    main()


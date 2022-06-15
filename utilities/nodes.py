# Copyright 2022 Cloudera, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import cm_client
from cm_client.rest import ApiException
import sys
import requests
import base64
import getpass

# Configure HTTPS authentication
cm_client.configuration.username = 'username'
cm_client.configuration.password = 'pwd'
cm_client.configuration.verify_ssl = False
cm_host = 'cm_server_url'
# Construct base URL for API
api_host = 'https://' + cm_host
port = '7183'
api_version = 'v22'
api_url = api_host + ':' + port + '/api/' + api_version
api_client = cm_client.ApiClient(api_url)

# Get host API
hosts_api_instance = cm_client.HostsResourceApi(api_client)
cm_hosts = hosts_api_instance.read_hosts(view='FULL')

# All all services if missing
svcs = {'hdfs': {'namenodes': 'NAMENODE', 'datanodes': 'DATANODE', 'journalnodes': 'JOURNAL',
                 'nfs_gateway': 'NFSGATEWAY', 'hdfs_gateways': '-GATEWAY', 'failover_controllers': 'FAIL',
                 'httpfs': 'HTTPFS', 'balancer': 'BALANCER'},
        'hive': {'hive_metastore_server': 'METASTORE', 'hiveserver2': 'SERVER2', 'webhcat_server': 'WEBHCAT',
                 'hive_gateway': 'GATEWAY'},
        'hue': {'hue_load_balancer': 'LOAD_BALANCER', 'hue_server': 'SERVER', 'kerberos_ticket_renewer': 'KT'},
        'impala': {'catalog_server': 'CATALOGSERVER', 'state_store': 'STATESTORE', 'daemons': 'IMPALAD'},
        'oozie': {'oozie_server': 'SERVER'},
        'sentry': {'sentry_server': 'SERVER'},
        'solr': {'solr_server': 'SERVER', 'solr_gateway': 'GATEWAY'},
        'spark': {'spark_gateway': '-GATEWAY'},
        'yarn': {'job_history_server': 'JOB', 'resource_manager': 'RESOURCE', 'yarn_gateway': 'yarn-GATEWAY',
                 'node_manager': 'NODE'},
        'zookeeper': {'zookeeper_server': 'SERVER'}}

try:
    if "-v" in sys.argv[4]:
        # Get Clusters
        cluster_api_instance = cm_client.ClustersResourceApi(api_client)
        api_response = cluster_api_instance.read_clusters(view='SUMMARY')
        clusters = {}
        for cluster in api_response.items:
            clusters[cluster.name] = cluster.display_name
        for outer_index in svcs:
            for inner_index in svcs[outer_index]:
                print("\n[%s]" % inner_index)
                for host_item in cm_hosts.items:
                    for role_item in host_item.role_refs:
                        if outer_index == 'yarn':
                            if svcs[outer_index][
                                inner_index] in role_item.role_name and 'yarn' in role_item.role_name and 'spark' not in role_item.role_name:
                                print(clusters[role_item.cluster_name], "-", host_item.hostname)
                        else:
                            if svcs[outer_index][
                                inner_index] in role_item.role_name and outer_index in role_item.role_name:
                                print(clusters[role_item.cluster_name], "-", host_item.hostname)

except:
    # IndexError
    for outer_index in svcs:
        for inner_index in svcs[outer_index]:
            print("\n[%s]" % inner_index)
            for host_item in cm_hosts.items:
                for role_item in host_item.role_refs:
                    if outer_index == 'yarn':
                        if svcs[outer_index][
                            inner_index] in role_item.role_name and 'yarn' in role_item.role_name and 'spark' not in role_item.role_name:
                            print(host_item.hostname)
                    else:
                        if svcs[outer_index][inner_index] in role_item.role_name and outer_index in role_item.role_name:
                            print(host_item.hostname)

print("\n[cm_server]")
print(cm_host)

print("\n[ansible_host]")
print(cm_host)

print("\n[all_hosts]")
for host_instance in cm_hosts.items:
    print(host_instance.hostname)

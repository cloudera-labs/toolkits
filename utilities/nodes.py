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


def hosts(env, username, pwd):
    # Configure HTTPS authentication
    cm_client.configuration.username = username
    cm_client.configuration.password = pwd
    cm_client.configuration.verify_ssl = False

    environments = {'lab': 'lab-cm', 'dev': 'dev-cm', 'pre-prod': 'pre-prod-cm', 'prod': 'cm'}
    # Construct base URL for API
    api_host = 'https://' + environments[env]
    port = '7183'
    api_version = 'v19'
    api_url = api_host + ':' + port + '/api/' + api_version  # https://<environment>:7183/api/v19
    api_client = cm_client.ApiClient(api_url)

    # Get host API
    hosts_api_instance = cm_client.HostsResourceApi(api_client)
    cm_hosts = hosts_api_instance.read_hosts(view='FULL')

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
            for i in svcs:
                for j in svcs[i]:
                    print("\n[%s]" % j)
                    for k in cm_hosts.items:
                        for l in k.role_refs:
                            if i == 'yarn':
                                if svcs[i][j] in l.role_name and 'yarn' in l.role_name and 'spark' not in l.role_name:
                                    print(clusters[l.cluster_name], "-", k.hostname)
                            else:
                                if svcs[i][j] in l.role_name and i in l.role_name:
                                    print(clusters[l.cluster_name], "-", k.hostname)

    except:
        # IndexError
        for i in svcs:
            for j in svcs[i]:
                print("\n[%s]" % j)
                for k in cm_hosts.items:
                    for l in k.role_refs:
                        if i == 'yarn':
                            if svcs[i][j] in l.role_name and 'yarn' in l.role_name and 'spark' not in l.role_name:
                                print(k.hostname)
                        else:
                            if svcs[i][j] in l.role_name and i in l.role_name:
                                print(k.hostname)
    cmservers = {'lab': 'lab_cm_url', 'dev': 'dev_cm_url', 'pre-prod': 'pre_prod_cm_url', 'prod': 'prod_cm_url'}
    print("\n[cm_server]")
    print(cmservers[env])

    print("\n[ansible_host]")
    print(cmservers[env])

    print("\n[all_hosts]")
    for m in cm_hosts.items:
        print(m.hostname)


f = open('/tmp/encoded.txt', "r")
passwd = base64.b64decode(f.read()).decode("utf-8").strip()
hosts(env="lab", username="admin", pwd=passwd)



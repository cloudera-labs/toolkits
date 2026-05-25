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
import os
import requests

# Change below path if not using AUTO TLS
cert_path = '/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem'

# Configure HTTPS authentication
cm_client.configuration.username = "cm_usr"
cm_client.configuration.password = "cm_pwd"
cm_host = 'cm_host_url'
cm_client.configuration.verify_ssl = False
api_host = 'https://' + cm_host
port = '7183'
api_version = 'v31'
requests.packages.urllib3.disable_warnings()

# Construct Base URL for API
api_url = api_host + ':' + port + '/api/' + api_version
api_client = cm_client.ApiClient(api_url)
cluster_resource_api = cm_client.ClustersResourceApi(api_client)
service_resource_api = cm_client.ServicesResourceApi(api_client)
api_instance = cm_client.ClouderaManagerResourceApi(api_client)
roles_resource_api = cm_client.RolesResourceApi(api_client)
host_api = cm_client.HostsResourceApi(api_client)
role_cfg_resource_api = cm_client.RoleConfigGroupsResourceApi(api_client)

# Bulk var declare
IMPALA_HOST = ""
HUE_HOST = ""
SOLR_HOST = ""
HIVE_HOST = ""
KUDU_HOST = ""
OOZIE_HOST = ""
LIVY_HOST = ""
ZEPPELIN_HOST = ""
SCHEMAREGISTRY_HOST = ""
STREAMS_MESSAGING_MANAGER_HOST = ""
STREAMS_REPLICATION_MANAGER_HOST = ""
FLINK_HOST = ""
SQL_STREAM_BUILDER_HOST = ""
RANGER_HOST = ""
KNOX_HOST = ""
HBASE_HOST = ""
HDFS_HOST = ""
ATLAS_HOST = ""
SPARK_HOST = ""
YARN_HOST = ""
# Yarn Jar path
yarn_jar = "/opt/cloudera/parcels/CDH/jars/hadoop-mapreduce-examples*.jar"


def urls_for_test():
    return {
        "ATLAS": [{"ATLAS_SERVER": "https://" + ATLAS_HOST + ":31443"}],
        "IMPALA": [{"STATESTORE": "https://" + IMPALA_HOST + ":25010"}],
        "IMPALA": [{"CATALOGSERVER": "https://" + IMPALA_HOST + ":25020"}],
        "FLINK": [{"FLINK_HISTORY_SERVER": "https://" + FLINK_HOST + ":18211"}],
        "LIVY": [{"LIVY_SERVER": "https://" + LIVY_HOST + ":8998"}],
        "OOZIE": [{"OOZIE_SERVER": "https://" + OOZIE_HOST + ":11443/oozie"}],
        "HBASE": [{"MASTER": "https://" + HBASE_HOST + ":22002/master-status"}],
        "HDFS": [{"NAMENODE": "https://" + HDFS_HOST + ":20102/dfshealth.html#tab-overview"}],
        "SPARK": [{"SPARK_YARN_HISTORY_SERVER": "http://" + SPARK_HOST + ":18089"},
                  {"SPARK_YARN_HISTORY_SERVER": "http://" + SPARK_HOST + ":18088"},
                  {"SPARK_YARN_HISTORY_SERVER": "https://" + SPARK_HOST + ":18089"},
                  {"SPARK_YARN_HISTORY_SERVER": "https://" + SPARK_HOST + ":18088"}],
        "YARN": [{"JOBHISTORY": "https://" + YARN_HOST + ":19890"},
                 {"RESOURCEMANAGER": "https://" + YARN_HOST + ":8090"}],
        "SCHEMAREGISTRY": [{"SCHEMA_REGISTRY_SERVER": "https://" + SCHEMAREGISTRY_HOST + ":7790"}],
        "SQL_STREAM_BUILDER": [{"STREAMING_SQL_CONSOLE": "http://" + SQL_STREAM_BUILDER_HOST + ":18111"}],
        "KUDU": [{"KUDU_MASTER": "https://" + KUDU_HOST + ":8051"}],
        "STREAMS_MESSAGING_MANAGER": [
            {"STREAMS_MESSAGING_MANAGER_SERVER": "http://" + STREAMS_MESSAGING_MANAGER_HOST + ":9991"}],
        "STREAMS_REPLICATION_MANAGER": [
            {"STREAMS_REPLICATION_MANAGER_SERVICE": "http://" + STREAMS_REPLICATION_MANAGER_HOST + ":7790"}],
        "HUE": [{"HUE_SERVER": "https://" + HUE_HOST + ":8888"}],
        "SOLR": [{"SOLR_SERVER": "https://" + SOLR_HOST + ":8995"}],
        "RANGER": [{"RANGER_ADMIN": "https://" + RANGER_HOST + ":6182"}],
        "KNOX": [{"KNOX_GATEWAY": "https://" + KNOX_HOST + ":8443/gateway/knoxsso/knoxauth/login.html"}]
    }


def test_items():
    return {
        "hdfs": [{
            "hdfs_create": "hdfs dfs -mkdir /tmp/smoke_test",
            "hdfs_write": "hdfs dfs -touchz /tmp/smoke_test/test.txt",
            "hdfs_delete": "hdfs dfs -rm -r /tmp/smoke_test/"}],
        "hive": [{"hive_show": "beeline -e 'show tables;'",
                  "hive_create_db": "beeline -e 'create database if not exists sanity_test;'",
                  "hive_use": "beeline -e 'use sanity_test;'",
                  "hive_internal_table_creation": "beeline -e 'create table if not exists sanity_test.insertion (num int, name STRING, state STRING);'",
                  "hive_external_table_creation": "beeline -e 'create external table if not exists sanity_test.tester (num int, name STRING)\
                                                            partitioned by (state STRING)\
                                                            stored as parquet;\
                                                            insert into table sanity_test.insertion (num, name, state) values (1, \"abc\", \"NY\"), (2, \"def\", \"CA\");'",
                  "hive_select": "beeline -e 'select * from sanity_test.insertion;'",
                  "hive_insert": "beeline -e 'insert into table sanity_test.tester partition(state=\"NY\") select num, name from sanity_test.insertion where state=\"NY\" ;'",
                  "hive_insert": "beeline -e 'insert into table sanity_test.tester partition(state=\"CA\") select num, name from sanity_test.insertion where state=\"CA\" ;'",
                  "hive_select": "beeline -e 'select * from sanity_test.tester;'",
                  "hive_drop_table": "beeline -e 'drop table sanity_test.insertion;'",
                  "hive_drop_table": "beeline -e 'drop table sanity_test.tester;'", }],
        "yarn": [{"yarn_job": "hadoop jar " + yarn_jar + " pi 16 100"}],
        "spark_on_yarn": [{"spark_submit": "spark-submit --class org.apache.spark.examples.SparkPi \
                                                            --master yarn-client \
                                                            --num-executors 1 \
                                                            --driver-memory 512m \
                                                            --executor-memory 512m \
                                                            --executor-cores 1 \
                                                            /opt/cloudera/parcels/CDH-*/jars/spark-examples_*.jar"}],
        "hbase": [{
            "hbase_list": "echo \"list\"| hbase shell -n"}],
        "impala": [{
            "impala_drop": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'drop database if exists sanity;'",
            "impala_show_db": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'show databases;'",
            "impala_create_db": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'create database if not exists sanity_test;'",
            "impala_use": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'use sanity_test;'",
            "impala_create_external": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'create external table if not exists sanity_test.tester (num int, name varchar(5)) partitioned by (state varchar(2)) stored as parquet;'",
            "impala_create_internal": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'create table if not exists sanity_test.tester_dummy (num int, name varchar(5), state varchar(2));'",
            "impala_insert": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'insert into table sanity_test.tester_dummy values (10, CAST(\"rty\" as VARCHAR(5)),CAST(\"CA\" as varchar(2))), (15, CAST(\"asd\" as varchar(5)),CAST(\"NY\" as varchar(2)));'",
            "impala_select": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'select * from sanity_test.tester;'",
            "impala_select": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'select * from sanity_test.tester_dummy;'",
            "impala_drop_tb": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'drop table sanity_test.tester;'",
            "impala_drop_tb": "impala-shell -i " + impala_daemon + " -k --ssl --ca_cert=" + cert_path + " -q 'drop table sanity_test.tester_dummy;'"}]
    }


def get_ret_code(cmd):
    print(cmd)
    retcode = os.system(cmd + " &> /dev/null")
    if retcode == 0:
        result = "Pass"
    else:
        result = "Fail"
    return result


def execute(srvc_list, test_dict):
    for i in srvc_list:
        if i['h'] != 'GOOD':
            print('The status of ' + i['s'] + ' is NOT Healthy, thus sanity test can not be performed')
        else:
            for service, values1 in test_dict.items():
                if i['s'].lower() == service.lower():
                    print('Performing test on ' + i['s'].lower())
                    for role in values1:
                        for key, values in role.items():
                            result = get_ret_code(values)
                            print(key + ": " + result)
                    print("")


def get_clusters():
    try:
        return cluster_resource_api.read_clusters(cluster_type='base', view='summary')
    except ApiException as e:
        print("Exception when calling ClustersResourceApi->read_clusters: %s\n" % e)
        raise


def get_services(cluster_name):
    try:
        return service_resource_api.read_services(cluster_name=cluster_name, view='summary')
    except ApiException as e:
        print("Exception when calling ServicesResourceApi->read_services: %s\n" % e)
        raise


def get_role_config_groups(cluster_name, service_name):
    try:
        return role_cfg_resource_api.read_role_config_groups(cluster_name, service_name)
    except ApiException as e:
        print("Exception when calling RoleConfigGroupsResourceApi->read_role_config_groups: %s\n" % e)
        raise


def get_roles(cluster_name, service_name):
    try:
        return roles_resource_api.read_roles(cluster_name=cluster_name, service_name=service_name, filter='',
                                             view='summary')
    except ApiException as e:
        print("Exception when calling RolesResourceApi->read_roles: %s\n" % e)
        raise


def get_service_list(clstr_name):
    for cluster in clstr_name.items:
        srvc_list = []
        services = get_services(cluster.name)
        for service_info in services.items:
            srvc_list.append({'s': service_info.type, 'h': service_info.health_summary})
        return srvc_list


def get_hosts_by_role_type(clusters, service_type, role_type):
    for cluster in clusters.items:
        hosts_list = []
        services = get_services(cluster.name)
        for service_info in services.items:
            if service_info.type == service_type:
                roles = get_roles(cluster.name, service_info.name)
                service_health = service_info.health_summary
                for role in roles.items:
                    if role.type == role_type:
                        host_id = role.host_ref.host_id
                        for hosts in host_api.read_hosts().items:
                            if hosts.host_id == host_id:
                                hosts_list.append(hosts.hostname)
                                return hosts_list


def url_test(service_name, url):
    try:
        response = requests.request("GET", url, verify=False)
        print(response.status_code)
        if (response.status_code == 200 or response.status_code == 401):
            print(service_name.lower(), "_ui_accessible: Pass")
            print(" ")
        else:
            print("Unexpected response code: " + response.status_code)
    except Exception as e:
        print(service_name.lower(), "_ui_accessible: Fail")
        print("URL " + url + " not accessible")
        print(" ")


def test_ui(srvc_list, test_dict):
    print('-------------------------------------------------------------------------------------')
    print("---- TESTING UI's -------------------------------------------------------------------")
    print('-------------------------------------------------------------------------------------')
    for i in srvc_list:
        if i['h'] != 'GOOD':
            print('The status of ' + i['s'].lower() + ' is NOT Healthy, thus sanity test can not be performed')
        else:
            for service, values1 in test_dict.items():
                if i['s'].lower() == service.lower():
                    print('Performing test on ' + i['s'].lower())
                    for role in values1:
                        for key, values in role.items():
                            result = url_test(i['s'], values)
        print('-------------------------------------------------------------------------------------')


def check_krb_ticket():
    print("Checking KRB ticket")
    krb_test = get_ret_code("klist -s")
    print("krb_test: " + krb_test)
    print("")
    return krb_test


def update_urls(clstr, url_dict):
    blank = {}
    for service, values in url_dict.items():
        role = str(list(values[0]))[2:-2]
        host_var = service + "_HOST"
        blank[host_var] = str(get_hosts_by_role_type(clstr, service, role))[2:-2]
    return blank


if __name__ == '__main__':
    krb_result = check_krb_ticket()
    if krb_result == "Fail":
        print("No Valid KRB ticket present. Please generate a new ticket and proceed for testing \n")
    else:
        clusters = get_clusters()
        service_list = get_service_list(clusters)
        impala_daemon = get_hosts_by_role_type(clusters, 'IMPALA', 'IMPALAD')[0]

        # Test execution
        exec_dict = test_items()
        execute(service_list, exec_dict)

        # UI URL test
        url_dict = urls_for_test()
        u1 = update_urls(clusters, url_dict)
        for k, v in u1.items():
            exec(k + '=v')
        updated_urls = urls_for_test()
        test_ui(service_list, updated_urls)

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

import json
import os
import cm_client
import requests
import subprocess
import re
import xlsxwriter
from cm_client.rest import ApiException

requests.packages.urllib3.disable_warnings()


def version_check():
    # Configure HTTPS authentication
    cm_client.configuration.username = 'admin'
    cm_client.configuration.password = 'admin'
    cm_client.configuration.verify_ssl = False
    configuration = cm_client.Configuration()
    cm_host = 'cm_url'

    # Setup Workbook
    workbook = xlsxwriter.Workbook('Version_Check.xlsx')
    worksheet1 = workbook.add_worksheet('Status Summary')
    worksheet2 = workbook.add_worksheet('Incompatible Versions Error Log')
    worksheet3 = workbook.add_worksheet('TLS Service Level Info')
    worksheet4 = workbook.add_worksheet('Kerberos Information')
    cell_format = workbook.add_format({'bold': True, 'italic': False, "center_across": True, 'font_size': 13})
    text_format = workbook.add_format({'text_wrap': True})
    worksheet2.write("A1", "Hostname", cell_format)
    worksheet2.write('B1', "Error on Host", cell_format)
    worksheet3.write("A1", "Name of Service", cell_format)
    worksheet3.write("B1", "SSL Parameter Name", cell_format)
    worksheet3.write("C1", "SSL Enabled?", cell_format)
    worksheet4.write("A1", "Name of Service", cell_format)
    worksheet4.write("B1", "Kerberos Parameter Name", cell_format)
    worksheet4.write("C1", "Kerberos Parameter Value", cell_format)

    # Initiate workbook indices
    index_counter = 1
    tls_counter = 1
    kerberos_counter = 1

    # Construct base URL for API
    api_host = 'https://' + cm_host
    port = '7183'
    api_version = 'v41'
    api_url = api_host + ':' + port + '/api/' + api_version
    api_client = cm_client.ApiClient(api_url)

    # Get Host API
    hosts_api_instance = cm_client.HostsResourceApi(api_client)
    hosts = hosts_api_instance.read_hosts(view='FULL')
    api_instance = cm_client.RoleConfigGroupsResourceApi(api_client)

    # Get Service API
    services_api_instance = cm_client.ServicesResourceApi(api_client)
    role_config_groups = cm_client.RoleConfigGroupsResourceApi(api_client)

    # Define ECS Hosts
    ecs_hosts = ["ecs-1.company.com",
                 "ecs-2.company.com",
                 "ecs-3.company.com",
                 "ecs-4.company.com",
                 "ecs-5.company.com"]

    # Define Postgres ECS DB Host
    postgres_host = "ecs-db-host.company.com"


    # Define Hue Role Assignments
    svcs = {'hue': {'hue_load_balancer': 'LOAD_BALANCER', 'hue_server': 'SERVER', 'kerberos_ticket_renewer': 'KT'}}

    # Get DB Type
    r = requests.get('{0}/cm/scmDbInfo'.format(api_url), verify=False,
                     auth=(cm_client.configuration.username, cm_client.configuration.password))
    first_pair = next(iter((json.loads(r.text).items())))
    worksheet1.write('A7', str(first_pair[0]), cell_format)
    worksheet1.write('B7', str(first_pair[1]))

    # Set up Cluster API
    cluster_api_instance = cm_client.ClustersResourceApi(api_client)
    api_response = cluster_api_instance.read_clusters(view='SUMMARY')
    clusters = {}

    # Get DB Host & check compatibility
    db_host = subprocess.getoutput(
        "ssh {0} 'cat /etc/cloudera-scm-server/db.properties |egrep host | cut -c 26-'".format(cm_host))
    p = '(?P<host>[^:/ ]+).?(?P<port>[0-9]*).*'
    m = re.search(p, db_host)
    db_host = m.group('host')
    db_version_result_aggregate = []

    # Check if DB Type is PostgreSQL
    if first_pair[1] == "POSTGRESQL":
        db_version = subprocess.getoutput("ssh {0} 'postgres --version'".format(db_host))
        head, sep, tail = db_version.partition('.')
        temp = head
        head, sep, tail = temp.partition('(PostgreSQL) ')
        db_version = tail
        supported_postgres_versions = ["10", "11", "12", "14"]
        postgres_result = any(db_version in string for string in supported_postgres_versions)

        # Check if Version of PostgreSQL is Compatible
        if not postgres_result:
            worksheet2.write(index_counter, 0, "The postgres version installed is not supported", cell_format)
            worksheet2.write(index_counter, 1, 'Yes')
            index_counter = index_counter + 1
        else:
            db_version_result_aggregate.append(str(postgres_result))

        bool_result = any("False" in string for string in db_version_result_aggregate)
        # Write Summary Result for DB Version to Worksheet
        if not bool_result:
            worksheet1.write('A1', 'Is the version of postgres running supported?', cell_format)
            worksheet1.write('B1', 'Yes')
        else:
            worksheet1.write('A1', 'Is the version of postgres running supported?', cell_format)
            worksheet1.write('B1', 'No')

    # Check if DB Type is MySQL or MariaDB
    elif first_pair[1] == "MYSQL" or first_pair[1] == "MARIADB":
        db_version = subprocess.getoutput("ssh {0} 'mysql -V'".format(db_host))
        head, sep, tail = db_version.partition('Distrib ')
        temp = tail
        head, sep, tail = temp.partition('-MariaDB')
        temp2 = head
        x = temp2.split('.')
        db_version = x[0] + '.' + x[1]
        supported_mysql_versions = ["8.0", "5.7", "5.6"]
        supported_mariaDB_versions = ["10.5", "10.4", "10.3", "10.2"]
        print(db_version)
        db_result = any(db_version in string for string in supported_mysql_versions) or any(
            db_version in string for string in supported_mariaDB_versions)

        # Check if Version of MariaDB / MySQL Installed is Supported
        if not db_result:
            worksheet1.write('A1', "Is the MariaDb/MySQL db version installed supported?", cell_format)
            worksheet1.write('B1', 'No')
        else:
            db_version_result_aggregate.append(str(db_result))

        # Write Result to Worksheet
        bool_result = any("False" in string for string in db_version_result_aggregate)
        if not bool_result:
            worksheet1.write('A2', "The version of {0} installed is supported".format(first_pair[1]), cell_format)
            worksheet1.write('B2', 'Yes')
        else:
            worksheet1.write('A2', "The version of {0} installed is supported".format(first_pair[1]), cell_format)
            worksheet1.write('B2', 'No')

    # Check if Cluster is TLS Encrypted & Kerberized
    for cluster in api_response.items:
        clusters[cluster.name] = cluster.display_name
        r2 = requests.get('{}/clusters/{}/isTlsEnabled'.format(api_url, cluster.display_name), verify=False,
                          auth=(cm_client.configuration.username, cm_client.configuration.password))

        # Write TLS Result to worksheet
        worksheet1.write('A8', "{0} is TLS Secured".format(cluster.display_name), cell_format)
        worksheet1.write('B8', str.upper(r2.text))
        r3 = requests.get('{0}/cm/kerberosInfo'.format(api_url), verify=False,
                          auth=(cm_client.configuration.username, cm_client.configuration.password))
        second_pair = json.loads(r3.text)
        values = list(second_pair.values())

        # Write Kerberos Result to worksheet
        if values[1]:
            worksheet1.write('A2', "{0} has Kerberos enabled".format(cluster.display_name), cell_format)
            worksheet1.write('B2', "Yes")
        else:
            worksheet1.write('A2', "{0} has Kerberos enabled".format(cluster.display_name))
            worksheet1.write('B2', "No")

        # Check if required services are installed
        services = services_api_instance.read_services(cluster.display_name, view='FULL')

        # Append services in cluster to respective cluster worksheet
        cluster_services = []
        service_result = []
        service_names = []
        for service in services.items:
            cluster_services.append(service.type)
            service_names.append(service.name)
        required_services = ["ZOOKEEPER", "HDFS", "OZONE", "HBASE", "HIVE", "KAFKA", "SOLR", "RANGER", "ATLAS", "YARN"]
        service_result.append(all(elem in cluster_services for elem in required_services))

    if service_result:
        worksheet1.write('A9', "All Required Services are Installed for all clusters", cell_format)
        worksheet1.write('B9', "Yes")
    else:
        worksheet1.write('A9', "Required Services are not Installed", cell_format)
        required_services = str(required_services)
        worksheet1.write('B9', "All Clusters require" + required_services + "to be considered a supported base cluster", text_format)
    # Check Python Version on Hue Servers
    python_version_result_aggregate = []
    for i in svcs:
        for j in svcs[i]:
            for k in hosts.items:
                for l in k.role_refs:
                    if svcs[i][j] in l.role_name and i in l.role_name:
                        python_hue_version = ["Python 2.7.5"]
                        installed_python_version = subprocess.getoutput("ssh %s 'python -V'" % k.hostname)
                        python_result = any(installed_python_version in string for string in python_hue_version)

                        # Write Result of Python Version Check to Error Worksheet (if applicable)
                        if not python_result:
                            worksheet2.write(index_counter, 0, k.hostname, cell_format)
                            worksheet2.write(index_counter, 1, subprocess.getoutput("ssh %s 'python -V'" % k.hostname),
                                             text_format)
                            index_counter = index_counter + 1
                        else:
                            python_version_result_aggregate.append(str(python_result))
    # Check TLS & Kerberos for Services
    for name in service_names:
        if "atlas" in name.lower():
            atlas = name + "-ATLAS_SERVER-BASE"
            try:
                atlas_result = api_instance.read_config(cluster.display_name, atlas, name, view="summary")
                atlas_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in atlas_kerberos.items:
                    if config.name == "kerberos.auth.enable":
                        worksheet4.write(kerberos_counter, 0, "Atlas")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in atlas_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Atlas")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "hbase" in name.lower():
            hbase_res = name + "-HBASERESTSERVER-BASE"
            hbase_thrift = name + "-HBASETHRIFTSERVER-BASE" # hbase_thriftserver_http_use_ssl
            api_instance = cm_client.RoleConfigGroupsResourceApi(api_client)
            try:
                hbase_rs_result = api_instance.read_config(cluster.display_name, hbase_res, name, view="summary")
                hbase_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in hbase_kerberos.items:
                    if config.name == "hbase_security_authentication":
                        worksheet4.write(kerberos_counter, 0, "HBase")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                    if config.name == "hbase_restserver_security_authentication":
                        worksheet4.write(kerberos_counter, 0, "HBase")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in hbase_rs_result.items:
                    if config.name == "hbase_restserver_ssl_enable" or config.name == "hbase_restserver_ssl_enabled":
                        worksheet3.write(tls_counter, 0, "HBase Rest Server")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                hbase_thrift_result = api_instance.read_config(cluster.display_name, hbase_thrift, name, view="summary")
                for config in hbase_thrift_result.items:
                    if config.name == "hbase_thriftserver_http_use_ssl" or config.name == "hbase_thriftserver_https_use_ssl":
                        worksheet3.write(tls_counter, 0, "HBase Thrift Server")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "hdfs" in name.lower():
            hdfs = name
            try:
                hdfs_result = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                hdfs_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in hdfs_kerberos.items:
                    if config.name == "hadoop_security_authentication":
                        worksheet4.write(kerberos_counter, 0, "HDFS")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                    if config.name == "hadoop_secure_web_ui":
                        worksheet4.write(kerberos_counter, 0, "HDFS")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in hdfs_result.items:
                    if config.name == "hdfs_hadoop_ssl_enabled" or config.name == "hdfs_hadoop_ssl_enable":
                        worksheet3.write(tls_counter, 0, "HDFS")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling ServicesResourceApi->read_service_config: %s\n" % e)

        if "hive" in name.lower() and not "hive_on_tez" in name.lower():
            hive = name
            try:
                hive_result = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in hive_result.items:
                    if config.name == "ssl_enabled_database" or config.name == "ssl_enable_database":
                        worksheet3.write(tls_counter, 0, "Hive Metastore Server")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1

                    if config.name == "hiveserver2_enable_ssl" or config.name == "hiveserver2_enabled_ssl":
                        worksheet3.write(tls_counter, 0, "Hive Server 2")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling ServicesResourceApi->read_service_config: %s\n" % e)

        if "hue" in name.lower():
            hue = name + "-HUE_SERVER-BASE"
            try:
                hue_result = api_instance.read_config(cluster.display_name, hue, name, view="summary")
                for config in hue_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Hue")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "impala" in name.lower():
            impala = name
            try:
                impala_result = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in impala_result.items:
                    if config.name == "client_services_ssl_enabled" or config.name == "client_services_ssl_enable":
                        worksheet3.write(tls_counter, 0, "Impala")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "kafka" in name.lower():
            kafka_broker = name + "-KAFKA_BROKER-BASE"
            kafka_connect = name + "-KAFKA_CONNECT-BASE"
            kafka_mirror = name + "-KAFKA_MIRROR_MAKER-BASE"
            try:
                kafka_broker_result = api_instance.read_config(cluster.display_name, kafka_broker, name, view="summary")
                kafka_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in kafka_kerberos.items:
                    if config.name == "kerberos.auth.enable":
                        worksheet4.write(kerberos_counter, 0, "Kafka")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in kafka_broker_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Kafka Broker")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                kafka_connect_result = api_instance.read_config(cluster.display_name, kafka_connect, name, view="summary")
                for config in kafka_connect_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Kafka Connect")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                kafka_mirror_result = api_instance.read_config(cluster.display_name, kafka_mirror, name, view="summary")
                for config in kafka_mirror_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Kafka Mirror Maker")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                    else:
                        worksheet3.write(tls_counter, 0, "Kafka Mirror Maker")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, "False")
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "ranger" in name.lower() and not "ranger_rms" in name.lower():
            ranger_admin = name + "-RANGER_ADMIN-BASE"
            try:
                ranger_admin_result = api_instance.read_config(cluster.display_name, ranger_admin, name, view="summary")
                for config in ranger_admin_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Ranger Admin")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

            ranger_tagsync = name + "-RANGER_TAGSYNC-BASE"
            try:
                ranger_tagsync_result = api_instance.read_config(cluster.display_name, ranger_tagsync, name, view="summary")
                for config in ranger_tagsync_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Ranger Tagsync")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "ranger_rms" in name.lower():
            ranger_rms = name + "-RANGER_RMS_SERVER-BASE"
            try:
                ranger_rms_result = api_instance.read_config(cluster.display_name, ranger_rms, name, view="summary")
                ranger_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in ranger_kerberos.items:
                    if config.name == "ranger_rms_authentication":
                        worksheet4.write(kerberos_counter, 0, "Ranger RMS")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in ranger_rms_result.items:
                    if config.name == "ssl_enable" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Ranger RMS")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1

            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "solr" in name.lower() and not "solr_user" in name.lower():
            solr = "solr"
            try:
                solr_result = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                solr_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in solr_kerberos.items:
                    if config.name == "solr_security_authentication":
                        worksheet4.write(kerberos_counter, 0, "Solr")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in solr_result.items:
                    if config.name == "solr_use_ssl" or config.name == "solr_use_ssl":
                        worksheet3.write(tls_counter, 0, "Solr")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

        if "zookeeper" in name.lower():
            zookeeper = name
            try:
                zookeeper_result = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                zookeeper_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in zookeeper_kerberos.items:
                    if config.name == "enableSecurity":
                        worksheet4.write(kerberos_counter, 0, "Zookeeper")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                    if config.name == "quorum_auth_enable_sasl":
                        worksheet4.write(kerberos_counter, 0, "Zookeeper")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in zookeeper_result.items:
                    if config.name == "zookeeper_tls_enabled" or config.name == "ssl_enabled":
                        worksheet3.write(tls_counter, 0, "Zookeeper")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling ServicesResourceApi->read_service_config: %s\n" % e)
        if "ozone" in name.lower():
            ozone_dn = name + "-OZONE_DATANODE-BASE" # ssl_enabled
            ozone_manager = name + "-OZONE_MANAGER-BASE" # ssl_enabled
            ozone_recon = name + "-OZONE_RECON-BASE" # ssl_enabled
            ozone_gateway = name + "-S3_GATEWAY-BASE" # ssl_enabled
            ozone_scm = name + "-STORAGE_CONTAINER_MANAGER-BASE" # ssl_enabled

            try:
                ozone_dn_result = api_instance.read_config(cluster.display_name, ozone_dn, name, view="summary")
                ozone_kerberos = services_api_instance.read_service_config(cluster.display_name, name, view="summary")
                for config in ozone_kerberos.items:
                    if config.name == "ozone.security.enabled":
                        worksheet4.write(kerberos_counter, 0, "Ozone")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                    if config.name == "ozone.security.http.kerberos.enabled":
                        worksheet4.write(kerberos_counter, 0, "Ozone")
                        worksheet4.write(kerberos_counter, 1, config.name)
                        worksheet4.write(kerberos_counter, 2, config.value)
                        kerberos_counter = kerberos_counter + 1
                for config in ozone_dn_result.items:
                    if config.name == "ssl_enabled" or config.name == "ssl_enable":
                        worksheet3.write(tls_counter, 0, "Ozone Datanode")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                ozone_manager_result = api_instance.read_config(cluster.display_name, ozone_manager, name, view="summary")
                for config in ozone_manager_result.items:
                    if config.name == "ssl_enabled" or config.name == "ssl_enable":
                        worksheet3.write(tls_counter, 0, "Ozone Manager")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                ozone_recon_result = api_instance.read_config(cluster.display_name, ozone_recon, name, view="summary")
                for config in ozone_recon_result.items:
                    if config.name == "ssl_enabled" or config.name == "ssl_enable":
                        worksheet3.write(tls_counter, 0, "Ozone Recon")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                ozone_gateway_result = api_instance.read_config(cluster.display_name, ozone_gateway, name, view="summary")
                for config in ozone_gateway_result.items:
                    if config.name == "ssl_enabled" or config.name == "ssl_enable":
                        worksheet3.write(tls_counter, 0, "Ozone Gateway")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
                ozone_scm_result = api_instance.read_config(cluster.display_name, ozone_scm, name, view="summary")
                for config in ozone_scm_result.items:
                    if config.name == "ssl_enabled" or config.name == "ssl_enable":
                        worksheet3.write(tls_counter, 0, "Ozone Storage Container Manager")
                        worksheet3.write(tls_counter, 1, config.name)
                        worksheet3.write(tls_counter, 2, config.value)
                        tls_counter = tls_counter + 1
            except ApiException as e:
                print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

    # Write Python Summary Status to Sheet
    bool_result = any("False" in string for string in python_version_result_aggregate)
    if not bool_result:
        worksheet1.write('A3', 'Are all base cluster nodes are running the supported version of python?', cell_format)
        worksheet1.write('B3', "Yes")

    # Initialize lists for checks
    linux_version_result_aggregate = []
    parcel_result_aggregate = []
    java_version_result_aggregate = []
    firewalld_result_aggregate = []
    chronyd_ntpd_result_aggregate = []
    vm_swappiness_result_aggregate = []
    nfs_result_aggregate = []
    se_result_aggregate = []

    # Check Linux Versions
    for k in hosts.items:
        rhel_versions = ["Red Hat Enterprise Linux Server release 8.4 (Ootpa)",
                         "Red Hat Enterprise Linux Server release 8.2 (Ootpa)",
                         "Red Hat Enterprise Linux Server release 7.9 (Maipo)",
                         "Red Hat Enterprise Linux Server release 7.7 (Maipo)",
                         "Red Hat Enterprise Linux Server release 7.6 (Maipo)"]
        centos_versions = ["CentOS Linux release 8.2.2004 (Core)", "CentOS Linux release 7.9.2009 (Core)"
                                                                   "CentOS Linux release 7.7.1908 (Core)",
                           "CentOS Linux release 7.6.1810 (Core)"]
        installed_os_version = subprocess.getoutput("ssh %s 'cat /etc/redhat-release'" % k.hostname)
        os_result = any(installed_os_version in string for string in rhel_versions) or any(
            installed_os_version in string for string in centos_versions)

        # If version is unsupported, add the hostname and rhel version that is not supported to the spreadsheet
        if not os_result:
            worksheet2.write(index_counter, 0, k.hostname, cell_format)
            worksheet2.write(index_counter, 1, subprocess.getoutput("ssh %s 'cat /etc/redhat-release'" % k.hostname),
                             text_format)
            index_counter = index_counter + 1
            linux_version_result_aggregate.append(str(os_result))
        else:
            linux_version_result_aggregate.append(str(os_result))


        # Check if there is enough space on parcel directory to accommodate CDP Parcel
        parcel_space = subprocess.getoutput(
            "ssh %s df -h /opt/cloudera/parcels | awk \'{print $4}\' | egrep \"G\" | sed \"s/G//\"" % k.hostname)
        parcel_space = int(parcel_space)
        if parcel_space < 20:
            worksheet2.write(index_counter, 0, k.hostname, cell_format)
            worksheet2.write(index_counter, 1, "20GB not free on /opt/cloudera/parcels dir")
            index_counter = index_counter + 1
            parcel_result_aggregate.append(str("Yes"))
        else:
            parcel_result_aggregate.append(str("No"))

        # Check Java Version
        oracle_java_versions = ["1.8"]
        open_jdk_versions = ["1.8", "11"]
        installed_java_version = subprocess.getoutput(
            "ssh %s java -version 2>&1 | grep \"version\" 2>&1 | awk -F\\\" '{ split($2,a,\".\"); print a[1]\".\"a[2]}'" % k.hostname)
        java_result = any(installed_java_version in string for string in oracle_java_versions) or any(
            installed_java_version in string for string in open_jdk_versions)

        # If version is unsupported, add the hostname and java version that is not supported to the spreadsheet
        if not java_result:
            worksheet2.write(index_counter, 0, k.hostname, cell_format)
            worksheet2.write(index_counter, 1, subprocess.getoutput("ssh %s 'java -version'" % k.hostname), text_format)
            index_counter = index_counter + 1
            java_version_result_aggregate.append(str(java_result))
        else:
            java_version_result_aggregate.append(str(java_result))

    # Initialize ECS Checks
    iptable_result_aggregate = []
    scsi_result_aggregate = []
    ftype_result_aggregate = []

    # ECS Checks
    for ecs_host in ecs_hosts:
        # SCP Scripts
        os.system("scp virgin_iptable.txt %s:/tmp/" % ecs_host)
        os.system("scp iptable_check.sh %s:/tmp/" % ecs_host)
        os.system("scp scsi_check.sh %s:/tmp/" % ecs_host)
        os.system("scp ftype.sh %s:/tmp/" % ecs_host)

        # Check Iptables
        iptable_check = subprocess.getoutput("ssh %s 'sh /tmp/iptable_check.sh'" % ecs_host)
        if "clean iptables" in iptable_check:
            iptable_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, "Iptables are filled with rules")
            index_counter = index_counter + 1
            iptable_result_aggregate.append("False")

        # Check SCSI
        scsi_check = subprocess.getoutput("ssh %s 'sh /tmp/scsi_check.sh'" % ecs_host)
        if "all devices are scsi" in scsi_check:
            scsi_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, scsi_check)
            index_counter = index_counter + 1
            scsi_result_aggregate.append("False")

        # Check FType
        ftype_check = subprocess.getoutput("ssh %s 'sh /tmp/ftype.sh'" % ecs_host)
        if "ftype=1" == ftype_check:
            ftype_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, ftype_check, text_format)
            index_counter = index_counter + 1
            ftype_result_aggregate.append("False")

        # Check Firewalld Service
        firewalld_output = subprocess.getoutput("ssh %s 'systemctl status firewalld.service | grep Active'" % ecs_host)
        if "inactive" in firewalld_output or "Unit firewalld.service could not be found." in firewalld_output:
            firewalld_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, "Firewalld is Running")
            index_counter = index_counter + 1
            firewalld_result_aggregate.append("False")

        # Check Chronyd & NTP
        chronyd_output = subprocess.getoutput("ssh %s 'systemctl status chronyd.service | grep Active'" % ecs_host)
        ntpd_output = subprocess.getoutput("ssh %s 'systemctl status ntpd.service | grep Active'" % ecs_host)
        if "running" in chronyd_output or "running" in ntpd_output:
            chronyd_ntpd_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, "Chronyd/NTPD is not running")
            index_counter = index_counter + 1
            chronyd_ntpd_result_aggregate.append("False")

        # Check VM Swappiness
        vm_output = subprocess.getoutput("ssh %s 'cat /etc/sysctl.conf | grep vm.swappiness'" % ecs_host)
        if "1" in vm_output:
            vm_swappiness_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, vm_output)
            index_counter = index_counter + 1
            vm_swappiness_result_aggregate.append("False")

        # Check NFS Utils
        nfs_output = subprocess.getoutput("ssh %s 'rpm -qa | grep nfs-utils'" % ecs_host)
        if "nfs-utils" in nfs_output:
            nfs_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, "NFS Utility needs to be installed")
            index_counter = index_counter + 1
            nfs_result_aggregate.append("False")

        # Check SE Linux
        se_output = subprocess.getoutput("ssh %s 'sestatus'" % ecs_host)
        if "disabled" in se_output or "permissive" in se_output or "bash: sestatus: command not found" in se_output:
            se_result_aggregate.append("True")
        else:
            worksheet2.write(index_counter, 0, ecs_host, cell_format)
            worksheet2.write(index_counter, 1, "SE Linux needs to be set to disabled or permissive")
            index_counter = index_counter + 1
            se_result_aggregate.append("False")

    # Check if Postgres DB is encrypted
    encryption_result = subprocess.getoutput("ssh %s \'cat /var/lib/pgsql/10/data/postgresql.conf | grep \"ssl =\"\'" % postgres_host)
    if encryption_result in "ssl = on":
        worksheet1.write('A14', "The ECS Cluster Postgres DB is Encrypted", cell_format)
        worksheet1.write('B14', "Yes")
    else:
        worksheet1.write('A14', "The ECS Cluster Postgres DB is Encrypted", cell_format)
        worksheet1.write('B14', "No")

    # Write Summary Result for Iptables
    bool_result_iptable = any("False" in string for string in iptable_result_aggregate)
    if bool_result_iptable:
        worksheet1.write('A12', "All ECS nodes have clean iptables", cell_format)
        worksheet1.write('B12', "Yes")
    else:
        worksheet1.write('A12', "All ECS nodes have clean iptables", cell_format)
        worksheet1.write('B12', "No")

    # Write Summary Result for SCSI
    bool_result_scsi = any("False" in string for string in scsi_result_aggregate)
    if bool_result_scsi:
        worksheet1.write('A12', "All ECS nodes have scsi devices", cell_format)
        worksheet1.write('B12', "No")
    else:
        worksheet1.write('A12', "All ECS nodes have scsi devices", cell_format)
        worksheet1.write('B12', "Yes")

    # Write Summary Result for FType
    bool_result_ftype = any("False" in string for string in ftype_result_aggregate)
    if bool_result_ftype:
        worksheet1.write('A13', "All ECS nodes have devices with ftype=1", cell_format)
        worksheet1.write('B13', "No")
    else:
        worksheet1.write('A13', "All ECS nodes have devices with ftype=1", cell_format)
        worksheet1.write('B13', "Yes")

    # Write Summary Result for Firewalld Service
    bool_result_firewalld = any("False" in string for string in firewalld_result_aggregate)
    if bool_result_firewalld:
        worksheet1.write('A7', "All ECS nodes are not running firewalld", cell_format)
        worksheet1.write('B7', "No")
    else:
        worksheet1.write('A7', "All ECS nodes are not running firewalld", cell_format)
        worksheet1.write('B7', "Yes")

    # Write Summary Result for Chronyd & NTP
    bool_result_chronyd_ntp = any("False" in string for string in chronyd_ntpd_result_aggregate)
    if bool_result_chronyd_ntp:
        worksheet1.write('A8', "All ECS nodes are running either NTP or Chronyd", cell_format)
        worksheet1.write('B8', "No")
    else:
        worksheet1.write('A8', "All ECS nodes are running either NTP or Chronyd", cell_format)
        worksheet1.write('B8', "Yes")

    # Write Summary Result for vm.swappiness
    bool_result_vm = any("False" in string for string in vm_swappiness_result_aggregate)
    if bool_result_vm:
        worksheet1.write('A9', "All ECS nodes have vm.swappiness=1", cell_format)
        worksheet1.write('B9', "No")
    else:
        worksheet1.write('A9', "All ECS nodes have vm.swappiness=1", cell_format)
        worksheet1.write('B9', "Yes")

    # Write Summary Result for NFS Utils
    bool_result_nfs = any("False" in string for string in nfs_result_aggregate)
    if bool_result_nfs:
        worksheet1.write('A10', "All ECS nodes have nfs utils installed", cell_format)
        worksheet1.write('B10', "No")
    else:
        worksheet1.write('A10', "All ECS nodes have nfs utils installed", cell_format)
        worksheet1.write('B10', "Yes")

    # Write Summary Result for SE Linux
    bool_result_se = any("False" in string for string in se_result_aggregate)
    if bool_result_se:
        worksheet1.write('A11', "All ECS nodes have SE Linux disabled", cell_format)
        worksheet1.write('B11', "No")
    else:
        worksheet1.write('A11', "All ECS nodes have SE Linux disabled", cell_format)
        worksheet1.write('B11', "Yes")

    # Write Summary Result for CDP Parcel Space
    bool_result_parcel = any("False" in string for string in parcel_result_aggregate)
    if bool_result_parcel:
        worksheet1.write('A4', "All base cluster nodes have enough space to accommodate the CDP Parcel (20GB)", cell_format)
        worksheet1.write('B4', "Yes")
    else:
        worksheet1.write('A4', "All base cluster nodes have enough space to accommodate the CDP Parcel (20GB)", cell_format)
        worksheet1.write('B4', "No")

    # Write Summary Result for Linux Version
    bool_result_linux = any("False" in string for string in linux_version_result_aggregate)
    if not bool_result_linux:
        worksheet1.write('A5', "All base cluster nodes are running the supported version of Linux", cell_format)
        worksheet1.write('B5', "Yes")
    else:
        worksheet1.write('A5', "All base cluster nodes are running the supported version of Linux", cell_format)
        worksheet1.write('B5', "No")

    # Write Summary Result for Java Version
    bool_result_java = any("False" in string for string in java_version_result_aggregate)
    if not bool_result_java:
        worksheet1.write('A6', "All base cluster nodes are running the supported version of Java", cell_format)
        worksheet1.write('B6', 'Yes')
    else:
        worksheet1.write('A6', "All base cluster nodes are running the supported version of Java", cell_format)
        worksheet1.write('B6', 'No')

    # Format Worksheet cell width
    worksheet1.set_column("A:J", 100)
    worksheet2.set_column("A:J", 100)
    worksheet3.set_column("A:J", 50)
    worksheet4.set_column("A:J", 50)

    # Close workbook
    workbook.close()


def main():
    version_check()


if __name__ == '__main__':
    main()
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
import cm_client
import requests
import subprocess
import re
import xlsxwriter

requests.packages.urllib3.disable_warnings()


def version_check():
    # Configure HTTPS authentication
    cm_client.configuration.username = 'usr'
    cm_client.configuration.password = 'pwd'
    cm_client.configuration.verify_ssl = False
    cm_host = 'cloudera_manager_host'

    # Setup Workbook
    workbook = xlsxwriter.Workbook('Version_Check.xlsx')
    worksheet1 = workbook.add_worksheet('Status Summary')
    worksheet2 = workbook.add_worksheet('Incompatible Versions Error Log')
    cell_format = workbook.add_format({'bold': True, 'italic': False, "center_across": True})
    text_format = workbook.add_format({'text_wrap': True})
    worksheet2.write("A1", "Hostname", cell_format)
    worksheet2.write('B1', "Error on Host", cell_format)
    index_counter = 1

    # Construct base URL for API
    api_host = 'https://' + cm_host
    port = '7183'
    api_version = 'v41'
    api_url = api_host + ':' + port + '/api/' + api_version
    api_client = cm_client.ApiClient(api_url)

    # Get Host API
    hosts_api_instance = cm_client.HostsResourceApi(api_client)
    hosts = hosts_api_instance.read_hosts(view='FULL')

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
            worksheet2.write(index_counter, 1, 'TRUE')
            index_counter = index_counter + 1
        else:
            db_version_result_aggregate.append(str(postgres_result))

        bool_result = any("False" in string for string in db_version_result_aggregate)
        # Write Summary Result for DB Version to Worksheet
        if not bool_result:
            worksheet1.write('A1', 'The version of postgres running is supported', cell_format)
            worksheet1.write('B1', 'TRUE')
        else:
            worksheet1.write('A1', 'The version of postgres running is supported', cell_format)
            worksheet1.write('B1', 'FALSE')

    # Check if DB Type is MySQL or MariaDB
    elif first_pair[1] == "MYSQL" or first_pair[1] == "MARIADB":
        db_version = subprocess.getoutput("ssh {0} 'mysql -V'".format(db_host))
        head, sep, tail = db_version.partition('Distrib ')
        temp = tail
        head, sep, tail = temp.partition('-MariaDB')
        temp2 = head
        x = temp2.split('.')
        db_version = x[0] + '.' + x[1]
        supported_mysql_versions = ["8.0", "5.7"]
        supported_mariaDB_versions = ["10.5", "10.4", "10.3", "10.2"]
        db_result = any(db_version in string for string in supported_mysql_versions) or any(
            db_version in string for string in supported_mariaDB_versions)

        # Check if Version of MariaDB / MySQL Installed is Supported
        if not db_result:
            worksheet2.write('A1', "The db version installed is not supported", cell_format)
            worksheet2.write('B1', 'TRUE', cell_format)
        else:
            db_version_result_aggregate.append(str(db_result))

        # Write Result to Worksheet
        bool_result = any("False" in string for string in db_version_result_aggregate)
        if not bool_result:
            worksheet1.write('A2', "The version of {0} installed is supported".format(first_pair[1]), cell_format)
            worksheet1.write('B2', 'TRUE')
        else:
            worksheet1.write('A2', "The version of {0} installed is supported".format(first_pair[1]), cell_format)
            worksheet1.write('B2', 'FALSE')

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
        if values[3]:
            worksheet1.write('A2', "{0} has Kerberos enabled".format(cluster.display_name), cell_format)
            worksheet1.write('B2', "TRUE")
        else:
            worksheet1.write('A2', "{0} has Kerberos enabled".format(cluster.display_name))
            worksheet1.write('B2', "FALSE")

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

    # Write Python Summary Status to Sheet
    bool_result = any("False" in string for string in python_version_result_aggregate)
    if not bool_result:
        worksheet1.write('A3', 'All nodes are running the supported version of python', cell_format)
        worksheet1.write('B3', "TRUE")

    # Check Linux Versions
    linux_version_result_aggregate = []
    parcel_result_aggregate = []
    java_version_result_aggregate = []
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
            parcel_result_aggregate.append(str("True"))
        else:
            parcel_result_aggregate.append(str("False"))

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

    # Write Summary Result for CDP Parcel Space
    bool_result_parcel = any("False" in string for string in parcel_result_aggregate)
    if bool_result_parcel:
        worksheet1.write('A4', "All nodes have enough space to accommodate the CDP Parcel (20GB)", cell_format)
        worksheet1.write('B4', "TRUE")
    else:
        worksheet1.write('A4', "All nodes have enough space to accommodate the CDP Parcel (20GB)", cell_format)
        worksheet1.write('B4', "FALSE")

    # Write Summary Result for Linux Version
    bool_result_linux = any("False" in string for string in linux_version_result_aggregate)
    if not bool_result_linux:
        worksheet1.write('A5', "All nodes are running the supported version of Linux", cell_format)
        worksheet1.write('B5', "TRUE")
    else:
        worksheet1.write('A5', "All nodes are running the supported version of Linux", cell_format)
        worksheet1.write('B5', "FALSE")

    # Write Summary Result for Java Version
    bool_result_java = any("False" in string for string in java_version_result_aggregate)
    if not bool_result_java:
        worksheet1.write('A6', "All nodes are running the supported version of Java", cell_format)
        worksheet1.write('B6', 'TRUE')
    else:
        worksheet1.write('A6', "All nodes are running the supported version of Java", cell_format)
        worksheet1.write('B6', 'FALSE')

    # Format Worksheet cell width
    worksheet1.set_column("A:J", 100)
    worksheet2.set_column("A:J", 100)

    # Close workbook
    workbook.close()


def main():
    version_check()


if __name__ == '__main__':
    main()

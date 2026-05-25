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

import subprocess
import cm_client
import requests
import json
import xlsxwriter

requests.packages.urllib3.disable_warnings()


def hosts():
    # Open new workbook
    workbook = xlsxwriter.Workbook('Cluster_Discovery.xlsx')
    worksheet1 = workbook.add_worksheet('Host_Information')
    worksheet2 = workbook.add_worksheet('Cloudera_Version_Information')
    cell_format = workbook.add_format({'bold': True, 'italic': False})
    text_format = workbook.add_format({'text_wrap': True})

    # Configure HTTPS authentication
    cm_client.configuration.username = "usr"
    cm_client.configuration.password = "pwd"
    cm_host = 'cloudera_manager_server_url'
    cm_client.configuration.verify_ssl = False
    api_host = 'https://' + cm_host
    port = '7183'
    api_version = 'v31'

    # Construct base URL for API
    api_url = api_host + ':' + port + '/api/' + api_version
    api_client = cm_client.ApiClient(api_url)
    clustername = {}
    cluster_api_instance = cm_client.ClustersResourceApi(api_client)
    services_api_instance = cm_client.ServicesResourceApi(api_client)

    # Get CM Version
    cm_version = subprocess.getoutput("ssh %s 'rpm -qa 'cloudera-manager-server*' | cut -c -29'" % cm_host)
    worksheet2.write('A1', 'CM Version & Build', cell_format)
    worksheet2.write('B1', cm_version)

    # Get DB Type
    r = requests.get('{0}/cm/scmDbInfo'.format(api_url), verify=False,
                     auth=(cm_client.configuration.username, cm_client.configuration.password))
    first_pair = next(iter((json.loads(r.text).items())))
    worksheet2.write('A2', first_pair[0], cell_format)
    worksheet2.write('B2', first_pair[1])
    worksheet2.write('A3', '')
    worksheet2.write('A4', 'Cluster Name', cell_format)
    worksheet2.write('B4', 'Version', cell_format)
    count = 4

    # Lists all known clusters
    worksheets = []
    api_response = cluster_api_instance.read_clusters(view='SUMMARY')

    for cluster in api_response.items:
        clustername[cluster.name] = cluster.display_name
        services = services_api_instance.read_services(cluster.name, view='FULL')

        # Create worksheet for each cluster in environment
        worksheet_name = workbook.add_worksheet(cluster.display_name)
        worksheets.append(worksheet_name)

        # Write Cluster Version information to Cloudera Version Sheet
        worksheet2.write(count, 0, cluster.display_name)
        worksheet2.write(count, 1, cluster.full_version)
        count = count + 1

        # Append services in cluster to respective cluster worksheet
        for worksheet in worksheets:
            if worksheet.name == cluster.display_name:
                j = 1
                worksheet.write('A1', 'Type of Service', cell_format)
                worksheet.write('B1', 'Service Name', cell_format)
                for service in services.items:
                    worksheet.write(j, 1, service.display_name)
                    worksheet.write(j, 0, service.type)
                    j = j + 1
            worksheet.set_column("A:J", 25)

    # Set up Host Information Sheet
    header = ("Hostname", "Roles", "Number of Roles", "Cluster", "Linux Version", "Model Number",
                  "Number of Cores", "Total Memory", "Java Version", "System Python Version")
    worksheet1.write_row('A1', header, cell_format)

    # Connect to hosts resource
    hosts_api_instance = cm_client.HostsResourceApi(api_client)
    cm_hosts = hosts_api_instance.read_hosts(view='FULL')
    r = 1
    for i in cm_hosts.items:
        # Collect host level information and append to host_information sheet
        memory = round(i.total_phys_mem_bytes * (10 ** -9), 1)
        rhel_version = subprocess.getoutput("ssh %s 'cat /etc/redhat-release'" % i.hostname)
        dmi_product = subprocess.getoutput("ssh %s 'cat /sys/class/dmi/id/product_name'" % i.hostname)
        java_version = subprocess.getoutput("ssh %s 'java -version'" % i.hostname)
        python_version = subprocess.getoutput("ssh %s 'python -V'" % i.hostname)
        roles = ""
        rolenum = 0
        cluster = ""
        for j in i.role_refs:
            roles += "'%s' " % (j.role_name[:-33].replace('-', ' ').replace('_', ' '))
            rolenum += 1
            if j.cluster_name is None:
                cluster = ""
            else:
                cluster = clustername[j.cluster_name]
        data_extract = (
            i.hostname, roles, rolenum, cluster, rhel_version, dmi_product, int(i.num_cores), memory,
            java_version, python_version)
        worksheet1.write_row(r, 0, data_extract, text_format)
        r = r + 1
    worksheet1.set_column("A:J", 25)
    worksheet2.set_column("A:J", 25)
    workbook.close()


def main():
    hosts()


if __name__ == '__main__':
    main()

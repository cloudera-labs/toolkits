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
import requests
import json
import xlsxwriter
import sys

requests.packages.urllib3.disable_warnings()


def hosts(args):
    # Open new workbook
    workbook = xlsxwriter.Workbook('Cluster_Discovery.xlsx')
    worksheet1 = workbook.add_worksheet('Host_Information')
    worksheet2 = workbook.add_worksheet('HDP_Version_Information')
    cell_format = workbook.add_format({'bold': True, 'italic': False})
    text_format = workbook.add_format({'text_wrap': True})

    # Configure HTTPS authentication
    AMBARI_USER_ID = "admin"
    AMBARI_USER_PW = "vsrivastava"
    AMBARI_DOMAIN = args
    HTTPS = False
    if HTTPS:
        AMBARI_PORT = '8443'
        PROTOCOL = 'https://'
    else:
        AMBARI_PORT = '8080'
        PROTOCOL = 'http://'
    
    restAPI='/api/v1/clusters'
    url=PROTOCOL+AMBARI_DOMAIN+":"+AMBARI_PORT+restAPI
    
    #Get HDP Version
    r=requests.get('{0}'.format(url), verify=False, auth=(AMBARI_USER_ID, AMBARI_USER_PW))
    json_data=json.loads(r.text)
    CLUSTER_NAME = json_data["items"][0]["Clusters"]["cluster_name"]

    restAPI="/api/v1/clusters/" + CLUSTER_NAME + "/stack_versions/"
    url=PROTOCOL+AMBARI_DOMAIN+":"+AMBARI_PORT+restAPI
    r1=requests.get('{0}'.format(url), verify=False, auth=(AMBARI_USER_ID, AMBARI_USER_PW))
    json_data=json.loads(r1.text)

    version=json_data["items"][0]["ClusterStackVersions"]["version"]
    stack=json_data["items"][0]["ClusterStackVersions"]["stack"]
    repository_version=json_data["items"][0]["ClusterStackVersions"]["repository_version"]
    
    hdp_version= stack + version

    worksheet2.write('A1', 'HDP Version', cell_format) 
    worksheet2.write('B1', hdp_version)

    worksheet2.write('A2', 'cluster_name', cell_format)
    worksheet2.write('B2', CLUSTER_NAME) 

    
    #Get the DB Type
    restAPI="/api/v1/services/AMBARI/components/AMBARI_SERVER?fields=RootServiceComponents/properties/server.jdbc.database"
    url=PROTOCOL+AMBARI_DOMAIN+":"+AMBARI_PORT+restAPI
    #http://c6401.ambari.apache.org:8080/api/v1/services/AMBARI/components/AMBARI_SERVER?fields=RootServiceComponents/properties/server.jdbc.database
    r2=requests.get('{0}'.format(url), verify=False, auth=(AMBARI_USER_ID, AMBARI_USER_PW))
    json_data=json.loads(r2.text)
    databasename=json_data["RootServiceComponents"]["properties"]["server.jdbc.database"]
    worksheet2.write('A3', '')
    worksheet2.write('A4', 'Ambari Database', cell_format)
    worksheet2.write('B4', databasename)

    #get List of services
    worksheet3 = workbook.add_worksheet('Active Services')
    worksheet3.write('A1', 'Service Name', cell_format)
    restAPI='/api/v1/clusters/' + CLUSTER_NAME +  '/services/'
    url=PROTOCOL+AMBARI_DOMAIN+":"+AMBARI_PORT+restAPI
    r3=requests.get('{0}'.format(url), verify=False, auth=(AMBARI_USER_ID, AMBARI_USER_PW))
    json_data=json.loads(r3.text)
    count=0
    j=1
    for i in json_data["items"]:
        worksheet3.write(j,0, json_data["items"][count]["ServiceInfo"]["service_name"])
        #print(json_data["items"][count]["ServiceInfo"]["service_name"])
        count=count+1
        j=j+1
    worksheet3.set_column("A:J", 25)    
    
    
    #get the host information
    header = ("Hostname", "Roles", "Number of Roles", "Cluster", "Linux Version", "Model Number",
                  "Java Version", "System Python Version")
    worksheet1.write_row('A1', header, cell_format)
    restAPI = "/api/v1/hosts"
    url=PROTOCOL+AMBARI_DOMAIN+":"+AMBARI_PORT+restAPI
    r=requests.get('{0}'.format(url), verify=False, auth=(AMBARI_USER_ID, AMBARI_USER_PW))
    json_data=json.loads(r.text)
    cnt=0
    r=1
    for j in json_data["items"]:
        hostname=json_data["items"][cnt]["Hosts"]["host_name"]
        rhel_version = subprocess.getoutput(f"ssh {hostname} 'cat /etc/redhat-release'")
        dmi_product = subprocess.getoutput(f"ssh {hostname} 'cat /sys/class/dmi/id/product_name'")
        java_version = subprocess.getoutput(f"ssh {hostname} 'java -version'")
        python_version = subprocess.getoutput(f"ssh {hostname} 'python -V'")

        restAPI1 = "/api/v1/clusters/" + CLUSTER_NAME + "/hosts/" + hostname + "/host_components/"
        url1=PROTOCOL+AMBARI_DOMAIN+":"+AMBARI_PORT+restAPI1
        r4=requests.get('{0}'.format(url1), verify=False, auth=(AMBARI_USER_ID, AMBARI_USER_PW))
        json_data1=json.loads(r4.text)
        roles = ""
        rolenum = 0
        for s in json_data1["items"]:
            roles+=json_data1["items"][rolenum]["HostRoles"]["component_name"] + "\n"
            rolenum=rolenum+1

        cluster=CLUSTER_NAME
        data_extract = (
            hostname, roles, rolenum, cluster, rhel_version, dmi_product,
            java_version, python_version)
        worksheet1.write_row(r, 0, data_extract, text_format)
        cnt=cnt+1
        r=r+1
    worksheet1.set_column("A:J", 25)
    workbook.close()

def main(argv):
    args = argv
    hosts(args)


if __name__ == '__main__': sys.exit(main(sys.argv[1]))
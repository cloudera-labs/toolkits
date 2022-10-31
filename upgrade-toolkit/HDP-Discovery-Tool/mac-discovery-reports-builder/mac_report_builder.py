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

import csv
import json
import logging
import os
import os.path
import re
from datetime import datetime
from pathlib import Path
import pandas as pd

log = logging.getLogger('main')

role_assignments = {
    'master': ["NAMENODE", "JOURNALNODE", "FAILOVERCONTROLLER", "RESOURCEMANAGER", "SERVER", "JOBHISTORY",
               "KUDU_MASTER", "MASTER", "SCHEMA_REGISTRY_SERVER", "SPARK_YARN_HISTORY_SERVER"],
    "utility": ["ACTIVITYMONITOR", "ALERTPUBLISHER", "EVENTSERVER", "HOSTMONITOR", "NAVIGATOR", "NAVIGATORMETASERVER",
                "REPORTSMANAGER", "SERVICEMONITOR", "TELEMETRYPUBLISHER", "CRUISE_CONTROL_SERVER", "HIVEMETASTORE",
                "CATALOGSERVER", "STATESTORE", "OOZIE_SERVER", "RANGER_ADMIN", "RANGER_TAGSYNC", "RANGER_USERSYNC",
                "ATLAS_SERVER", "SOLR_SERVER", "STREAMS_MESSAGING_MANAGER_SERVER", "STREAMS_MESSAGING_MANAGER_UI",
                "STREAMS_REPLICATION_MANAGER_SERVICE"
                ],
    "gateway": ["HUE_LOAD_BALANCER", "HUE_SERVER", "KT_RENEWER", "HIVESERVER2", "GATEWAY"],
    "worker": ["DATANODE", "NODEMANAGER", "IMPALAD", "KUDU_TSERVER", "KAFKA_BROKER", "KAFKA_CONNECT", "REGIONSERVER",
               "SOLR_SERVER", "STREAMS_REPLICATION_MANAGER_DRIVER"]
}

component_service_map = {}


class MacReportBuilder:
    def __init__(self, discovery_bundle_path, workbook):
        self.discovery_bundle_path = discovery_bundle_path
        self.workbook = workbook

    def create_node_report(self):
        log.debug("Node report building has been started.")
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/hosts.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.debug(
                "Issue in finding and loading the hosts.json in api_diagnostic folder: Please verify the extraction bundles output")
        else:
            for i, each in enumerate(data['items']):
                host_name = each['Hosts']['host_name']
                cluster_name = each['Hosts']['cluster_name']
                node_details = self.node_report(host_name)
                os_installed = node_details['os_type']
                java_installed = node_details['java_installed']
                vcores_available = node_details['vcores_available']
                pcores_available = node_details['pcores_available']
                cpu_clockspeed = node_details['cpu_clockspeed']
                memory_available = node_details['memory_available']
                disk_available = node_details['disk_available']
                disk_used = node_details['disk_used']
                roles_installed = node_details['roles_installed']
                services_installed = node_details['services_installed']
                self.workbook['Nodes'].append(
                    [host_name, cluster_name, os_installed, java_installed, vcores_available, pcores_available,
                     cpu_clockspeed,
                     memory_available, disk_available, disk_used, roles_installed, services_installed])
        log.debug("Node report building has been finished.")

    def node_report(self, hostname):
        hostname = hostname
        node_details = {}
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/' + hostname + 'details.json',
                      'r') as f:
                data = json.load(f)
        except IOError:
            log.debug(
                    "Issue in finding and loading the details.json in api_diagnostic folder: Please verify the extraction bundles output")
        else:
            node_details['vcores_available'] = data['Hosts']['cpu_count']
            node_details['os_arch'] = data['Hosts']['os_arch']
            node_details['os_family'] = data['Hosts']['os_family']
            node_details['os_type'] = data['Hosts']['os_type']
            node_details['pcores_available'] = data['Hosts']['ph_cpu_count']
            node_details['java_installed'] = '-'
            node_details['cpu_clockspeed'] = '-'
            node_details['memory_available'] = data['Hosts']['total_mem'] / (1024 * 1024)
            diskspace_available = 0
            diskspace_used = 0
            for i, disk in enumerate(data['Hosts']['disk_info']):
                diskspace_available += int(disk['available'])
                diskspace_used += int(disk['used'])
            node_details['disk_available'] = diskspace_available / (1024 * 1024)
            node_details['disk_used'] = diskspace_used / (1024 * 1024)
            host_components = []
            for each in data['host_components']:
                host_components.append(each['HostRoles']['component_name'])
            node_details['roles_installed'] = host_components.__str__()
            csmap = self.component_service_map()
            services_on_host = []
            for component in host_components:
                services_on_host.append(csmap[component])
            services_on_host = list(set(services_on_host))
            node_details['services_installed'] = services_on_host.__str__()
            return node_details


    def component_service_map(self):
        service_list = []
        components_service = {}
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/services.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.debug(
                    "Issue in finding and loading the services.json in api_diagnostic folder: Please verify the extraction bundles output")
        else:
            for each in data['items']:
                service_list.append(each['ServiceInfo']['service_name'])
            for service_name in service_list:
                with open(self.discovery_bundle_path + '/api_diagnostics/' + service_name + '.json', 'r') as f:
                    data = json.load(f)
                    for each in data['components']:
                        components_service[each['ServiceComponentInfo']['component_name']] = \
                        each['ServiceComponentInfo']['service_name']
        return components_service

    def create_configuration_report(self):
        log.debug("Configuration report building has been started.")
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/configurations.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.debug(
                    "Issue in finding and loading the configurations.json in api_diagnostic folder: Please verify the extraction bundles output")
        else:
            for i, each in enumerate(data['items']):
                for j, each1 in enumerate(data['items'][i]['configurations']):
                    conf_type = data['items'][i]['configurations'][j]['type']
                    cluster_name = data['items'][i]['configurations'][j]['Config']['cluster_name']
                    service_name = data['items'][i]['service_name']
                    for key, value in data['items'][i]['configurations'][j]['properties'].items():
                        self.workbook['Configurations'].append(
                            [cluster_name, service_name, "role-type", conf_type, key, value])

        log.debug("Configuration report building has been finished.")

    def get_cluster_name(self):
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/clusters.json', 'r') as f:
                clusterdata = json.load(f)
        except IOError:
            log.debug(
                "Issue in finding and loading the clusters.json in api_diagnostic folder: Please verify the extraction bundles output")
        else:
            cluster_name = clusterdata['cluster_name']
            return cluster_name

    def create_service_metrics_report(self):
        log.debug("Service Metrics report building has been started.")
        cluster_name = self.get_cluster_name()
        try:
            with open( self.discovery_bundle_path + '/AMS_METRICS/apps.json', 'r') as f:
                applist = json.load(f).keys()
        except IOError as e:
            log.error("Unable to find the apps.json file in AMS_METRICS folder Seems AMS service is not installed in the cluster")
            log.error(e)
            raise SystemExit(e)
        else:
            for app in applist:
                try:
                    with open( self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_max.json',
                              'r') as f:
                        data = json.load(f)
                except IOError:
                    log.error("unable to find the" + app + "_max.json")
                else:
                    filename1 =  self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_max.csv'
                    fields = ['cluster', 'app', 'service', 'timestamp', 'metric_name', 'max']
                    with open(filename1, 'a') as csvfile:
                        # creating a csv writer object
                        csvwriter = csv.writer(csvfile)

                        # writing the fields
                        csvwriter.writerow(fields)
                        for i, each in enumerate(data['metrics']):
                            for key, value in data['metrics'][i]['metrics'].items():
                                # appid = data['metrics'][i]['appid']
                                hostname = data['metrics'][i]['hostname']
                                # metric_starttime = data['metrics'][i]['starttime']
                                metric_name = data['metrics'][i]['metricname']
                                service = 'service'
                                row = [cluster_name, app, hostname, key, metric_name[:-5], value]
                                csvwriter.writerow(row)
                try:
                    with open( self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_min.json',
                              'r') as f:
                        data = json.load(f)
                except IOError:
                    log.error("unable to find the" + app + "_min.json")
                else:
                    filename2 =  self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_min.csv'
                    fields = ['cluster', 'app', 'service', 'timestamp', 'metric_name', 'min']
                    with open(filename2, 'a') as csvfile:
                        # creating a csv writer object
                        csvwriter = csv.writer(csvfile)

                        # writing the fields
                        csvwriter.writerow(fields)
                        for i, each in enumerate(data['metrics']):
                            for key, value in data['metrics'][i]['metrics'].items():
                                # appid = data['metrics'][i]['appid']
                                hostname = data['metrics'][i]['hostname']
                                # metric_starttime = data['metrics'][i]['starttime']
                                service = 'service'
                                metric_name = data['metrics'][i]['metricname']
                                row = [cluster_name, app, hostname, key, metric_name[:-5], value]
                                csvwriter.writerow(row)

                try:
                    with open( self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_avg.json',
                              'r') as f:
                        data = json.load(f)
                except IOError:
                    log.error("unable to find the" + app + "_avg.json")
                else:
                    filename3 = self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_avg.csv'
                    fields = ['cluster', 'app', 'service', 'timestamp', 'metric_name', 'avg']
                    with open(filename3, 'a') as csvfile:
                        # creating a csv writer object
                        csvwriter = csv.writer(csvfile)

                        # writing the fields
                        csvwriter.writerow(fields)
                        for i, each in enumerate(data['metrics']):
                            for key, value in data['metrics'][i]['metrics'].items():
                                # appid = data['metrics'][i]['appid']
                                hostname = data['metrics'][i]['hostname']
                                # metric_starttime = data['metrics'][i]['starttime']
                                service = 'service'
                                metric_name = data['metrics'][i]['metricname']
                                row = [cluster_name, app, hostname, key, metric_name[:-5], value]
                                csvwriter.writerow(row)
                try:
                    data1 = pd.read_csv(self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_max.csv')
                    data2 = pd.read_csv(self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_avg.csv')
                    data3 = pd.read_csv(self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_min.csv')
                except IOError:
                    log.error("unable to find the files" + app + "csv files")
                else:
                    concatenated = pd.concat([data3, data2[['avg']], data1[['max']]], axis=1)
                    concatenated.set_index('cluster', inplace=True)
                    concatenated.to_csv(self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_concat.csv')
                    csv_file = self.discovery_bundle_path + '/AMS_METRICS/' + app + '/' + app + '_concat.csv'
                    f = open(csv_file)
                    reader = csv.reader(f, delimiter=',')
                    next(reader, None)
                    for row in reader:
                        self.workbook['Metrics'].append(row)
        log.debug("Service Metrics report building has been finished.")

    def create_service_report(self):
        log.debug("Service report building has been started.")
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/services.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.error("Unable to find and open the services.json file, Please verify if the extraction bundle output is generated as expected")
        else:
            for i, each in enumerate(data['items']):
                service_name = each['ServiceInfo']['service_name']
                self.service_report(service_name)
        log.debug("Service report building has been finished.")

    def service_report(self, service_name):
        service_name = service_name
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/' + service_name + '.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.error("unable to find the component" +service_name+ "file")
        else:
            for i, each in enumerate(data['components']):
                component_name = data['components'][i]['ServiceComponentInfo']['component_name']
                self.component_hostname(component_name)

    def component_hostname(self, component_name):
        component_name = component_name
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/' + component_name + '.json',
                      'r') as f:
                data = json.load(f)
        except IOError:
            log.error("unable to find and open" + component_name + ".json")
        else:
            for i,each in enumerate(data['host_components']):
                service_name = data['ServiceComponentInfo']['service_name']
                host_name = data['host_components'][i]['HostRoles']['host_name']
                cluster_name = data['host_components'][i]['HostRoles']['cluster_name']
                component_name = data['host_components'][i]['HostRoles']['component_name']
                self.workbook['Services'].append([host_name, cluster_name, service_name, component_name])

    def create_hive_metastore_report(self):
        csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/hive")).rglob("*.csv")
        for csv_file in csv_files:
            try:
                f = open(csv_file)
            except IOError:
                log.error("unable to find the hive extraction csv file")
            else:
                reader = csv.reader(f, delimiter=',')
                next(reader, None)
                for row in reader:
                    self.workbook['Hive Metastore'].append(row)

    def create_cm_report(self):
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/ambari_details.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.error("unable to find and load ambari_details.json")
        else:
            ct = datetime.now()
            extraction_time = ct
            cm_url = data['ambari_http_protocol'] + "://" + data['ambari_server_host'] + ":" + data['ambari_server_port']
            cm_version = '-'
            if data['ambari_http_protocol'] == "https":
                cm_tls_enabled = True
                cm_agent_tls_enabled = True
            else:
                cm_tls_enabled = False
                cm_agent_tls_enabled = False
            identity_service_provider = "-"
            self.workbook['CM'].append(
                [extraction_time, cm_url, cm_version, cm_tls_enabled, cm_agent_tls_enabled, identity_service_provider])

    def create_cluster_report(self):
        cluster_name = self.get_cluster_name()
        hdfs_data = self.get_latest_hdfs_map()
        hms_report_map = self.fetch_latest_hms_deployment_info()
        cluster_hosts = self.get_cluster_hosts()
        host_assignments, role_types = self.create_role_assignment_map()
        cluster_hardware = self.get_cluster_hardware_map(cluster_hosts, host_assignments['worker'])
        self.workbook["Clusters"].append(
            [
                cluster_name,
                hdfs_data['dfs_capacity_used'] / (1024 * 1024 * 1024),
                hdfs_data['dfs_capacity'] / (1024 * 1024 * 1024),
                cluster_hardware["total_cpu_cores"],
                cluster_hardware["total_memory"] / (1024 * 1024),
                cluster_hardware["total_worker_cpu_cores"],
                cluster_hardware["total_worker_memory"] / (1024 * 1024),
                hms_report_map['view'],
                hms_report_map["table"],
                len(cluster_hosts),
                len(host_assignments['master']),
                host_assignments['master'].__str__(),
                len(host_assignments['utility']),
                host_assignments['utility'].__str__(),
                len(host_assignments['gateway']),
                host_assignments['gateway'].__str__(),
                len(host_assignments['worker']),
                host_assignments['worker'].__str__(),
                len(set(role_types))
            ]
        )

    def get_cluster_hardware_map(self, cluster_hosts, worker_hosts_names):
        cluster_hardware = {
            "total_cpu_cores": 0,
            "total_memory": 0,
            "total_worker_cpu_cores": 0,
            "total_worker_memory": 0
        }
        for host in cluster_hosts:
            try:
                with open(self.discovery_bundle_path + '/api_diagnostics/' + host + 'details.json', 'r') as f:
                    data = json.load(f)
            except IOError:
                log.error("unable to find the" + host + "details.json")
            else:
                cluster_hardware['total_cpu_cores'] += data['Hosts']['cpu_count']
                cluster_hardware['total_memory'] += data['Hosts']['total_mem']
        for host in worker_hosts_names:
            try:
                with open(self.discovery_bundle_path + '/api_diagnostics/' + host + 'details.json', 'r') as f:
                    data = json.load(f)
            except IOError:
                log.error("unable to find and load the" + host + "details.json")
            else:
                cluster_hardware['total_worker_cpu_cores'] += data['Hosts']['cpu_count']
                cluster_hardware['total_worker_memory'] += data['Hosts']['total_mem']
        return cluster_hardware

    def create_role_assignment_map(self):
        host_assignments = {
            'master': [],
            "utility": [],
            "gateway": [],
            "worker": []
        }
        role_list = []
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/componentslist.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.error("unable to find and load the componentslist.json")
        else:
            for each in data['items']:
                role_list.append(each['HostRoles']['component_name'])
                for key, role_assignment_types in role_assignments.items():
                    if each['HostRoles']['component_name'] in role_assignment_types and each['HostRoles']['host_name'] not in host_assignments[key]:
                        host_assignments[key].append(each['HostRoles']['host_name'])
            return host_assignments, role_list

    def fetch_latest_hms_deployment_info(self):
        table_counter = {"table": 0, "view": 0}
        hms_csv_path = self.discovery_bundle_path + "/workload/hive/hive_ms.csv"
        if not os.path.exists(hms_csv_path):
            return table_counter
        try:
            f = open(hms_csv_path)
        except IOError:
            log.error("unable to open the file" + hms_csv_path)
        else:
            reader = csv.reader(f, delimiter=',')
            next(reader, None)
            for row in reader:
                if "MANAGED_TABLE" in row or "EXTERNAL_TABLE" in row:
                    table_counter['table'] = table_counter['table'] + 1
                elif "VIRTUAL_VIEW" in row:
                    table_counter['view'] = table_counter['view'] + 1
            return table_counter

    def get_cluster_hosts(self):
        try:
            with open(self.discovery_bundle_path + '/api_diagnostics/hosts.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.error("unable to find and load the hosts.json")
        else:
            cluster_hosts = []
            for each in data['items']:
                cluster_hosts.append(each['Hosts']['host_name'])
            return cluster_hosts

    def get_latest_hdfs_map(self):
        log.debug("started collecting latest hdfs data")
        hdfs_data = {}
        try:
            with open(self.discovery_bundle_path + '/AMB_METRICS/HDFS/NAMENODE/NAMENODE_METRICS.json',
                      'r') as f:
                data = json.load(f)
        except IOError:
            log.error("unable to load the NAMENODE_METRICS.json from AMB_METRIC folder")
        else:
            hdfs_data['dfs_capacity_used'] = data['ServiceComponentInfo']['CapacityUsed']
            hdfs_data['dfs_capacity'] = data['ServiceComponentInfo']['CapacityTotal']
            return hdfs_data

    def create_ranger_policy_report(self):
        log.debug("Ranger Policy report building has been started.")
        try:
            with open(self.discovery_bundle_path + '/ranger_policies/ranger_policies.json', 'r') as f:
                data = json.load(f)
        except IOError:
            log.error("Unable to find and open the ranger_plocies.json file, Please verify if the extraction bundle output is generated as expected")
        else:
            for i, each in enumerate(data):
                policy_id = each['id']
                guid = each['guid']
                isEnabled = each['isEnabled']
                version = each['version']
                service = each['service']
                name = each['name']
                serviceType = each['serviceType']
                self.workbook["Policy"].append([policy_id, guid, isEnabled, version, service, name, serviceType])
        log.debug("Ranger policy report building has been finished.")

    def create_hdfs_report(self):
        log.debug("HDFS report building has started")
        csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/")).rglob("hdfs_report.csv")
        hdfs_sheet_original = self.workbook['HDFS Report']
        counter = 1
        for csv_file in csv_files:
            hdfs_sheet = self.workbook.copy_worksheet(hdfs_sheet_original)
            hdfs_sheet.title = "HDFS Report " + str(counter)
            f = open(csv_file)
            reader = csv.reader(f, delimiter=',')
            next(reader, None)
            for row in reader:
                hdfs_sheet.append(row)
            counter += 1
        self.workbook.remove_sheet(hdfs_sheet_original)
        log.debug("HDFS report building has been finished")

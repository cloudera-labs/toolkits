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
import datetime
import math

from dateutil import parser
import json
import logging
import os
import os.path
import re
from pathlib import Path

from hdfs_report_builder import HdfsReportBuilder

import cm_client

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


class MacReportBuilder:
    def __init__(self, discovery_bundle_path, workbook):
        self.discovery_bundle_path = discovery_bundle_path
        self.workbook = workbook
        self.deployment = self.__setup_deployment()
        self.hosts = self.__setup_hosts()

    def __setup_deployment(self):
        f = open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/cm_deployment.json'))
        deployment_json = json.load(f)
        return cm_client.ApiClient()._ApiClient__deserialize(deployment_json, 'ApiDeployment2')

    def __setup_hosts(self):
        f = open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/host/read_hosts.json'))
        hosts_json = json.load(f)
        return cm_client.ApiClient()._ApiClient__deserialize(hosts_json, 'ApiHostList')

    def __create_disk_report(self, hostname):
        disk_report_path = os.path.join(self.discovery_bundle_path, f'bundle/{hostname}/df_stdout')
        dist_report = {"disk_all": 0, "disk_used": 0, "disk_available": 0}
        try:
            with open(disk_report_path) as f:
                for line in f:
                    matched = re.match("^(/dev/.*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+%)\s+(.*)\n$", line)
                    if bool(matched):
                        dist_report["disk_all"] = dist_report["disk_all"] + int(matched.group(2)) / math.pow(1024, 2)
                        dist_report["disk_used"] = dist_report["disk_used"] + int(matched.group(3)) / math.pow(1024, 2)
                        dist_report["disk_available"] = dist_report["disk_available"] + int(
                            matched.group(4)) / math.pow(1024, 2)
        except EnvironmentError:
            log.debug(f"Unable to open file, exception happened: {disk_report_path}")
        return dist_report

    def __create_cpu_report(self, hostname):
        cpu_report_path = os.path.join(self.discovery_bundle_path, f'bundle/{hostname}/lscpu_stdout')
        cpu_report = {"cpu_mac_MHz": "-"}
        try:
            with open(cpu_report_path) as f:
                for line in f:
                    matched = re.match("^(CPU max MHz:)\s+(\d+\.?\d*)\n$", line)
                    if bool(matched):
                        cpu_report["cpu_mac_MHz"] = matched.group(2)
        except EnvironmentError:
            log.debug(f"Unable to open file, exception happened: {cpu_report_path}")
        return cpu_report

    def __create_java_report(self, hostname):
        cpu_report_path = os.path.join(self.discovery_bundle_path, f'bundle/{hostname}/java_version')
        java_version = {"java_version": "Not present in diagnostic bundle"}
        try:
            with open(cpu_report_path) as f:
                for line in f:
                    matched = re.match("^(java version)\s+(.*)\n$", line)
                    if bool(matched):
                        java_version['java_version'] = matched.group(2)
        except EnvironmentError:
            log.debug(f"Unable to open file, exception happened: {cpu_report_path}")
        return java_version

    def __create_os_report(self, hostname):
        os_report = {"os_description": "-", "distributor_id": "-",
                     "release": "-"}
        os_report_path = os.path.join(self.discovery_bundle_path, f'bundle/{hostname}/lsb_release_stdout')
        try:
            with open(os_report_path) as f:
                for line in f:
                    matched = re.match("^(Description:)\s+(.*)\n$", line)
                    if bool(matched):
                        os_report["os_description"] = matched.group(2)
                    matched = re.match("^(Distributor ID:)\s+(.*)\n$", line)
                    if bool(matched):
                        os_report["distributor_id"] = matched.group(2)
                    matched = re.match("^(Release:)\s+(.*)\n$", line)
                    if bool(matched):
                        os_report["release"] = matched.group(2)
        except EnvironmentError:
            log.debug(f"Unable to open file, exception happened: {os_report_path}")
        return os_report

    def create_node_report(self):
        log.debug("Node report building has been started.")
        for host in self.hosts.items:
            os_report = self.__create_os_report(host.hostname)
            cpu_report = self.__create_cpu_report(host.hostname)
            java_report = self.__create_java_report(host.hostname)
            disk_report = self.__create_disk_report(host.hostname)
            role_names = list(set(map(lambda role_ref: role_ref.role_name, host.role_refs)))
            service_names = list(set(map(lambda role_ref: role_ref.service_name, host.role_refs)))
            try:
                disk_available = disk_report['disk_available']
                disk_used = disk_report['disk_used']
            except ValueError:
                disk_available = "-"
                disk_used = "-"

            self.workbook['Nodes'].append([
                host.hostname,
                "Not PRESENT" if host.cluster_ref is None else host.cluster_ref.cluster_name,
                os_report['os_description'],
                java_report['java_version'],
                host.num_cores,
                host.num_physical_cores,
                cpu_report['cpu_mac_MHz'],
                host.total_phys_mem_bytes / 10 ** 9,
                disk_available,
                disk_used,
                role_names.__str__(),
                service_names.__str__()
            ])
        log.debug("Node report building has been finished.")

    def create_configuration_report(self):
        log.debug("Configuration report building has been started.")
        for cluster in self.deployment.clusters:

            all_configs = Path(
                os.path.join(self.discovery_bundle_path,
                             "api_diagnostics",
                             "cluster",
                             cluster.display_name.replace(' ', '_'),
                             "configs")).rglob("*.json")

            for service_config in all_configs:
                api_config_list_json = json.load(open(service_config))
                api_config_list = cm_client.ApiClient()._ApiClient__deserialize(api_config_list_json, 'ApiConfigList')
                for api_config in api_config_list.items:
                    self.workbook['Configurations'].append(
                        [cluster.display_name,
                         service_config.parent.parent.name,
                         service_config.parent.name,
                         service_config.name.rstrip(".json"),
                         api_config.name,
                         api_config.value,
                         api_config.default])


    def create_service_metrics_report(self):
        log.debug("Service Metrics report building has been started.")
        service_metrics = Path(os.path.join(self.discovery_bundle_path, "metrics/cluster")).rglob("service_*.json")
        for service_metric in service_metrics:
            f = open(service_metric)
            hosts_json = json.load(f)
            timeseries_resource = cm_client.ApiClient()._ApiClient__deserialize(hosts_json, 'ApiTimeSeriesResponseList')
            list_of_service_metrics = timeseries_resource.items[0].time_series
            for metric in list_of_service_metrics:
                for data in metric.data:
                    self.workbook['Service Metrics'].append([
                        metric.metadata.attributes['clusterDisplayName'],
                        metric.metadata.attributes['serviceName'],
                        metric.metadata.attributes['serviceType'],
                        datetime.datetime.strptime(parser.parse(data.timestamp[:-1]).isoformat(), "%Y-%m-%dT%H:%M:%S"),
                        metric.metadata.metric_name,
                        data.aggregate_statistics.min,
                        data.aggregate_statistics.mean,
                        data.aggregate_statistics.max,
                        metric.metadata.unit_numerators[0]
                    ])
        log.debug("Service Metrics report building has been finished.")

    def create_role_metrics_report(self):
        log.debug("Role CPU Metrics report building has been started.")
        service_metrics = Path(os.path.join(self.discovery_bundle_path, "metrics/host")).rglob(
            "role_cpu_usage_rate.json")
        ws = self.workbook['Role Metrics']
        row = 2

        for service_metric in service_metrics:
            f = open(service_metric)
            hosts_json = json.load(f)
            timeseries_resource = cm_client.ApiClient()._ApiClient__deserialize(hosts_json, 'ApiTimeSeriesResponseList')
            for query_item in timeseries_resource.items:
                list_of_service_metrics = query_item.time_series
                for metric in list_of_service_metrics:
                    for data in metric.data:
                        ws.cell(row=row, column=1).value = metric.metadata.attributes.get('clusterDisplayName', "NONE")
                        ws.cell(row=row, column=2).value = metric.metadata.attributes['hostname']
                        ws.cell(row=row, column=3).value = metric.metadata.attributes['serviceType']
                        ws.cell(row=row, column=4).value = metric.metadata.attributes['roleType']
                        ws.cell(row=row, column=5).value = metric.metadata.alias
                        ws.cell(row=row, column=6).value = datetime.datetime.strptime(
                            parser.parse(data.timestamp[:-1]).isoformat(), "%Y-%m-%dT%H:%M:%S")
                        ws.cell(row=row, column=7).value = data.value
                        ws.cell(row=row, column=8).value = "%"
                        row += 1
        log.debug("Role CPU Metrics report building has been finished.")

    def create_workload_metrics_report(self):
        log.debug("Workload Metrics report building has been started.")
        workload_metrics = Path(os.path.join(self.discovery_bundle_path, "metrics/cluster")).rglob("workload_*.json")
        ws = self.workbook['YARN Workload Metrics']
        row = 2
        for workload_metric in workload_metrics:
            f = open(workload_metric)
            metric_json = json.load(f)
            timeseries_resource = cm_client.ApiClient()._ApiClient__deserialize(metric_json,
                                                                                'ApiTimeSeriesResponseList')
            list_of_workload_metrics = timeseries_resource.items[0].time_series
            for metric in list_of_workload_metrics:
                for data in metric.data:
                    try:
                        ws.cell(row=row, column=1).value = workload_metric.parent.name
                        ws.cell(row=row, column=2).value = metric.metadata.metric_name
                        ws.cell(row=row, column=3).value = datetime.datetime.strptime(
                            parser.parse(data.timestamp[:-1]).isoformat(), "%Y-%m-%dT%H:%M:%S.%f")
                        ws.cell(row=row, column=4).value = data.value
                        ws.cell(row=row, column=5).value = metric.metadata.unit_numerators[0]
                        row += 1
                    except Exception:
                        log.warning(f"Unable to add metric: {data}")
        log.debug("Service Metrics report building has been finished.")

    def create_service_report(self):
        log.debug("Service report building has been started.")
        host_mapping = dict(map(lambda host: (host.host_id, host.hostname), self.deployment.hosts))
        for cluster in self.deployment.clusters:
            for service in cluster.services:
                for role in service.roles:
                    self.workbook['Services'].append([
                        host_mapping[role.host_ref.host_id],
                        cluster.display_name,
                        service.type,
                        role.type
                    ])
        log.debug("Service report building has been finished.")

    def create_hive_metastore_report(self):
        csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/")).rglob("hive_ms.csv")
        for csv_file in csv_files:
            f = open(csv_file)
            reader = csv.reader(f, delimiter=',')
            next(reader, None)
            for row in reader:
                self.workbook['Hive Metastore'].append(row)

    def create_hdfs_report(self, hdfs_report_depth):
        raw_csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/")).rglob("hdfs_fs.csv")
        for raw_csv_file in raw_csv_files:
            HdfsReportBuilder(hdfs_report_depth=hdfs_report_depth).create_csv_report(raw_csv_file)
        self.__create_hdfs_structure_report()
        self.__create_hdfs_modification_time_report()

    def __create_hdfs_structure_report(self):
        csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/")).rglob("hdfs_structure_report.csv")
        hdfs_sheet_original = self.workbook['HDFS Structure Report']
        for csv_file in csv_files:
            hdfs_sheet = self.workbook.copy_worksheet(hdfs_sheet_original)
            hdfs_sheet.title = f"{csv_file.parent.parent.parent.name} HDFS Report"
            f = open(csv_file)
            reader = csv.reader(f, delimiter=',')
            next(reader, None)
            for row in reader:
                hdfs_sheet.append(row)
        self.workbook.remove_sheet(hdfs_sheet_original)

    def __create_hdfs_modification_time_report(self):
        csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/")).rglob("hdfs_modification_times.csv")
        ws = self.workbook['HDFS ModTime Report']
        for csv_file in csv_files:
            f = open(csv_file)
            row_index = 2
            reader = csv.reader(f, delimiter=',')
            next(reader, None)
            for row in reader:
                ws.cell(row=row_index, column=1).value = row[0]
                ws.cell(row=row_index, column=2).value = datetime.datetime.strptime(
                        parser.parse(row[1]).isoformat(), "%Y-%m-%dT%H:%M:%S")
                ws.cell(row=row_index, column=3).value = int(row[2])
                row_index += 1

    def create_sentry_policies_report(self):
        csv_files = Path(os.path.join(self.discovery_bundle_path, "workload/")).rglob("sentry_policies.csv")
        for csv_file in csv_files:
            f = open(csv_file)
            reader = csv.reader(f, delimiter=',')
            next(reader, None)
            for row in reader:
                self.workbook['Sentry Policies'].append(row)

    def create_cm_report(self):
        cm_url = open(os.path.join(self.discovery_bundle_path, "cm_url")).readline()
        cm_version_json = json.load(
            open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/cluster/cm_version.json')))
        cm_version = cm_client.ApiClient()._ApiClient__deserialize(cm_version_json, 'ApiVersionInfo')
        cm_config_json = json.load(
            open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/cluster/cm_config.json')))
        cm_config = cm_client.ApiClient()._ApiClient__deserialize(cm_config_json, 'ApiConfigList')
        kerberos_config_json = json.load(
            open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/cluster/kerberos_info.json')))
        kerberos_config = cm_client.ApiClient()._ApiClient__deserialize(kerberos_config_json, 'ApiKerberosInfo')

        web_tls = next(filter(lambda config: config.name == "WEB_TLS", cm_config.items))
        agent_tls = next(filter(lambda config: config.name == "AGENT_TLS", cm_config.items))
        auto_tls_type = next(filter(lambda config: config.name == "AUTO_TLS_TYPE", cm_config.items), None)
        auth_backend_order_config = next(filter(lambda config: config.name == "AUTH_BACKEND_ORDER", cm_config.items))
        auth_backend_order = auth_backend_order_config.value if auth_backend_order_config.value else auth_backend_order_config.default
        ldap_type_config = next(filter(lambda config: config.name == "LDAP_TYPE", cm_config.items))
        if auth_backend_order == "DB_ONLY":
            external_auth = "DB_ONLY"
        else:
            external_auth = ldap_type_config.value if ldap_type_config.value else ldap_type_config.default
        self.workbook["CM"].append(
            [
                self.deployment.timestamp,
                cm_url,
                cm_version.version,
                web_tls.value if web_tls.value else "Not enabled",
                agent_tls.value if agent_tls.value else "Not enabled",
                external_auth,
                auto_tls_type.value if auto_tls_type else "Not enabled",
                kerberos_config.kerberized if kerberos_config.kerberized else "Not enabled",
                kerberos_config.kdc_type if kerberos_config.kdc_type else "Not enabled",
                kerberos_config.kdc_host if kerberos_config.kdc_host else "Not enabled",
                kerberos_config.kerberos_realm if kerberos_config.kerberos_realm else "Not enabled"
            ]
        )

    def create_cluster_report(self):
        for cluster in self.deployment.clusters:
            cluster_hosts = list(filter(lambda host: ("Not PRESENT" if host.cluster_ref is None else host.cluster_ref.cluster_name) == cluster.name, self.hosts.items))
            hms_report_map = self.__fetch_latest_hms_deployment_info(cluster.display_name)
            host_assignments, role_types = self.__create_role_assignment_map(cluster)
            hdfs_data = self.__get_latest_hdfs_map(cluster.display_name)
            cluster_hardware = self.__get_cluster_hardware_map(cluster_hosts, host_assignments['worker'])
            activated_cdh = next(filter(lambda parcel: parcel.stage == "ACTIVATED" and parcel.product == "CDH",
                                        cluster.parcels))

            self.workbook["Clusters"].append(
                [
                    cluster.display_name,
                    activated_cdh.version,
                    hdfs_data['dfs_capacity_used'],
                    hdfs_data['dfs_capacity'],
                    cluster_hardware["total_cpu_cores"],
                    cluster_hardware["total_memory"],
                    cluster_hardware["total_worker_cpu_cores"],
                    cluster_hardware["total_worker_memory"],
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

    def __fetch_latest_hms_deployment_info(self, cluster_name):
        table_counter = {"table": 0, "view": 0}
        hms_csv_path = f"{self.discovery_bundle_path}/workload/{cluster_name.replace(' ', '_')}/service/HIVE-1/hive_ms.csv"
        if not os.path.exists(hms_csv_path):
            return table_counter
        f = open(hms_csv_path)
        reader = csv.reader(f, delimiter=',')
        next(reader, None)
        for row in reader:
            if "MANAGED_TABLE" in row or "EXTERNAL_TABLE" in row:
                table_counter['table'] = table_counter['table'] + 1
            elif "VIRTUAL_VIEW" in row:
                table_counter['view'] = table_counter['view'] + 1
        return table_counter

    def __create_role_assignment_map(self, cluster):
        host_mapping = dict(map(lambda host: (host.host_id, host.hostname), self.deployment.hosts))
        host_assignments = {
            'master': [],
            "utility": [],
            "gateway": [],
            "worker": []
        }
        role_types = []
        for service in cluster.services:
            for role in service.roles:
                role_host = host_mapping[role.host_ref.host_id]
                for key, role_assignment_types in role_assignments.items():
                    role_types.append(role.type)
                    if role.type in role_assignment_types and role_host not in host_assignments[key]:
                        host_assignments[key].append(role_host)

        return host_assignments, role_types

    def __get_latest_hdfs_map(self, cluster_name):
        hdfs_data = {
            "dfs_capacity": 0,
            "dfs_capacity_used": 0
        }
        hdfs_metric_path = f"{self.discovery_bundle_path}/metrics/cluster/{cluster_name.replace(' ', '_')}/service/HDFS"
        if not os.path.exists(hdfs_metric_path):
            return hdfs_data
        for hdfs_metric in hdfs_data.keys():
            f = open(os.path.join(hdfs_metric_path, f"service_{hdfs_metric}.json"))
            metric_json = json.load(f)
            timeseries_resource = cm_client.ApiClient()._ApiClient__deserialize(metric_json,
                                                                                'ApiTimeSeriesResponseList')
            list_of_service_metrics = timeseries_resource.items[0].time_series
            for metric in list_of_service_metrics:
                if metric.data:
                    latest_metric = metric.data[-1]
                    log.debug(
                        f"Latest timestamp for {hdfs_metric}: {latest_metric.timestamp}, value: {int(latest_metric.value) / 10 ** 12} TB")
                    hdfs_data[hdfs_metric] += int(latest_metric.value) / 10 ** 12
        return hdfs_data

    def __get_cluster_hardware_map(self, cluster_hosts, worker_hosts_names):
        cluster_hardware = {
            "total_cpu_cores": 0,
            "total_memory": 0,
            "total_worker_cpu_cores": 0,
            "total_worker_memory": 0
        }
        for host in cluster_hosts:
            cluster_hardware['total_cpu_cores'] += host.num_cores
            cluster_hardware['total_memory'] += host.total_phys_mem_bytes / 10 ** 9
        for worker_host_name in worker_hosts_names:
            worker_host = next(filter(lambda host: host.hostname == worker_host_name, self.hosts.items))
            cluster_hardware['total_worker_cpu_cores'] += worker_host.num_cores
            cluster_hardware['total_worker_memory'] += worker_host.total_phys_mem_bytes / 10 ** 9
        return cluster_hardware

    def __get_cluster_hardware_map(self, cluster_hosts, worker_hosts_names):
        cluster_hardware = {
            "total_cpu_cores": 0,
            "total_memory": 0,
            "total_worker_cpu_cores": 0,
            "total_worker_memory": 0
        }
        for host in cluster_hosts:
            cluster_hardware['total_cpu_cores'] += host.num_cores
            cluster_hardware['total_memory'] += host.total_phys_mem_bytes / 10 ** 9
        for worker_host_name in worker_hosts_names:
            worker_host = next(filter(lambda host: host.hostname == worker_host_name, self.hosts.items))
            cluster_hardware['total_worker_cpu_cores'] += worker_host.num_cores
            cluster_hardware['total_worker_memory'] += worker_host.total_phys_mem_bytes / 10 ** 9
        return cluster_hardware

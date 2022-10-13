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
import logging
import os
from pathlib import Path

import cm_client

log = logging.getLogger('main')

desired_rollup = 'HOURLY'


def create_directory(dir_path):
    path = Path(dir_path)
    path.mkdir(parents=True, exist_ok=True)


class CmMetricsExtractor:
    def __init__(self, output_dir, cluster_names, start_timestamp, end_timestamp):
        self.metrics_output_dir = os.path.join(output_dir, 'metrics')
        self.time_series_resource_api = cm_client.TimeSeriesResourceApi()
        self.clusters_resource_api = cm_client.ClustersResourceApi()
        self.hosts_resource_api = cm_client.HostsResourceApi()
        self.services_resource_api = cm_client.ServicesResourceApi()
        self.cluster_names = cluster_names
        self.start_timestamp = start_timestamp
        self.end_timestamp = end_timestamp

    def dump_json(self, path, api_response):
        json_dict = cm_client.ApiClient().sanitize_for_serialization(api_response)
        f = open(path, "w")
        f.write(json.dumps(json_dict))

    def collect_metrics(self):
        log.info("CM metrics collection started.")
        self.collect_host_metrics()
        self.collect_host_specific_role_cpu_metrics()
        for cluster_name in self.cluster_names:
            self.collect_hive_workload_metrics(cluster_name)
            self.collect_spark_workload_metrics(cluster_name)
            self.collect_mapreduce_workload_metrics(cluster_name)
            self.collect_hdfs_metrics(cluster_name)
            self.collect_yarn_metrics(cluster_name)
            self.collect_impala_metrics(cluster_name)
            self.collect_kudu_metrics(cluster_name)
            self.collect_solr_metrics(cluster_name)
            self.collect_hue_metrics(cluster_name)
        log.info("CM metrics collection finished.")

    def collect_host_metrics(self):
        log.debug("Collecting host related metrics.")
        hosts_api_response = self.hosts_resource_api.read_hosts(view="FULL")
        metrics = [
            "cpu_percent",
            "swap_used",
            "physical_memory_used",
            "physical_memory_total",
            "physical_memory_cached",
            "physical_memory_buffers",
            "mem_rss",
            "total_bytes_receive_rate_across_network_interfaces",
            "total_bytes_transmit_rate_across_network_interfaces"
        ]
        for host in hosts_api_response.items:
            output_path = os.path.join(os.path.join(self.metrics_output_dir, "host", host.hostname))
            create_directory(output_path)
            for metric in metrics:
                log.debug(f"Collecting host related {metric} metric from cluster: {host.hostname}")
                query = "SELECT " \
                        f"{metric} " \
                        f"WHERE category = 'host' AND entityName='{host.host_id}'"
                host_cpu_metrics = self.time_series_resource_api.query_time_series(desired_rollup=desired_rollup,
                                                                                   _from=self.start_timestamp,
                                                                                   must_use_desired_rollup=True,
                                                                                   query=query,
                                                                                   to=self.end_timestamp)
                self.dump_json(os.path.join(output_path, f"{metric}.json"), host_cpu_metrics)

    def collect_host_specific_role_cpu_metrics(self):
        log.debug("Collecting host related metrics.")
        hosts_api_response = self.hosts_resource_api.read_hosts(view="FULL")
        for host in hosts_api_response.items:
            output_path = os.path.join(os.path.join(self.metrics_output_dir, "host", host.hostname))
            create_directory(output_path)
            log.debug(f"Collecting host related role_cpu_usage_rate metric from cluster: {host.hostname}")
            query = 'select ' \
                    '(cpu_user_rate / getHostFact(numCores, 1) * 100) + (cpu_system_rate / getHostFact(numCores, 1) * 100) AS role_total_cpu_usage ' \
                    'WHERE category = role ' \
                    'AND (serviceType RLIKE "^(?!YARN).*") ' \
                    'AND (serviceType RLIKE "^(?!MGMT).*") ' \
                    f'AND hostId = {host.host_id}; ' \
                    'select ' \
                    '(cpu_user_with_descendants_rate / getHostFact(numCores, 1) * 100) + (cpu_system_with_descendants_rate / getHostFact(numCores, 1) * 100) AS role_total_cpu_usage ' \
                    'WHERE category = role and serviceType = YARN ' \
                    f'AND hostId = {host.host_id}; '
            host_cpu_metrics = self.time_series_resource_api.query_time_series(desired_rollup=desired_rollup,
                                                                               _from=self.start_timestamp,
                                                                               must_use_desired_rollup=True,
                                                                               query=query,
                                                                               to=self.end_timestamp)
            self.dump_json(os.path.join(output_path, "role_cpu_usage_rate.json"), host_cpu_metrics)

    def get_service_by_type(self, cluster_name, service_type):
        if service_type == 'MAPREDUCE':
            return service_type
        services_response = self.services_resource_api.read_services(cluster_name)
        return next(filter(lambda service: service.type == service_type, services_response.items), None)

    def collect_service_metrics(self, cluster_name, service_type, query, metric_name):
        service = self.get_service_by_type(cluster_name, service_type)
        if not service:
            log.debug(f"{service_type} service is not found on cluster: {cluster_name}")
            return
        log.debug(
            f"Collecting {service_type} related {metric_name} metric from cluster: {cluster_name}")
        try:
            metrics = self.time_series_resource_api.query_time_series(desired_rollup=desired_rollup,
                                                                      _from=self.start_timestamp,
                                                                      must_use_desired_rollup=True,
                                                                      query=query,
                                                                      to=self.end_timestamp)
            output_path = os.path.join(self.metrics_output_dir, "cluster", cluster_name.replace(" ", "_"), "service", service_type)
            create_directory(output_path)
            self.dump_json(os.path.join(output_path, f"{metric_name}.json"), metrics)
        except:
            log.warning(f"Unable to fetch {metric_name} from {cluster_name}")

    def collect_hdfs_metrics(self, cluster_name):
        service_type = "HDFS"
        metrics = ["dfs_capacity", "dfs_capacity_used", "blocks_total", "files_total"]
        for metric in metrics:
            query = "SELECT " \
                    f"{metric} " \
                    f"WHERE clusterDisplayName = '{cluster_name}' AND serviceType='{service_type}' AND category = 'service'"
            self.collect_service_metrics(cluster_name, service_type, query, f"service_{metric}")

    def collect_yarn_metrics(self, cluster_name):
        service_type = "YARN"
        service_metrics = [
            "total_available_vcores_across_yarn_pools",
            "total_allocated_vcores_across_yarn_pools",
            "total_pending_vcores_across_yarn_pools",
            "total_reserved_vcores_across_yarn_pools",
            "total_available_memory_mb_across_yarn_pools",
            "total_allocated_memory_mb_across_yarn_pools",
            "total_containers_running_across_nodemanagers",
            "pending_containers_cumulative",
            "apps_running_cumulative",
            "apps_killed_cumulative_rate",
            "apps_failed_cumulative_rate"
        ]
        for service_metric in service_metrics:
            query = "SELECT " \
                    f"{service_metric} " \
                    f" WHERE clusterDisplayName = '{cluster_name}' AND serviceType='{service_type}'"
            self.collect_service_metrics(cluster_name, service_type, query, service_metric)

        pool_metrics = [
            "pending_containers_cumulative",
            "apps_running_cumulative",
            "apps_killed_cumulative_rate",
            "apps_failed_cumulative_rate"
        ]
        for pool_metric in pool_metrics:
            query = "SELECT " \
                    f"{pool_metric} " \
                    f" WHERE clusterDisplayName = '{cluster_name}' AND serviceType='{service_type}' AND entityName RLIKE '.*root$' "
            self.collect_service_metrics(cluster_name, service_type, query, pool_metric)

    def collect_impala_metrics(self, cluster_name):
        service_type = "IMPALA"
        metrics = [
            "total_num_queries_rate_across_impalads",
            "queries_oom_rate",
            "queries_successful_rate",
            "queries_spilled_memory_rate"
        ]
        for metric in metrics:
            query = "SELECT " \
                    f"{metric} " \
                    f" WHERE clusterDisplayName = '{cluster_name}' AND serviceType='{service_type}' AND category = 'service'"
            self.collect_service_metrics(cluster_name, service_type, query, f"service_{metric}")

        workload_metrics = ""

    def collect_kudu_metrics(self, cluster_name):
        service_type = "KUDU"
        metrics = [
            "total_kudu_on_disk_size_across_kudu_replicas",
            "total_kudu_rows_upserted_rate_across_kudu_replicas",
            "total_kudu_rows_updated_rate_across_kudu_replicas",
            "total_kudu_rows_deleted_rate_across_kudu_replicas",
            "total_kudu_rows_inserted_rate_across_kudu_replicas",
            "total_kudu_scanner_bytes_scanned_from_disk_rate_across_kudu_replicas",
            "total_kudu_scanner_bytes_returned_rate_across_kudu_replicas"
        ]
        for metric in metrics:
            query = "SELECT " \
                    f"{metric} " \
                    f" WHERE clusterDisplayName = '{cluster_name}' AND serviceType='{service_type}' AND category = 'service'"
            self.collect_service_metrics(cluster_name, service_type, query, f"service_{metric}")

    def collect_solr_metrics(self, cluster_name):
        service_type = "SOLR"
        metrics = [
            "total_index_size_across_solr_replicas",
            "index_size_across_solr_replicas",
            "total_num_docs_across_solr_replicas",
            "num_docs_across_solr_replicas",
            "total_select_requests_rate_across_solr_replicas",
            "select_requests_rate_across_solr_replicas",
            "total_query_requests_rate_across_solr_replicas",
            "query_requests_rate_across_solr_replicas",
            "total_update_requests_rate_across_solr_replicas",
            "update_requests_rate_across_solr_replicas",
            "select_avg_time_per_request_across_solr_replicas",
            "query_avg_time_per_request_across_solr_replicas",
            "update_avg_time_per_request_across_solr_replicas"
        ]
        for metric in metrics:
            query = "SELECT " \
                    f"{metric} " \
                    f" WHERE clusterDisplayName = '{cluster_name}' AND serviceType='{service_type}' AND category = 'service'"
            self.collect_service_metrics(cluster_name, service_type, query, f"service_{metric}")

    def collect_hue_metrics(self, cluster_name):
        service_type = "HUE"
        hue_server_role_type = "HUE_SERVER"
        metrics = [
            "hue_users_active"
        ]
        for metric in metrics:
            query = f"SELECT {metric} WHERE category = ROLE and roleType = {hue_server_role_type}"
            self.collect_service_metrics(cluster_name, service_type, query, f"service_{metric}")

    def collect_hive_workload_metrics(self, cluster_name):
        hive_service_type = "HIVE"

        metrics = [
            "allocated_memory_seconds",
            "allocated_vcore_seconds"
        ]
        for metric in metrics:
            query = f'select {metric} from YARN_APPLICATIONS where hive_query_id RLIKE ".*" OR application_type = "TEZ"'
            self.collect_service_metrics(cluster_name, hive_service_type, query, f"workload_{metric}")

    def collect_spark_workload_metrics(self, cluster_name):
        hive_service_type = "SPARK_ON_YARN"

        metrics = [
            "allocated_memory_seconds",
            "allocated_vcore_seconds"
        ]
        for metric in metrics:
            query = f'select {metric} from YARN_APPLICATIONS where applicationType = SPARK'
            self.collect_service_metrics(cluster_name, hive_service_type, query, f"workload_{metric}")

    def collect_mapreduce_workload_metrics(self, cluster_name):
        hive_service_type = "MAPREDUCE"
        metrics = [
            "allocated_memory_seconds",
            "allocated_vcore_seconds"
        ]
        for metric in metrics:
            query = f'select {metric} from YARN_APPLICATIONS where applicationType = MAPREDUCE and hive_query_id is NULL'
            self.collect_service_metrics(cluster_name, hive_service_type, query, f"workload_{metric}")

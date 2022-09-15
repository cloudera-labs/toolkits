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

import calendar
import datetime
import logging.config
import os
import os.path
import re
import shutil
import tarfile
import zipfile
from pathlib import Path
from threading import Thread

import cm_client

from discovery_bundle_builder_utils import create_directory, _make_tarfile, check_if_dir_exists, copy_to_local, \
    retrieve_hdfs_username_group

log = logging.getLogger('main')


class YarnWorkloadExtractor:
    def __init__(self, output_dir, time_range_in_days):
        self.output_dir = output_dir
        self.time_range_in_days = time_range_in_days
        self.services_resource = cm_client.ServicesResourceApi()
        self.role_config_groups_resource = cm_client.RoleConfigGroupsResourceApi()
        self.workload_dates = self.__get_workload_dates()

    def collect_workloads(self, workloads_to_collect):
        cm_deployment = cm_client.ClouderaManagerResourceApi().get_deployment2()
        for cluster in cm_deployment.clusters:
            self.collect_workloads_from_cluster(cluster, workloads_to_collect)

    def collect_workloads_from_cluster(self, cluster, workloads_to_collect):
        cluster_name = cluster.display_name
        log.debug(f"Checking if HDFS is deployed on {cluster_name}")
        hdfs_service = next(filter(lambda service: service.type == "HDFS", cluster.services), None)
        if not hdfs_service:
            log.debug(f"HDFS is not deployed on cluster service deployed on cluster: {cluster_name}")
            return
        log.debug(f"HDFS service deployed on cluster: {cluster_name}")
        client_config_path = self.fetch_client_config(cluster_name, hdfs_service.name)
        retrieve_hdfs_username_group(client_config_path)
        log.debug(f"Extracted client config path: {client_config_path}")
        workload_extraction_threads = []
        if "spark" in workloads_to_collect:
            workload_extraction_threads.append(
                Thread(target=self.collect_spark_history, args=(cluster, client_config_path,),
                       name=f"{cluster_name}-spark_history_thread"))
        if "mapreduce" in workloads_to_collect:
            workload_extraction_threads.append(
                Thread(target=self.collect_mapreduce_history, args=(cluster, client_config_path,),
                       name=f"{cluster_name}-mapreduce_history_thread"))
        if "tez" in workloads_to_collect:
            workload_extraction_threads.append(
                Thread(target=self.collect_tez_history, args=(cluster, client_config_path,),
                       name=f"{cluster_name}-tez_history_thread"))
        for thread in workload_extraction_threads:
            thread.start()
        for thread in workload_extraction_threads:
            thread.join()
        log.info(f"Collected workloads from {cluster.display_name}.")

    def fetch_client_config(self, cluster_name, hdfs_service_name):
        response = self.services_resource.get_client_config(cluster_name=cluster_name,
                                                            service_name=hdfs_service_name,
                                                            _preload_content=False)
        client_config_dir = os.path.join("/tmp", "workload", cluster_name.replace(" ", "_"))
        create_directory(client_config_dir)
        with open(os.path.join(client_config_dir, "client_config.zip"), 'wb') as fd:
            fd.write(response.data)
        with zipfile.ZipFile(os.path.join(client_config_dir, "client_config.zip"), 'r') as zip_ref:
            zip_ref.extractall(client_config_dir)
        dest_directory = next(Path(client_config_dir).rglob("core-site.xml")).parent
        log.debug(f"Destination directory: {dest_directory}")
        self.update_ssl_config(dest_directory)
        return dest_directory.__str__()

    def update_ssl_config(self, destination_path):
        ssl_config_path = None
        truststores = Path("/var/run/cloudera-scm-agent/process/").rglob("*truststore*.jks")
        for truststore in truststores:
            configs = Path(truststore.parent).rglob("ssl-client.xml")
            for config in configs:
                ssl_config_path = config
                break
            if ssl_config_path:
                break
        if not ssl_config_path and os.path.exists("/etc/hadoop/conf/ssl-client.xml"):
            ssl_config_path = "/etc/hadoop/conf/ssl-client.xml"
        try:
            log.debug(f"SSL config path: {ssl_config_path}")
            log.debug(f"copying to {os.path.join(destination_path, 'ssl-client.xml')}")
            shutil.copy(ssl_config_path,
                        os.path.join(destination_path, "ssl-client.xml"))
        except:
            log.error(f"Unable to copy file from source: {ssl_config_path}")

    def collect_spark_history(self, cluster, client_config_path):
        spark_services = list(filter(lambda service: "SPARK" in service.type, cluster.services))
        if not spark_services:
            log.debug(f"SPARK is not deployed on cluster service deployed on cluster: {cluster.display_name}")
            return
        log.debug(f"SPARK service is deployed on {cluster.display_name}")

        for spark_service in spark_services:
            spark_service_configs = self.services_resource.read_service_config(cluster.display_name, spark_service.name,
                                                                               view="FULL").items
            spark_log_history_dir = self.__get_config_value(spark_service_configs, "spark_history_log_dir")
            check_if_dir_exists(client_config_path, spark_log_history_dir)
            spark_output_dir = os.path.join(self.output_dir, "workload", cluster.display_name.replace(" ", "_"), "service",
                                            spark_service.name)
            create_directory(spark_output_dir)
            copy_to_local(spark_log_history_dir, spark_output_dir, client_config_path)
            target_file = os.path.join(spark_output_dir, "SPARK_APP_HISTORY.tar.gz")
            _make_tarfile(target_file, spark_output_dir)

    def collect_tez_history(self, cluster, client_config_path):
        tez_service = self.__get_service_by_service_type(cluster, "TEZ")
        hive_on_tez = self.__get_service_by_service_type(cluster, "HIVE_ON_TEZ")
        if not tez_service or not hive_on_tez:
            return
        tez_service_configs = self.services_resource.read_service_config(cluster.display_name, tez_service.name,
                                                                         view="FULL").items
        tez_log_history_dir = self.__get_config_value(tez_service_configs, "tez.history.logging.proto-base-dir")
        hive_on_tez_service_configs = self.services_resource.read_service_config(cluster.display_name, hive_on_tez.name,
                                                                                 view="FULL").items
        hive_on_tez_log_history_dir = self.__get_config_value(hive_on_tez_service_configs,
                                                              "hive_hook_proto_base_directory")

        tez_output_dir = os.path.join(self.output_dir, "workload", cluster.display_name.replace(" ", "_"), "service",
                                      tez_service.name)

        self.collect_hive_on_tez_files(tez_output_dir, hive_on_tez_log_history_dir, client_config_path)
        self.collect_tez_files(tez_output_dir, tez_log_history_dir, client_config_path)

    def collect_tez_files(self, tez_output_dir, tez_location, client_config):
        app_data = "app_data"
        dag_data = "dag_data"
        dag_meta = "dag_meta"
        tez_protobuf = "tez_protobuf_app_files"
        create_directory(f"{tez_output_dir}/{tez_protobuf}/sys.db/{app_data}")
        create_directory(f"{tez_output_dir}/{tez_protobuf}/sys.db/{dag_data}")
        create_directory(f"{tez_output_dir}/{tez_protobuf}/sys.db/{dag_meta}")
        for directory_date in self.workload_dates:
            if check_if_dir_exists(client_config,
                                   os.path.join(tez_location, app_data,
                                                f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}")):
                copy_to_local(
                    os.path.join(tez_location, app_data,
                                 f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}"),
                    f"{tez_output_dir}/{tez_protobuf}/sys.db/{app_data}",
                    client_config)
            if check_if_dir_exists(client_config,
                                   os.path.join(tez_location, dag_data,
                                                f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}")):
                copy_to_local(
                    os.path.join(tez_location, dag_data,
                                 f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}"),
                    f"{tez_output_dir}/{tez_protobuf}/sys.db/{dag_data}",
                    client_config)
            if check_if_dir_exists(client_config,
                                   os.path.join(tez_location, dag_meta,
                                                f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}")):
                copy_to_local(
                    os.path.join(tez_location, dag_meta,
                                 f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}"),
                    f"{tez_output_dir}/{tez_protobuf}/sys.db/{dag_meta}",
                    client_config)
        target_file = os.path.join(f"{tez_output_dir}/{tez_protobuf}", "TEZ_PROTOBUF_APPLICATIONS.tar.gz")
        _make_tarfile(target_file, f"{tez_output_dir}/{tez_protobuf}")

    def collect_hive_on_tez_files(self, tez_output_dir, hive_on_tez_location, client_config):
        hive_on_tez_protobuf = "hive_on_tez_protoquery_databuf_app_files"
        create_directory(f"{tez_output_dir}/{hive_on_tez_protobuf}/query_data")
        for directory_date in self.workload_dates:
            if check_if_dir_exists(client_config,
                                   os.path.join(hive_on_tez_location,
                                                f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}")):
                copy_to_local(
                    os.path.join(hive_on_tez_location,
                                 f"date={directory_date['year']}-{directory_date['month']}-{directory_date['day']}"),
                    f"{tez_output_dir}/{hive_on_tez_protobuf}/query_data",
                    client_config)
        target_file = os.path.join(f"{tez_output_dir}/{hive_on_tez_protobuf}", "HIVE_PROTOBUF_APPLICATIONS.tar.gz")
        _make_tarfile(target_file, f"{tez_output_dir}/{hive_on_tez_protobuf}")

    def collect_mapreduce_history(self, cluster, client_config_path):
        mapreduce_logs_dir = self.fetch_mapreduce_history_dir_config_value(cluster)
        mapreduce_output_dir = os.path.join(self.output_dir, "workload", cluster.display_name.replace(" ", "_"),
                                            "service",
                                            "MAPREDUCE")
        for directory_date in self.workload_dates:
            create_directory(f"{mapreduce_output_dir}/done/{directory_date['year']}/{directory_date['month']}")
            if check_if_dir_exists(client_config_path,
                                   f"{mapreduce_logs_dir}/{directory_date['year']}/{directory_date['month']}/{directory_date['day']}"):
                copy_to_local(
                    f"{mapreduce_logs_dir}/{directory_date['year']}/{directory_date['month']}/{directory_date['day']}",
                    f"{mapreduce_output_dir}/done/{directory_date['year']}/{directory_date['month']}",
                    client_config_path)
        target_file = os.path.join(mapreduce_output_dir, "MR_JOB_HISTORY.tar.gz")
        _make_tarfile(target_file, mapreduce_output_dir)

    def fetch_mapreduce_history_dir_config_value(self, cluster):
        yarn_service = self.__get_service_by_service_type(cluster, "YARN")
        if not yarn_service:
            return
        yarn_service_config = self.services_resource.read_service_config(cluster.display_name, yarn_service.name,
                                                                         view="FULL").items
        mapreduce_safety_valve = self.__get_config_value(yarn_service_config, "yarn_service_mapred_safety_valve")
        if mapreduce_safety_valve and "mapreduce.jobhistory.done-dir" in mapreduce_safety_valve:
            log.debug(f"Fetching mapreduce history dir from safety valve")
            matched = re.match(
                "(.*)\s?(<name>mapreduce.jobhistory.done-dir</name>)\s?(<value>)\s?([\/\w\.-]*)\s?(</value>)\s?(.*)",
                mapreduce_safety_valve)
            if bool(matched):
                mapreduce_log_dir = matched.group(4)
                log.info(f"Mapreduce log dir: {mapreduce_log_dir}")
                return mapreduce_log_dir
            else:
                log.error(f"Could not fetch Mapreduce log dir from: {mapreduce_safety_valve}")
        log.debug(f"Fetching mapreduce history dir from service config: yarn_app_mapreduce_am_staging_dir")
        role_config_groups = self.role_config_groups_resource.read_role_config_groups(cluster.display_name,
                                                                                      yarn_service.name)
        job_history_role_config_group = next(
            filter(lambda role_config_group: "JOBHISTORY" == role_config_group.role_type, role_config_groups.items),
            None)
        job_history_configs = self.role_config_groups_resource.read_config(cluster_name=cluster.display_name,
                                                                           service_name=yarn_service.name,
                                                                           role_config_group_name=job_history_role_config_group.name,
                                                                           view="FULL").items
        yarn_app_mapreduce_am_staging_dir = self.__get_config_value(job_history_configs,
                                                                    "yarn_app_mapreduce_am_staging_dir")
        return os.path.join(yarn_app_mapreduce_am_staging_dir, "history", "done")

    def __get_workload_dates(self):
        directory_dates = []
        start_date = datetime.date.today()
        end_date = start_date - datetime.timedelta(days=self.time_range_in_days - 1)
        log.debug(f"Staring from: {start_date}, latest mapreduce history dir is created at : {end_date}")
        range_pointer = self.time_range_in_days
        date_pointer = start_date
        while range_pointer > 0:
            days_in_month = calendar.monthrange(date_pointer.year, date_pointer.month)[1]
            if date_pointer.year == date_pointer.year and date_pointer.month == start_date.month and date_pointer.day <= range_pointer:
                month = str(date_pointer.month) if date_pointer.month >= 10 else f"0{date_pointer.month}"
                directory_dates.append({"year": date_pointer.year, "month": month, "day": "*"})
                date_pointer = date_pointer - datetime.timedelta(days=start_date.day)
                range_pointer = range_pointer - start_date.day
            elif days_in_month < range_pointer:
                month = str(date_pointer.month) if date_pointer.month >= 10 else f"0{date_pointer.month}"
                directory_dates.append({"year": date_pointer.year, "month": month, "day": "*"})
                date_pointer = date_pointer - datetime.timedelta(days=days_in_month)
                range_pointer = range_pointer - days_in_month
            else:
                for i in range(0, range_pointer):
                    delta = datetime.timedelta(days=i)
                    calculated_date = date_pointer - delta
                    month = str(calculated_date.month) if calculated_date.month >= 10 else f"0{calculated_date.month}"
                    day = str(calculated_date.day) if calculated_date.day >= 10 else f"0{calculated_date.day}"
                    directory_dates.append({"year": date_pointer.year, "month": month, "day": day})
                range_pointer = 0
        log.debug(f"Directories to download created at: {directory_dates}")
        return directory_dates

    def __get_service_by_service_type(self, cluster, service_type):
        fetched_service = next(filter(lambda service: service_type == service.type, cluster.services), None)
        if not fetched_service:
            log.debug(f"{service_type} is not deployed on cluster service deployed on cluster: {cluster.display_name}")
            return
        log.debug(f"{service_type} service deployed on cluster: {cluster.display_name}")
        return fetched_service

    @staticmethod
    def __get_config_value(all_config, config_name):
        config = next(filter(lambda service_config: service_config.name == config_name, all_config))
        log.debug(
            f"Config name: {config.name}, value: {config.value if not config.sensitive else '*******'}, default value: {config.default}")
        config_value = config.value if config.value else config.default
        log.debug(f"Using {config_value if not config.sensitive else '*******'} for config {config.name}")
        return config_value


class ImpalaProfilesExtractor:
    def __init__(self, output_dir):
        self.output_dir = output_dir
        self.cloudera_manager_resource = cm_client.ClouderaManagerResourceApi()

    def collect_impala_profiles(self):
        log.info("Started IMPALA workload extraction")
        cm_deployment = self.cloudera_manager_resource.get_deployment2()
        for cluster in cm_deployment.clusters:
            log.debug(f"Checking if Impala daemons are deployed on {cluster.display_name}")
            for service in cluster.services:
                impala_demon_roles = list(filter(lambda rcg: rcg.type == "IMPALAD", service.roles))
                if impala_demon_roles:
                    log.debug(
                        f"Impala Daemon roles deployed on {cluster.display_name} cluster under {service.name} service.")
                    impalad_output_dir = os.path.join(self.output_dir, "workload",
                                                      cluster.display_name.replace(" ", "_"), "service",
                                                      service.name)
                    create_directory(impalad_output_dir)

                    self.collect_impala_profiles_for_role(cm_deployment.hosts, impala_demon_roles, impalad_output_dir)
                    break

    def collect_impala_profiles_for_role(self, cluster_hosts, impala_demon_roles, impalad_output_dir):
        impalad_profile_dir_prefix = "var/log/impalad"
        non_empty_impala_profiles = []
        for impala_demon_role in impala_demon_roles:
            impala_host = next(filter(lambda host: host.host_id == impala_demon_role.host_ref.host_id, cluster_hosts),
                               None)
            impala_profile_parent_path = os.path.join(self.output_dir, "extracted_raw_diagnostic_bundle",
                                                      "impala-query-logs",
                                                      f"{impala_host.hostname}-{impala_host.ip_address}")
            log.debug(f"impala_profile_parent_path: {impala_profile_parent_path}")
            all_impala_profiles_for_role = Path(impala_profile_parent_path).rglob("impala_profile*")
            non_empty_impala_profiles_for_role = list(
                filter(lambda profile: os.stat(profile).st_size != 0, all_impala_profiles_for_role))
            non_empty_impala_profiles.extend(non_empty_impala_profiles_for_role)
        impala_profiles_dest = os.path.join(impalad_output_dir, impalad_profile_dir_prefix)
        Path(impala_profiles_dest).mkdir(parents=True, exist_ok=True)
        for i in non_empty_impala_profiles:
            shutil.copy(i, impala_profiles_dest)
        with tarfile.open(impalad_output_dir + "/IMPALA_PROFILE_LOGS.tar.gz", "w:gz") as tar:
            for i in non_empty_impala_profiles:
                tar.add(i, arcname=impalad_profile_dir_prefix + "/" + os.path.basename(i))

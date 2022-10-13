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


def dump_json(path, api_response):
    json_dict = cm_client.ApiClient().sanitize_for_serialization(api_response)
    f = open(path, "w")
    f.write(json.dumps(json_dict))
    log.debug(f"Api response stored in: {path}")


def create_directory(dir_path):
    path = Path(dir_path)
    path.mkdir(parents=True, exist_ok=True)


class CmApiExtractor:
    def __init__(self, output_dir, sensitive_values_redacted):
        self.api_output_dir = os.path.join(output_dir, 'api_diagnostics')
        self.hosts_resource_api = cm_client.HostsResourceApi()
        self.clusters_resource = cm_client.ClustersResourceApi()
        self.cloudera_manager_resource = cm_client.ClouderaManagerResourceApi()
        self.services_resource = cm_client.ServicesResourceApi()
        self.roles_resource = cm_client.RolesResourceApi()
        self.role_config_groups_resource = cm_client.RoleConfigGroupsResourceApi()
        self.view_parameter = "EXPORT_REDACTED" if sensitive_values_redacted else "EXPORT"

    def collect_cm_api_diagnostic(self):
        log.info("CM API collection started.")
        create_directory(self.api_output_dir)
        self.collect_cm_deployment(self.api_output_dir)
        self.collect_hosts()
        self.collect_cluster_info()
        log.info("CM API collection finished.")

    def collect_cm_deployment(self, output_dir):
        api_response = self.cloudera_manager_resource.get_deployment2(view=self.view_parameter)
        dump_json(os.path.join(output_dir, "cm_deployment.json"), api_response)

    def collect_hosts(self):
        log.debug("Read host information.")
        hosts_output_dir = os.path.join(self.api_output_dir, "host")
        create_directory(hosts_output_dir)
        api_response = self.hosts_resource_api.read_hosts(view='FULL')
        dump_json(os.path.join(hosts_output_dir, "read_hosts.json"), api_response)

    def collect_cluster_info(self):
        log.debug("Collect cluster information")
        clusters_output_dir = os.path.join(self.api_output_dir, "cluster")
        create_directory(clusters_output_dir)
        self.collect_kerberos_info(clusters_output_dir)
        self.collect_cm_config(clusters_output_dir)
        self.collect_cm_version(clusters_output_dir)
        api_response = self.clusters_resource.read_clusters(view=self.view_parameter)
        dump_json(os.path.join(clusters_output_dir, "clusters.json"), api_response)

        cluster_names = list(map(lambda cluster: cluster.display_name, api_response.items))
        for cluster_name in cluster_names:
            create_directory(os.path.join(clusters_output_dir, cluster_name.replace(" ", "_")))
            self.list_of_hosts_per_cluster(os.path.join(clusters_output_dir, cluster_name.replace(" ", "_")),
                                           cluster_name)
            self.export_cluster(os.path.join(clusters_output_dir, cluster_name.replace(" ", "_")), cluster_name)
            self.collect_services(os.path.join(clusters_output_dir, cluster_name.replace(" ", "_")), cluster_name)
            self.collect_all_service_configs(os.path.join(clusters_output_dir, cluster_name.replace(" ", "_")),
                                             cluster_name)

    def collect_kerberos_info(self, output_dir):
        api_response = self.cloudera_manager_resource.get_kerberos_info()
        dump_json(os.path.join(output_dir, "kerberos_info.json"), api_response)

    def collect_cm_config(self, output_dir):
        api_response = self.cloudera_manager_resource.get_config(view='FULL')
        dump_json(os.path.join(output_dir, "cm_config.json"), api_response)

    def collect_cm_version(self, output_dir):
        api_response = self.cloudera_manager_resource.get_version()
        dump_json(os.path.join(output_dir, "cm_version.json"), api_response)

    def list_of_hosts_per_cluster(self, output_dir, cluster_name):
        api_response = self.clusters_resource.list_hosts(cluster_name)
        dump_json(os.path.join(output_dir, "list_of_hosts.json"), api_response)

    def export_cluster(self, output_dir, cluster_name):
        api_response = self.clusters_resource.export(cluster_name)
        dump_json(os.path.join(output_dir, "cluster_export.json"), api_response)

    def collect_services(self, output_dir, cluster_name):
        api_response = self.services_resource.read_services(cluster_name=cluster_name, view='FULL')
        dump_json(os.path.join(output_dir, "services.json"), api_response)

    def collect_all_service_configs(self, output_dir, cluster_name):
        services_response = self.services_resource.read_services(cluster_name=cluster_name)
        for service in services_response.items:
            service_configs_dir = os.path.join(output_dir, "configs", service.type, "service")
            roles_configs_dir = os.path.join(output_dir, "configs", service.type, "role")
            role_config_groups_configs_dir = os.path.join(output_dir, "configs", service.type, "role_config_group")
            create_directory(service_configs_dir)
            create_directory(roles_configs_dir)
            create_directory(role_config_groups_configs_dir)

            api_response = self.services_resource.read_service_config(cluster_name=cluster_name,
                                                                      service_name=service.name, view="FULL")
            dump_json(os.path.join(service_configs_dir, f"{service.name}.json"), api_response)
            self.collect_role_configs(roles_configs_dir, cluster_name, service.name)
            self.collect_role_config_groups_configs(role_config_groups_configs_dir, cluster_name, service.name)

    def collect_role_configs(self, output_dir, cluster_name, service_name):
        roles_response = self.roles_resource.read_roles(cluster_name=cluster_name, service_name=service_name)
        for role in roles_response.items:
            api_response = self.roles_resource.read_role_config(cluster_name=cluster_name, service_name=service_name,
                                                                role_name=role.name, view="FULL")
            dump_json(os.path.join(output_dir, f"{role.name}.json"), api_response)

    def collect_role_config_groups_configs(self, output_dir, cluster_name, service_name):
        role_config_groups_response = self.role_config_groups_resource.read_role_config_groups(
            cluster_name=cluster_name, service_name=service_name)
        for role_config_group in role_config_groups_response.items:
            api_response = self.role_config_groups_resource.read_config(cluster_name=cluster_name,
                                                                        service_name=service_name,
                                                                        role_config_group_name=role_config_group.name,
                                                                        view="FULL")
            dump_json(os.path.join(output_dir, f"{role_config_group.name}.json"), api_response)

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
import base64
import urllib.request
import ssl
import requests
from requests.auth import HTTPBasicAuth

from utility import dump_json, create_directory

log = logging.getLogger('main')

module_output_prefix = "api_diagnostics"


class AmbariApiExtractor:

    def __init__(self, ambari_conf):
        self.ambari_server_host = ambari_conf['ambari_server_host']
        self.ambari_server_port = ambari_conf['ambari_server_port']
        self.ambari_http_protocol = ambari_conf['ambari_http_protocol']
        self.api_output_dir = ambari_conf['output_dir']
        self.ambari_user = ambari_conf['ambari_user']
        self.ambari_pass = ambari_conf['ambari_pass']
        self.ambari_server_timeout = ambari_conf['ambari_server_timeout']
        self.url_suffix = ""
        self.host_list = []
        self.service_list = []
        create_directory(self.api_output_dir + "/" + module_output_prefix)
        self.cluster_name = self.get_cluster_name()


    def collect_ambari_api_diagnostic(self):
        self.collect_ambari_details()
        self.collect_hosts()
        self.collect_service_info()
        self.collect_blueprint()
        self.collect_cluster_info()
        self.collect_kerberos_info()
        self.collect_capacity_scheduler_info()
        self.get_cluster_name()
        self.collect_componentlist()
        self.collect_configuration()

    def collect_ambari_details(self):
        log.debug("Started collecting ambari details")
        ambari_details_json = {}
        ambari_details_json["ambari_http_protocol"] = self.ambari_http_protocol
        ambari_details_json["ambari_server_host"] = self.ambari_server_host
        ambari_details_json["ambari_server_port"] = self.ambari_server_port
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "ambari_details.json"), ambari_details_json)
        log.debug("Completed collecting the ambari(cm) details")

    def send_ambari_request(self, url_suffix):
        # Construct URL request for metrics data
        base_url = self.ambari_http_protocol + "://{}:{}/api/v1/clusters/{}".format(
            str(self.ambari_server_host),
            int(self.ambari_server_port),
            str(self.cluster_name)
        )

        url = "{}{}".format(base_url, url_suffix)
        log.debug("Connecting to URL " + url)
        auth_string = "{}:{}".format(self.ambari_user, self.ambari_pass)
        # ctx = ssl.create_default_context()
        # ctx.check_hostname = False
        # ctx.verify_mode = ssl.CERT_NONE
        ssl._create_default_https_context = ssl._create_unverified_context

        auth_encoded = 'Basic {}'.format(
            base64.urlsafe_b64encode(
                auth_string.encode('UTF-8')
            ).decode('ascii')
        )
        req = urllib.request.Request(url)
        req.add_header('Authorization', auth_encoded)

        httpHandler = urllib.request.HTTPHandler()
        # httpHandler.set_http_debuglevel(1)
        opener = urllib.request.build_opener(httpHandler)

        try:
            response = opener.open(req, timeout=int(self.ambari_server_timeout))
            return json.load(response)
        except (urllib.request.URLError, urllib.request.HTTPError) as e:
            log.error('Requested URL not found. Error:{}'.format(e))

    def collect_hosts(self):
        log.debug("Read host list.")
        hosts_list_api_response = self.send_ambari_request("/hosts")
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "hosts.json"), hosts_list_api_response)

        for hostname in hosts_list_api_response['items']:
            host_name_api_response = self.send_ambari_request("/hosts/" + hostname['Hosts']['host_name'])
            dump_json(os.path.join(self.api_output_dir, module_output_prefix,
                                   hostname['Hosts']['host_name'] + "details.json"),
                      host_name_api_response)

    def collect_service_info(self):
        log.debug("Read service information.")
        service_list_api_response = self.send_ambari_request("/services")
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "services.json"), service_list_api_response)

        for service in service_list_api_response['items']:
            service_api_response = self.send_ambari_request("/services/" + service['ServiceInfo']['service_name'])
            dump_json(os.path.join(self.api_output_dir, module_output_prefix,
                                   service['ServiceInfo']['service_name']) + ".json",
                      service_api_response)

            for i, component in enumerate(service_api_response['components']):
                component_api_response = self.send_ambari_request("/services/" + service['ServiceInfo']['service_name'] + '/components/' + component['ServiceComponentInfo']['component_name'])
                dump_json(os.path.join(self.api_output_dir, module_output_prefix,
                                       component['ServiceComponentInfo']['component_name']) + ".json",
                          component_api_response)

    def collect_blueprint(self):
        log.debug("collecting the blueprint of the cluster")
        blueprint_api_response = self.send_ambari_request("?format=blueprint")
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "blueprint.json"), blueprint_api_response)

    def collect_cluster_info(self):
        log.debug("Collecting the cluster Info")
        cluster_api_response = self.send_ambari_request("")
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "clusters.json"),
                  cluster_api_response['Clusters'])

    def collect_componentlist(self):
        log.debug("Collecting the componentlist Info")
        componentlist_api_response = self.send_ambari_request("/host_components?HostRoles")
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "componentslist.json"), componentlist_api_response)

    def collect_configuration(self):
       log.debug("Collecting the configuration Info")
       configuartion_api_response = self.send_ambari_request("/configurations/service_config_versions?is_current=true")
       dump_json(os.path.join(self.api_output_dir, module_output_prefix, "configurations.json"),
                 configuartion_api_response)

    def collect_kerberos_info(self):
        services_list = []
        log.debug("Collect kerberos information")
        service_list_api_response = self.send_ambari_request("/services")
        for service in service_list_api_response['items']:
            services_list.append(service['ServiceInfo']['service_name'])
        if "KERBEROS" in services_list:
            kerberos_api_response = self.send_ambari_request(
                "/configurations/service_config_versions?service_name=KERBEROS&is_current=true")
            dump_json(os.path.join(self.api_output_dir, module_output_prefix, "kerberos.json"),
                      kerberos_api_response)
        else:
            log.debug("Kerberos is not enabled for this cluster")

    def collect_capacity_scheduler_info(self):
        services_list = []
        log.debug("Collect kerberos information")
        service_list_api_response = self.send_ambari_request("/services")
        for service in service_list_api_response['items']:
            services_list.append(service['ServiceInfo']['service_name'])
        if "YARN" in services_list:
            cs_api_response = self.send_ambari_request(
                "/configurations/service_config_versions?service_name=YARN&is_current=true")
            for id, each in enumerate(cs_api_response['items'][0]['configurations']):
                if cs_api_response['items'][0]['configurations'][id]['type'] == 'capacity-scheduler':
                    dump_json(os.path.join(self.api_output_dir, module_output_prefix, "capacity-scheduler.json"),
                              cs_api_response['items'][0]['configurations'][id]['properties'])

    def collect_services_list(self):
        services_list = []
        log.debug("Collect kerberos information")
        service_list_api_response = self.send_ambari_request("/services")
        for service in service_list_api_response['items']:
            services_list.append(service['ServiceInfo']['service_name'])
        return services_list

    def get_cluster_name(self):
        try:
            r = requests.get(self.ambari_http_protocol+"://"+self.ambari_server_host+":"+self.ambari_server_port+"/api/v1/clusters",auth = HTTPBasicAuth(self.ambari_user, self.ambari_pass),verify=False)

        except requests.exceptions.RequestException as e:
            log.debug(
                "Issue connecting to ambari server. Please check the process is up and running and responding as expected.")
            raise SystemExit(e)
        dump_json(os.path.join(self.api_output_dir, module_output_prefix, "cluster_name.json"), r.json())
        return r.json()['items'][0]['Clusters']['cluster_name']

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

import base64
import json
import logging
import os
import os.path
import ssl
import tarfile
import urllib
from logging import Logger

import requests
from requests.auth import HTTPBasicAuth

from utility import create_directory
from hdfs import InsecureClient
from hdfs.ext.kerberos import KerberosClient

log: Logger = logging.getLogger('main')

def _make_tarfile(output_file_path, source_dir):
    log.info("Creating tarball at " + output_file_path + " from " + source_dir)
    files = os.listdir(source_dir)
    with tarfile.open(output_file_path, "w:gz") as tar:
        for f in files:
            tar.add(os.path.join(source_dir, f),
                    os.path.basename(f))
    log.info(f"Tarball created at: {output_file_path}")


class MapreduceExtractor:
    def __init__(self, ambari_conf):
        self.ambari_server_host = ambari_conf['ambari_server_host']
        self.ambari_server_port = ambari_conf['ambari_server_port']
        self.ambari_user = ambari_conf['ambari_user']
        self.ambari_pass = ambari_conf['ambari_pass']
        self.output_dir = ambari_conf['output_dir']
        self.ambari_server_timeout = ambari_conf['ambari_server_timeout']
        self.ambari_http_protocol = ambari_conf['ambari_http_protocol']
        self.ambari_api_version = "/api/v1"
        self.cluster_name = self.get_cluster_name()

    def collect_mapreduce_logs_for_cluster(self, hdfs_url, download_dir):
        default_history_dir = "/mr-history"

        log.debug(f"Downloading files from {default_history_dir}")
        service_list = self.collect_services_list()
        if "KERBEROS" in service_list:
            log.debug("Kerberos is enabled using the requests-kerberos python module!! Do you have a valid kerberos ticket ??")
            client = KerberosClient(hdfs_url)
            try:
                client.download(default_history_dir, download_dir + "/done", n_threads=4, overwrite=True)
            except Exception as e:
                log.error("Issue in downloading " + default_history_dir)
                log.error(e)
        else:
            log.debug("kerberos in not enabled, using the hdfs python module")
            client = InsecureClient(hdfs_url, user='hdfs')
            try:
                client.download(default_history_dir, download_dir + "/done", n_threads=4, overwrite=True)
            except Exception as e:
                log.error("Issue in downloading " + default_history_dir)
                log.error(e)
        try:
            _make_tarfile(os.path.join(download_dir, "mr-history.tar.gz"), download_dir)
        except Exception as e:
            log.error("Issue with taring the directory " + download_dir)
            log.error(e)

    def collect_mapreduce_job_histories(self):
        master_components = self.collect_master_componets_hosts()
        if 'NAMENODE' in master_components:
            hdfs_config = self.collect_hdfs_config()
            if 'nameservices' in hdfs_config:
                web_hdfs_host_name = self.get_active_namenode()
            else:
                web_hdfs_host_name = master_components['NAMENODE']
            if hdfs_config['web_hdfs_enabled'] == "true":
                web_hdfs_host_port = hdfs_config['port']
                web_hdfs_scheme = hdfs_config['http_type']
                active_namenode_url = web_hdfs_scheme + "://" + web_hdfs_host_name + ":" + str(web_hdfs_host_port)
                log.debug("Active namenode url:" + active_namenode_url)
                mapreduce_output_dir = os.path.join(self.output_dir, "workload", 'MAPREDUCE')
                create_directory(mapreduce_output_dir)
                self.collect_mapreduce_logs_for_cluster(active_namenode_url, mapreduce_output_dir)
            else:
                log.debug("Webhdfs is not enabled, Unable to collect the mr job history via webhdfs")

    def collect_master_componets_hosts(self):
        master_components = {}
        servicesapi_response = self.send_ambari_request("/services")
        for service in servicesapi_response['items']:
            service_name = self.send_ambari_request(
                "/services/" + (service['ServiceInfo']['service_name']) + "/components")
            for component in service_name['items']:
                component_name = component['ServiceComponentInfo']['component_name']
                amb_url = self.send_ambari_request(
                    "/services/" + service['ServiceInfo']['service_name'] + "/components/" + component_name)
                if component_name in ['NAMENODE', 'METRICS_COLLECTOR', 'HIVE_METASTORE']:
                    master_components[component_name] = amb_url['host_components'][0]['HostRoles']['host_name']
        return master_components

    def get_active_namenode(self):
        namenodes = []
        host_components_api_response = self.send_ambari_request("/host_components")
        for idx, each in enumerate(host_components_api_response['items']):
            if host_components_api_response['items'][idx]['HostRoles']['component_name'] == 'NAMENODE':
                namenodes.append(host_components_api_response['items'][idx]['HostRoles']['host_name'])
        for namenode in namenodes:
            active_nn_api_response = self.send_ambari_request("/hosts/" + namenode + "/host_components/NAMENODE")
            if active_nn_api_response['metrics']['dfs']['FSNamesystem']['HAState'] == 'active':
                return namenode

    def collect_hdfs_config(self):
        hdfs_config = {}
        hdfs_current_config_string = "/configurations/service_config_versions?service_name.in(HDFS)&is_current=true"
        current_config_api_response = self.send_ambari_request(hdfs_current_config_string)
        config_types = current_config_api_response['items'][0]['configurations']
        for config_type in config_types:
            if config_type['type'] == 'hdfs-site':
                hdfs_config['ns'] = config_type['properties']['dfs.nameservices'].split(",")[0]
                hdfs_config['nn1'] = config_type['properties']['dfs.ha.namenodes.' + hdfs_config['ns']].split(",")[0]
                if config_type['properties']['dfs.http.policy'] == "HTTP_ONLY":
                    hdfs_config['http_type'] = 'http'
                else:
                    hdfs_config['http_type'] = 'https'
                hdfs_config['port'] = config_type['properties']['dfs.namenode.' + hdfs_config['http_type'] + '-address' + '.' + hdfs_config['ns'] + '.' + hdfs_config['nn1']].split(":")[-1]
                hdfs_config['web_hdfs_enabled'] = config_type['properties']['dfs.webhdfs.enabled']
        return hdfs_config

    def send_ambari_request(self, url_suffix):
        # Construct URL request for metrics data
        base_url = self.ambari_http_protocol + "://{}:{}/api/v1/clusters/{}".format(
            str(self.ambari_server_host),
            int(self.ambari_server_port),
            str(self.cluster_name)
        )

        url = "{}{}".format(base_url, url_suffix)
        auth_string = "{}:{}".format(self.ambari_user, self.ambari_pass)
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
        return r.json()['items'][0]['Clusters']['cluster_name']

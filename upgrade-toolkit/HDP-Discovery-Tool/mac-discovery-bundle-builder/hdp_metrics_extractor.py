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
import os
import json
import logging
import ssl
import urllib.request
import datetime

import requests as requests
from requests.auth import HTTPBasicAuth

from utility import create_directory, dump_json

log = logging.getLogger('main')


class MetricsExtractor:
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

    def collect_metrics(self):
        log.debug("Started Collecting the Metrics")
        x = self.send_ambari_request("/services")
        for service in x['items']:
            service_name = self.send_ambari_request(
                "/services/" + (service['ServiceInfo']['service_name']) + "/components")
            for component in service_name['items']:
                component_name = component['ServiceComponentInfo']['component_name']
                amb_url = self.send_ambari_request(
                    "/services/" + service['ServiceInfo']['service_name'] + "/components/" + component_name)
                create_directory(self.output_dir + "/AMB_METRICS" + "/" + service['ServiceInfo'][
                    'service_name'] + "/" + component_name)
                dump_json(
                    os.path.join(self.output_dir, "AMB_METRICS", service['ServiceInfo']['service_name'], component_name,
                                 component_name + "_METRICS.json"), amb_url)

        master_components = self.collect_master_componets_hosts()
        log.debug(master_components)
        if 'METRICS_COLLECTOR' in master_components:
            metrics_collector_host = master_components['METRICS_COLLECTOR']
            # metrics_collector_host = "10.42.18.2"
            ams_config = self.collect_ams_config()
            ams_protocol = ams_config['http_type']
            ams_port = ams_config['port']

            end_timestamp = int(datetime.datetime.now().timestamp())
            log.debug("END TIME STAMP EPOCH:" + str(end_timestamp))
            start_timestamp = end_timestamp - 86400 * 45
            log.debug("START TIME STAMP EPOCH: " + str(start_timestamp))
            try:
                r = requests.get(
                ams_protocol + "://" + metrics_collector_host + ":" + ams_port + "/ws/v1/timeline/metrics/metadata")
            except requests.exceptions.RequestException as e:
                log.error(
                    'Issue connecting to ambari metrcis collector. Please check the DNS resolution, process is up and running and responding as expected. For now the thread is exiting without collecting any ams metrics')
                log.error(e)

            for app in (r.json().keys()):
                ams_url = ams_protocol + "://" + metrics_collector_host + ":" + ams_port + "/ws/v1/timeline/metrics?metricNames=%&appId=" + app + "&hostname=%&startTime=" + str(
                    start_timestamp) + "&endTime=" + str(end_timestamp)
                log.debug(ams_url)
                create_directory(self.output_dir + "/AMS_METRICS/")
                dump_json(os.path.join(self.output_dir, "AMS_METRICS/" + "apps.json"), r.json())

                try:
                    app_response = requests.get(ams_url)
                except requests.exceptions.RequestException as e:
                    raise SystemExit(e)
                create_directory(self.output_dir + "/AMS_METRICS/" + app)
                dump_json(os.path.join(self.output_dir, "AMS_METRICS", app, app + ".json"), app_response.json())

                ams_url_max = ams_protocol + "://" + metrics_collector_host + ":" + ams_port + "/ws/v1/timeline/metrics?metricNames=%._max&appId=" + app + "&hostname=%&startTime=" + str(
                    start_timestamp) + "&endTime=" + str(end_timestamp)
                log.debug(ams_url_max)
                try:
                    app_response_max = requests.get(ams_url_max)
                except requests.exceptions.RequestException as e:
                    raise SystemExit(e)
                dump_json(os.path.join(self.output_dir, "AMS_METRICS", app, app + "_max.json"), app_response_max.json())

                ams_url_min = ams_protocol + "://" + metrics_collector_host + ":" + ams_port + "/ws/v1/timeline/metrics?metricNames=%._min&appId=" + app + "&hostname=%&startTime=" + str(
                    start_timestamp) + "&endTime=" + str(end_timestamp)
                log.debug(ams_url_min)
                try:
                    app_response_min = requests.get(ams_url_min)
                except requests.exceptions.RequestException as e:
                    raise SystemExit(e)
                dump_json(os.path.join(self.output_dir, "AMS_METRICS", app, app + "_min.json"), app_response_min.json())

                ams_url_avg = ams_protocol + "://" + metrics_collector_host + ":" + ams_port + "/ws/v1/timeline/metrics?metricNames=%._avg&appId=" + app + "&hostname=%&startTime=" + str(
                    start_timestamp) + "&endTime=" + str(end_timestamp)
                log.debug(ams_url_avg)
                try:
                    app_response_avg = requests.get(ams_url_avg)
                except requests.exceptions.RequestException as e:
                    raise SystemExit(e)
                dump_json(os.path.join(self.output_dir, "AMS_METRICS", app, app + "_avg.json"), app_response_avg.json())



            log.debug("Completed collecting the Metrics")
        else:
            log.debug("Metrics collector component is not found in cluster. Unable to collect the hdp_metrics")

    def send_ambari_request(self, url_suffix):
        # Construct URL request for metrics data
        base_url = self.ambari_http_protocol+"://{}:{}/api/v1/clusters/{}".format(
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

    def collect_ams_config(self):
        ams_config = {}
        ams_current_config_string = "/configurations/service_config_versions?service_name.in(AMBARI_METRICS)&is_current=true"
        current_config_api_response = self.send_ambari_request(ams_current_config_string)
        config_types = current_config_api_response['items'][0]['configurations']
        for config_type in config_types:
            if config_type['type'] == 'ams-site':
                if config_type['properties']['timeline.metrics.service.http.policy'] == "HTTP_ONLY":
                    ams_config['http_type'] = 'http'
                else:
                    ams_config['http_type'] = 'https'
                ams_config['port'] = config_type['properties']['timeline.metrics.service.webapp.address'].split(":")[-1]
        return ams_config

    def get_cluster_name(self):
        try:
            r = requests.get(self.ambari_http_protocol+"://"+self.ambari_server_host+":"+self.ambari_server_port+"/api/v1/clusters",auth = HTTPBasicAuth(self.ambari_user, self.ambari_pass),verify=False)
        except requests.exceptions.RequestException as e:
            log.debug(
                "Issue connecting to ambari server. Please check the process is up and running and responding as expected.")
            raise SystemExit(e)
        return r.json()['items'][0]['Clusters']['cluster_name']
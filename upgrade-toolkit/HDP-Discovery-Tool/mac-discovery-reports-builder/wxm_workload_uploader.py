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
import time
from pathlib import Path
from typing import Any

import requests
import urllib3
from dateutil import parser
from tzlocal import get_localzone
from datetime import datetime

date = datetime.now().strftime("%Y_%m_%d-%I:%M:%S_%p")

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
log = logging.getLogger('main')


class WxmUploader:
    def __init__(self, discovery_bundle_path, wb):
        self.discovery_bundle_path = discovery_bundle_path
        self.wb = wb

    @staticmethod
    def run_cdp(cdp_cmd) -> Any:
        result = os.popen(cdp_cmd).read()
        try:
            log.debug(result)
            return json.loads(result)
        except json.JSONDecodeError:
            raise Exception(f'Failed to load JSON for CDP command "{cdp_cmd}"\nOutput:\n{result}\n'
                            f'Please make sure to set CDP_PROFILE env variable according to README.md')

    def get_cluster_name(self):
        try:
            with open( self.discovery_bundle_path + '/api_diagnostics/clusters.json', 'r') as f:
                clusterdata = json.load(f)
        except IOError:
            log.debug(
                "Issue in finding and loading the clusters.json in api_diagnostic folder: Please verify the extraction bundles output")
        else:
            cluster_name = clusterdata['cluster_name']
            return cluster_name

    def upload_workloads(self):
        log.info("Workload upload to WXM started.")
        # f = open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/cm_deployment.json'))
        # deployment_json = json.load(f)
        # deployment = cm_client.ApiClient()._ApiClient__deserialize(deployment_json, 'ApiDeployment2')
        env_names = []
        env_ids = []
        # for cluster in deployment.clusters:
        cluster = self.get_cluster_name()
        epoch = str(int(time.time()))
        env_name = cluster + '_' + epoch
        env = self.run_cdp(f'cdp wa create-environment --name {env_name} --timezone {get_localzone()}')
        env_id = env['environment']["id"]
        workload_metrics = Path(os.path.join(self.discovery_bundle_path, "workload")).rglob(
            "*.tar.gz")
        for workload in workload_metrics:
            upload_type = ""
            print(workload.name)
            if 'mr-history' in str(workload):
                upload_type = "MR_JOB_HISTORY"
            elif "spark" in str(workload):
                upload_type = "SPARK_APP_HISTORY"
            elif "tez-" in str(workload):
                upload_type = "TEZ_PROTOBUF_APPLICATIONS"
            elif "hive-" in str(workload):
                upload_type = "HIVE_PROTOBUF_APPLICATIONS"
            log.info(f"Uploading {upload_type} from local path: {workload}")
            upload_destination = self.run_cdp(
                f'cdp wa create-upload-destination --environment-id {env_id} --upload-type {upload_type}')
            with open(workload, 'rb') as f:
                data = f.read()
            response = requests.put(upload_destination['uploadDestination']['url'], data=data, verify=False)
            if response.status_code == 200:
                log.info("Workload upload successful.")
            else:
                log.warning(f"Workload upload returned status code {response.status_code}: {response.content}")
        log.info("Workload upload to WXM finished.")
        self.wb['Summary'].cell(row=31, column=2).value = env_name.__str__()
        self.wb['Summary'].cell(row=32, column=2).value = env_id.__str__()

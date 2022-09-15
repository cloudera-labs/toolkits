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

import cm_client
import requests
import urllib3
from dateutil import parser
from tzlocal import get_localzone

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

    def upload_workloads(self):
        log.info("Workload upload to WXM started.")
        f = open(os.path.join(self.discovery_bundle_path, 'api_diagnostics/cm_deployment.json'))
        deployment_json = json.load(f)
        deployment = cm_client.ApiClient()._ApiClient__deserialize(deployment_json, 'ApiDeployment2')
        env_names = []
        env_ids = []
        for cluster in deployment.clusters:
            env_name = f"{cluster.display_name.replace(' ', '-').replace('@', '-').replace('_','-').replace('#','-')}_{int(time.time())}"
            env_names.append(env_name)
            env = self.run_cdp(f'cdp wa create-environment --name {env_name} --timezone {get_localzone()}')
            env_id = env['environment']["id"]
            env_ids.append(env_id)
            workload_metrics = Path(os.path.join(self.discovery_bundle_path, "workload", cluster.display_name.replace(" ", "_"))).rglob(
                "*.tar.gz")
            for workload in workload_metrics:
                upload_type = ""
                if "IMPALA_PROFILE_LOGS" in workload.name:
                    upload_type = "IMPALA_PROFILE_LOGS"
                elif "MR_JOB_HISTORY" in workload.name:
                    upload_type = "MR_JOB_HISTORY"
                elif "SPARK_APP_HISTORY" in workload.name:
                    upload_type = "SPARK_APP_HISTORY"
                elif "TEZ_PROTOBUF_APPLICATIONS" in workload.name:
                    upload_type = "TEZ_PROTOBUF_APPLICATIONS"
                elif "HIVE_PROTOBUF_APPLICATIONS" in workload.name:
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
        self.wb['Summary'].cell(row=31, column=2).value = env_names.__str__()
        self.wb['Summary'].cell(row=32, column=2).value = env_ids.__str__()

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
from utility import create_directory

from utility import dump_json, create_directory

log = logging.getLogger('main')

module_output_prefix = "ranger_policies"


# ranger_admin_user =
# ranger_admin_pass =
# ranger_ui_protocol =
# ranger_ui_server_name =
# ranger_ui_port =

class RangerPolicyExtractor:
    def __init__(self, ambari_conf):
        self.ranger_admin_user = ambari_conf['ranger_admin_user']
        self.ranger_admin_pass = ambari_conf['ranger_admin_pass']
        self.ranger_ui_protocol = ambari_conf['ranger_ui_protocol']
        self.ranger_ui_server_name = ambari_conf['ranger_ui_server_name']
        self.ranger_ui_port = ambari_conf['ranger_ui_port']
        self.api_output_dir = ambari_conf['output_dir']
        create_directory(self.api_output_dir + "/" + module_output_prefix)

    def get_ranger_policies(self):
        try:
            r = requests.get(
                self.ranger_ui_protocol + "://" + self.ranger_ui_server_name + ":" + self.ranger_ui_port + "/service/public/v2/api/policy",
                auth=HTTPBasicAuth(self.ranger_admin_user, self.ranger_admin_pass),verify=False)
        except requests.exceptions.RequestException as e:
            log.error(
                "Issue connecting to Ranger Admin UI. Please check the configs provided. Also, the process is up and running and responding as expected.")
        try:
            dump_json(os.path.join(self.api_output_dir, module_output_prefix, "ranger_policies.json"), r.json())
        except Exception as e:
            log.error("Issue with connecting to Ranger UI")
            log.error("Unable to collect ranger details")
        else:
            dump_json(os.path.join(self.api_output_dir, module_output_prefix, "ranger_policies.json"), r.json())
            log.debug("Completed collecting the ranger details")

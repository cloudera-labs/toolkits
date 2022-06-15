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
import sys
import cm_client
from cm_client.rest import ApiException
import logging

logger = logging.getLogger('apply_properties')
logger.setLevel(logging.DEBUG)

# GLOBAL VARIABLES
json_input_file = sys.argv[1]

cm_user = 'admin'
cm_pass = 'admin'
cm_api_version = 'v41'
cm_host_name = 'cm_url'
cluster_name = 'cluster_name'
tls = True
cm_client.configuration.verify_ssl = False
ca_cert_path = 'cert.pem'

cm_api_instance = ''
services_instance = ''
role_config_instance = ''


def setup_api():
    """
    Helper to set up the Cloudera Manager API
    This assumes that you are executing this script on the
    Cloudera Manager host
    :return: api_client
    """
    global cm_api_version
    cm_host = cm_host_name
    cm_client.configuration.username = cm_user
    cm_client.configuration.password = cm_pass
    if tls:
        logging.info('Setting up with TLS true')
        cm_client.configuration.verify_ssl = tls
        cm_client.configuration.ssl_ca_cert = ca_cert_path
        api_host = 'https://{host}'.format(host=cm_host) + ':7183'
        api_url = api_host + '/api/' + cm_api_version
    else:
        logging.info("TLS is not enabled")
        api_host = 'http://{host}'.format(host=cm_host) + ':7180'
        api_url = api_host + '/api/' + cm_api_version

    api_client = cm_client.ApiClient(api_url)
    return api_client


def read_json_file():
    with open(json_input_file) as in_file:
        json_str = in_file.read()
    return json_str


def handle_service_configs(service_configs, service_ref_name):
    configs = []
    for properties in service_configs:
        if 'value' in properties:
            configs.append(cm_client.ApiConfig(name=properties['name'], value=properties['value']))
    if len(configs) > 0:
        msg = 'Updating parameter(s) for {service_type}'.format(service_type=service_ref_name)
        try:
            print(msg)
            api_response = services_instance.update_service_config(cluster_name=cluster_name,
                                                                   service_name=service_ref_name, message=msg,
                                                                   body=cm_client.ApiConfigList(configs))
            # pprint(api_response)
        except ApiException as e:
            print(("Exception when calling ServicesResourceApi->update_config: %s\n" % e))
    else:
        print("No Service Configs to update")


def handle_role_configs(role_configs, service_ref_name):
    for rcg in role_configs:
        configs = []
        if 'configs' in rcg:
            msg = 'Updating parameter(s) for {service_type} and role config group {rcg}'.format(
                service_type=service_ref_name, rcg=rcg['refName'])
            for properties in rcg['configs']:
                print(("Setting the property {name} the the value {value}".format(name=properties['name'],
                                                                                  value=properties['value'])))
                configs.append(cm_client.ApiConfig(name=properties['name'], value=properties['value']))
            try:
                print(msg)
                body = cm_client.ApiConfigList(configs)
                print(body)
                api_response = role_config_instance.update_config(cluster_name=cluster_name,
                                                                  role_config_group_name=rcg['refName'],
                                                                  service_name=service_ref_name,
                                                                  message=msg,
                                                                  body=body)
                # pprint(api_response)
            except ApiException as e:
                print(("Exception when calling RoleConfigGroupsResourceApi->update_config: %s\n" % e))


def iterate_json(json_str):
    json_data = json.loads(json_str)
    for service in json_data['services']:
        if 'serviceConfigs' in service:
            handle_service_configs(service['serviceConfigs'], service['refName'])
        if 'roleConfigGroups' in service:
            handle_role_configs(service['roleConfigGroups'], service['refName'])


if __name__ == '__main__':
    api_client = setup_api()
    cm_api_instance = cm_client.ClouderaManagerResourceApi(api_client)
    services_instance = cm_client.ServicesResourceApi(api_client)
    role_config_instance = cm_client.RoleConfigGroupsResourceApi(api_client)
    iterate_json(read_json_file())

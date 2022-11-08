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

import csv
import json
import logging
import subprocess
import sys
from configparser import ConfigParser
from pathlib import Path

log = logging.getLogger('main')


def run_cmd(args_list):
    """
    run linux commands
    """
    # import subprocess
    log.info('Running system command: {0}'.format(' '.join(args_list)))
    result = subprocess.run(args_list, capture_output=True, text=True)
    s_output = result.stdout
    s_err = result.stderr
    s_return = result.returncode
    return s_return, s_output, s_err


def dump_json(path, api_response):
    f = open(path, "w")
    f.write(json.dumps(api_response))
    log.debug(f"Api response stored in: {path}")


def create_directory(dir_path):
    path = Path(dir_path)
    path.mkdir(parents=True, exist_ok=True)


def get_config_params(config_file):
    try:
        with open(config_file) as f:
            try:
                parser = ConfigParser()
                parser.read_file(f)
            except ConfigParser.Error as err:
                log.error('Could not parse: {} '.format(err))
                return False
    except IOError as e:
        log.error("Unable to access %s. Error %s \nExiting" % (config_file, e))
        sys.exit(1)

    ambari_server_host = parser.get('ambari_config', 'ambari_server_host')
    ambari_server_port = parser.get('ambari_config', 'ambari_server_port')
    ambari_user = parser.get('ambari_config', 'ambari_user')
    ambari_pass = parser.get('ambari_config', 'ambari_pass')
    ambari_server_timeout = parser.get('ambari_config', 'ambari_server_timeout')
    ambari_http_protocol = parser.get('ambari_config', 'ambari_http_protocol')
    output_dir = parser.get('ambari_config', 'output_dir')

    hive_metastore_type = parser.get('hive_config', 'hive_metastore_type')
    hive_metastore_server = parser.get('hive_config', 'hive_metastore_server')
    hive_metastore_server_port = parser.get('hive_config', 'hive_metastore_server_port')
    hive_metastore_database_name = parser.get('hive_config', 'hive_metastore_database_name')
    hive_metastore_database_user = parser.get('hive_config', 'hive_metastore_database_user')
    hive_metastore_database_password = parser.get('hive_config', 'hive_metastore_database_password')
    hive_metastore_database_driver_path = parser.get('hive_config', 'hive_metastore_database_driver_path')

    ranger_admin_user = parser.get('ranger_config', 'ranger_admin_user')
    ranger_admin_pass = parser.get('ranger_config', 'ranger_admin_pass')
    ranger_ui_protocol = parser.get('ranger_config', 'ranger_ui_protocol')
    ranger_ui_server_name = parser.get('ranger_config', 'ranger_ui_server_name')
    ranger_ui_port = parser.get('ranger_config', 'ranger_ui_port')

    # Prepare dictionary object with config variables populated for both anmabri and ranger.
    config_dict = {}
    config_dict["ambari_server_host"] = ambari_server_host
    config_dict["ambari_server_port"] = ambari_server_port
    config_dict["ambari_server_timeout"] = ambari_server_timeout
    config_dict["output_dir"] = output_dir
    config_dict["ambari_user"] = ambari_user
    config_dict["ambari_pass"] = ambari_pass
    config_dict["hive_metastore_type"] = hive_metastore_type
    config_dict["hive_metastore_server"] = hive_metastore_server
    config_dict["hive_metastore_server_port"] = hive_metastore_server_port
    config_dict["hive_metastore_database_name"] = hive_metastore_database_name
    config_dict["hive_metastore_database_password"] = hive_metastore_database_password
    config_dict["hive_metastore_database_user"] = hive_metastore_database_user
    config_dict["hive_metastore_database_driver_path"] = hive_metastore_database_driver_path
    config_dict["ambari_http_protocol"] = ambari_http_protocol
    config_dict["ranger_admin_user"] = ranger_admin_user
    config_dict["ranger_admin_pass"] = ranger_admin_pass
    config_dict["ranger_ui_protocol"] = ranger_ui_protocol
    config_dict["ranger_ui_server_name"] = ranger_ui_server_name
    config_dict["ranger_ui_port"] = ranger_ui_port

    return config_dict


def write_csv(columns, rows, output):
    csv_file = open(output, mode='w')
    writer = csv.writer(csv_file, delimiter=',', lineterminator="\n")
    writer.writerow(columns)
    for row in rows:
        writer.writerow(row)
    log.debug("CSV write finished, results at: {output}")

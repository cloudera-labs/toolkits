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

import logging.config
import logging.config
import os
from optparse import OptionParser
from pathlib import Path
from threading import Thread

import yaml
from openpyxl import load_workbook

from mac_report_builder import MacReportBuilder


# from wxm_workload_uploader import WxmUploader


def create_directory(dir_path):
    path = Path(dir_path)
    path.mkdir(parents=True, exist_ok=True)


root_path = os.path.dirname(os.path.realpath(__file__))

if __name__ == '__main__':
    parser = OptionParser(usage='%prog [options]')
    parser.add_option('--discovery-bundle-path', action='store', type='string',
                      dest='input_path',
                      metavar='<input_path>',
                      help='')
    parser.add_option('--reports-path', action='store', type='string',
                      dest='output_path',
                      metavar='<output_path>',
                      help='')

    (options, args) = parser.parse_args()

    if not options.input_path:  # if input_path details is not given
        parser.error('discovery bundle path not given')
    if not options.output_path:  # if output_path is not given
        parser.error('reports path not given')

    create_directory(options.output_path + "/logs")

    with open(os.path.join(root_path, 'config', 'log-config.yaml'), 'r') as stream:
        config = yaml.load(stream, Loader=yaml.FullLoader)
        log_path = config['handlers']['file']['filename']
        config['handlers']['file']['filename'] = os.path.join(options.output_path, log_path)
    logging.config.dictConfig(config)
    log = logging.getLogger('main')

    log.debug("Building discovery bundle reports.")
    wb = load_workbook(os.path.join(root_path, 'template/reports-template.xlsx'))
    mac_reports_builder = MacReportBuilder(options.input_path, wb)
    threads = [
        Thread(target=mac_reports_builder.create_node_report, name="node_report_builder_thread"),
        Thread(target=mac_reports_builder.create_service_metrics_report, name="services_metrics_report_builder_thread"),
        Thread(target=mac_reports_builder.create_service_report, name="services_report_builder_thread"),
        Thread(target=mac_reports_builder.create_configuration_report, name="config_report_builder_thread"),
        Thread(target=mac_reports_builder.create_hive_metastore_report, name="hms_report_builder_thread"),
        Thread(target=mac_reports_builder.create_cluster_report, name="cluster_builder_thread"),
        Thread(target=mac_reports_builder.create_cm_report(), name="create_cm_report"),
        Thread(target=mac_reports_builder.create_ranger_policy_report(), name="ranger_policies_report"),
        Thread(target=mac_reports_builder.create_hdfs_report, name="hdfs_report_builder_thread")
    ]

    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    wb.save(os.path.join(options.output_path, 'mac-result-test.xlsx'))
    log.debug("Report build has been finished, Please verify the logs to see if script is able to build the complete "
              "report")

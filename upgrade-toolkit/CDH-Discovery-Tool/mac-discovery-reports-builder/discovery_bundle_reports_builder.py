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
                      help='Path where the Discovery bundle was exported.')
    parser.add_option('--reports-path', action='store', type='string',
                      dest='output_path',
                      metavar='<output_path>',
                      help='Path where the mac-discovery-bundle-report.xlsx file should be exported')
    parser.add_option('--hdfs-report-depth', action='store', type='int',
                      dest='hdfs_report_depth',
                      metavar='<report-depth>',
                      default=3,
                      help='Directory level depth to aggregate the statistics. If ')
    #parser.add_option("--wxm-upload",
    #                  action="store_true", dest="wxm_upload", default=False,
    #                  help="Use this flag to upload the tarballs to WXM")

    (options, args) = parser.parse_args()

    if not options.input_path:  # if input_path details is not given
        parser.error('input_path not given')
    if not options.output_path:  # if output_path is not given
        parser.error('output_path not given')

    create_directory(f"{options.output_path}/logs")
    with open(os.path.join(root_path, 'config', 'log-config.yaml'), 'r') as stream:
        config = yaml.load(stream, Loader=yaml.FullLoader)
        log_path = config['handlers']['file']['filename']
        config['handlers']['file']['filename'] = os.path.join(options.output_path, log_path)
    logging.config.dictConfig(config)
    log = logging.getLogger('main')

    log.info("*** INVOCATION PARAMETERS START ***")
    log.info("*** discovery-bundle-path: %s", options.input_path)
    log.info("*** reports-path: %s", options.output_path)
    log.info("*** hdfs-report-depth: %s", options.hdfs_report_depth)
    #log.info("*** wxm-upload: %s", options.wxm_upload)
    log.info("*** INVOCATION PARAMETERS END   ***")

    log.info("Building discovery bundle reports.")

    wb = load_workbook(os.path.join(root_path, 'template/reports-template.xlsx'))
    mac_reports_builder = MacReportBuilder(options.input_path, wb)
    threads = [
        Thread(target=mac_reports_builder.create_node_report, name="node_report_builder_thread"),
        Thread(target=mac_reports_builder.create_service_metrics_report, name="services_metrics_report_builder_thread"),
        Thread(target=mac_reports_builder.create_role_metrics_report, name="role_metrics_report_builder_thread"),
        Thread(target=mac_reports_builder.create_service_report, name="services_report_builder_thread"),
        Thread(target=mac_reports_builder.create_workload_metrics_report, name="workload_report_builder_thread"),
        Thread(target=mac_reports_builder.create_configuration_report, name="config_report_builder_thread"),
        Thread(target=mac_reports_builder.create_hive_metastore_report, name="hms_report_builder_thread"),
        Thread(target=mac_reports_builder.create_hdfs_report, name="hdfs_report_builder_thread",
               args=(options.hdfs_report_depth,)),
        Thread(target=mac_reports_builder.create_sentry_policies_report,
               name="sentry_policies_report_builder_thread"),
        Thread(target=mac_reports_builder.create_cluster_report, name="cluster_builder_thread"),
        Thread(target=mac_reports_builder.create_cm_report, name="create_cm_report")
    ]

    # if options.wxm_upload:
    #    threads.append(Thread(target=WxmUploader(options.input_path, wb).upload_workloads, name="wxm_uploader_thread"))
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    output_path = os.path.join(options.output_path, f'mac-discovery-bundle-report.xlsx')
    wb.save(output_path)
    log.info(f"Report build has been finished, report can be found at: {output_path}")

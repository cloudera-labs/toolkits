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

import configparser
import datetime
import logging.config
import os
import re
import sys
from optparse import OptionParser
from threading import Thread

import cm_client
import urllib3
import yaml

from cm_api_extractor import CmApiExtractor
from cm_metrics_extractor import CmMetricsExtractor
from diagnostic_bundle_extractor import DiagnosticBundleExtractor
from discovery_bundle_builder_utils import create_directory
from hdfs_fs_image_extractor import HdfsFsImageExtractor
from hive_metastore_extractor import HiveMetastoreExtractor
from sentry_policies_extractor import SentryPoliciesExtractor
from workload_extractor import ImpalaProfilesExtractor
from workload_extractor import YarnWorkloadExtractor

root_path = os.path.dirname(os.path.realpath(__file__))

config = configparser.ConfigParser()
config.read(os.path.join(root_path, 'config', 'config.ini'))


def setup_cm_client(cm_host, cm_user, cm_password):
    api_url = build_cm_url(cm_host)
    if api_url.startswith("https"):
        urllib3.disable_warnings()
        cm_client.configuration.verify_ssl = False
    cm_client.configuration.username = cm_user
    cm_client.configuration.password = cm_password
    cm_client.configuration.host = api_url


def build_cm_url(cm_host):
    log.info("Validating CM url")
    matched = re.match("^http[s]?://.*:\d+$", cm_host)
    if not bool(matched):
        log.error("CM URL does not matches regex. use the following format: http[s]://cm-host-url:cm-port")
        sys.exit(-1)
    log.info("%s CM url matches required format", cm_host)
    return cm_host + '/api/v19'


if __name__ == '__main__':
    parser = OptionParser(usage='%prog [options]')

    parser.add_option('--module', action='store', type='string',
                      dest='module',
                      metavar='<module>',
                      default='all',
                      help='Select a module to be executed. Defaults to all')

    parser.add_option('--cm-host', action='store', type='string',
                      dest='cm_host',
                      metavar='<cm_host>',
                      help='Cloudera Manager host.')

    parser.add_option('--output-dir', action='store', type='string',
                      dest='output_dir',
                      metavar='<output_dir>',
                      help='Output of the discovery bundle')

    parser.add_option('--time-range', action='store', type='int',
                      dest='time_range_in_days', default=45,
                      metavar='<time_range_in_days>',
                      help='Time range in days to collect metrics. Defaults to 45 days.')

    parser.add_option('--disable-redaction', action='store_false',
                      dest='sensitive_values_redacted', default=True,
                      metavar='<sensitive_values_redacted>',
                      help='Option to disable redaction. If option not set, it defaults to redacting sensitive values.')

    (options, args) = parser.parse_args()
    if not options.cm_host:  # if cm details is not given
        parser.error('--cm-host not given')
    if not options.output_dir:  # if output directory is not given
        parser.error('Output directory not given')
    now = datetime.datetime.now()
    dt_string = now.strftime("%d_%m_%Y_%H_%M_%S")

    module, cm_host, output_dir, time_range_in_days, sensitive_values_redacted = options.module, options.cm_host, options.output_dir, options.time_range_in_days, options.sensitive_values_redacted

    output_dir = output_dir + "_" + dt_string

    create_directory(f'{output_dir}/logs')
    with open(os.path.join(root_path, 'config', 'log-config.yaml'), 'r') as stream:
        log_config = yaml.load(stream, Loader=yaml.FullLoader)
        log_path = log_config['handlers']['file']['filename']
        log_config['handlers']['file']['filename'] = os.path.join(output_dir, log_path)
    logging.config.dictConfig(log_config)
    log = logging.getLogger('main')

    cm_user = config['credentials']['cm_user']
    cm_password = config['credentials']['cm_password']
    db_driver_path = config['database']['db_driver_path']
    cm_host = cm_host.rstrip('/')
    f = open(os.path.join(output_dir, "cm_url"), "w")
    f.write(cm_host)
    f.close()

    log.info("*** INVOCATION PARAMETERS START ***")
    log.info("*** module: %s", module)
    log.info("*** cm-host: %s", cm_host)
    log.info("*** output-dir: %s", output_dir)
    log.info("*** time-range: %s", time_range_in_days)
    log.info("*** disable-redaction: %s", (not sensitive_values_redacted))
    log.info("*** INVOCATION PARAMETERS END   ***")


    if not os.path.exists(db_driver_path):
        log.error(f"JDBC driver provided in config.ini does not exist at path: {db_driver_path}")
        exit(-1)

    end_timestamp = datetime.datetime.utcnow()
    log.info("Current timestamp to use in metric collection: %s", end_timestamp.replace(microsecond=0).isoformat())
    start_timestamp = end_timestamp - datetime.timedelta(days=time_range_in_days)
    log.info("Start timestamp to use in metric collection: %s", start_timestamp.replace(microsecond=0).isoformat())

    setup_cm_client(cm_host, cm_user, cm_password)
    try:
        clusters_response = cm_client.ClustersResourceApi().read_clusters()
    except Exception as err:
        log.error("Unable to connect to %s", cm_host)
        log.error("Verify if URL is correct, server is listening and reachable, and credentials are correct!")
        log.error("Message: %s", err)
        sys.exit(1)

    cluster_names = list(map(lambda cluster: cluster.display_name, clusters_response.items))

    threads = []

    if module == 'all' or module == 'cm_metrics':
        cm_metrics_extractor = CmMetricsExtractor(output_dir, cluster_names, start_timestamp, end_timestamp)
        threads.append(Thread(target=cm_metrics_extractor.collect_metrics, name="metrics_thread"))

    if module == 'all' or module == 'diagnostic_bundle':
        diagnostic_bundle_extractor = DiagnosticBundleExtractor(output_dir, start_timestamp, end_timestamp)
        threads.append(Thread(target=diagnostic_bundle_extractor.collect_diagnostic_bundle, name="diag_bundle_thread"))

    if module == 'all' or module == 'cm_api':
        cm_api_extractor = CmApiExtractor(output_dir, sensitive_values_redacted)
        threads.append(Thread(target=cm_api_extractor.collect_cm_api_diagnostic, name="cm_api_thread"))

    if module == 'all' or module == 'hdfs_report':
        hdfs_extractor = HdfsFsImageExtractor(output_dir)
        threads.append(Thread(target=hdfs_extractor.collect_fs_image_reports, name="hdfs_report_thread"))

    if module == 'all' or module == 'hive_metastore':
        HiveMetastoreExtractor(output_dir, db_driver_path).extract_hive_metastore()

    if module == 'all' or module == 'sentry_extractor':
        SentryPoliciesExtractor(output_dir, db_driver_path).extract_sentry_policies()

    yarn_workloads_to_collect = []

    if module == 'all' or module == 'mapreduce_extractor':
        yarn_workloads_to_collect.append("mapreduce")

    if module == 'spark_extractor':
        yarn_workloads_to_collect.append("spark")

    if module == 'all' or module == 'tez_extractor':
        yarn_workloads_to_collect.append("tez")

    if yarn_workloads_to_collect:
        threads.append(Thread(target=YarnWorkloadExtractor(output_dir, time_range_in_days).collect_workloads,
                              args=(yarn_workloads_to_collect,),
                              name="yarn_workloads_collector"))

    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    # Following modules depend on the diagnostic bundle export
    if module == 'all' or module == 'impala_profiles':
        impala_workload_extractor = ImpalaProfilesExtractor(output_dir)
        Thread(target=impala_workload_extractor.collect_impala_profiles, name="impala_profiles_thread").start()

    log.info(f"Finished discovery bundle extraction, results available at: {output_dir}")

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

import os
import sys

import yaml
import logging.config
from optparse import OptionParser
from threading import Thread
from utility import get_config_params, create_directory
from ambari_api_extarctor import AmbariApiExtractor
from hive_metastore_extractor import HiveMetastoreExtractor
from mr_workload_extractor import MapreduceExtractor
from spark_workload_extractor import SparkHistoryExtractor
from hdp_metrics_extractor import MetricsExtractor
from tez_workload_extractor import TezHistoryExtractor
from ranger_policy_extractor import RangerPolicyExtractor
from hdfs_fs_image_extractor import HdfsFsImageExtractor

root_path = os.path.dirname(os.path.realpath(__file__))

if __name__ == '__main__':

    parser = OptionParser(usage='%prog [options]')

    parser.add_option('--module', action='store', type='string',
                      dest='module',
                      metavar='<module>',
                      default='all',
                      help='all for building full discovery bundle, hdp_metrics extraction, ammbari_api extraction, hive_metastore for collecting hive metastore info. Defaults to all')

    (options, args) = parser.parse_args()

    module = options.module

    threads = []

    user_provided_config = get_config_params(os.path.join(root_path, 'conf', 'config.ini'))

    output_dir = user_provided_config['output_dir']
    create_directory(os.path.join(output_dir, 'logs'))
    with open(os.path.join(root_path, 'conf', 'log-config.yaml'), 'r') as stream:
        config = yaml.load(stream, Loader=yaml.FullLoader)
        log_path = config['handlers']['file']['filename']
        config['handlers']['file']['filename'] = os.path.join(output_dir, log_path)
    logging.config.dictConfig(config)
    log = logging.getLogger('main')

    for each in user_provided_config.values():
        if each == '':
            log.debug("check config.ini and pass all the values")
            sys.exit(1)

    if module == 'all' or module == 'ambari_api':
        ambari_api_extractor = AmbariApiExtractor(user_provided_config)
        threads.append(Thread(target=ambari_api_extractor.collect_ambari_api_diagnostic, name="ambari_api_thread"))

    if module == 'all' or module == 'hive_metastore':
        hive_ms_extractor = HiveMetastoreExtractor(user_provided_config)
        threads.append(Thread(target=hive_ms_extractor.collect_metastore_info, name="hive_ms_thread"))

    if module == 'all' or module == 'extract_metrics':
        metrics_extractor = MetricsExtractor(user_provided_config)
        threads.append(Thread(target=metrics_extractor.collect_metrics, name="metrics_collector_thread"))

    if module == 'all' or module == 'mapreduce_extractor':
        mapreduce_extractor = MapreduceExtractor(user_provided_config)
        threads.append(Thread(target=mapreduce_extractor.collect_mapreduce_job_histories(), name="mr_workload_thread"))

    if module == 'all' or module == 'spark_extractor':
        spark_extractor = SparkHistoryExtractor(user_provided_config)
        threads.append(Thread(target=spark_extractor.collect_spark_histories(), name="spark_workload_thread"))

    if module == 'all' or module == 'tez_extractor':
        tez_extractor = TezHistoryExtractor(user_provided_config)
        threads.append(Thread(target=tez_extractor.collect_tez_histories(), name="tez_workload_thread"))

    if module == 'all' or module == 'ranger_policy_extractor':
        ranger_extractor = RangerPolicyExtractor(user_provided_config)
        threads.append(Thread(target=ranger_extractor.get_ranger_policies(), name="ranger_policy_thread"))

    if module == 'all' or module == 'hdfs_report':
        hdfs_extractor = HdfsFsImageExtractor(user_provided_config)
        threads.append(Thread(target=hdfs_extractor.collect_fs_image_reports, name="hdfs_report_thread"))

    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    log.info(f"Finished discovery bundle extraction, results available at: {output_dir}")

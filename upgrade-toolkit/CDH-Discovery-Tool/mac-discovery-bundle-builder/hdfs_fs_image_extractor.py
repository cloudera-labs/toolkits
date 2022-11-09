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
import os
import os.path
import shutil
import zipfile
from datetime import datetime
from pathlib import Path

import cm_client

from discovery_bundle_builder_utils import create_directory, run_cmd

log = logging.getLogger('main')


class HdfsFsImageExtractor:
    def __init__(self, output_dir):
        self.output_dir = output_dir
        self.services_resource = cm_client.ServicesResourceApi()

    def collect_fs_image_reports(self):
        cm_deployment = cm_client.ClouderaManagerResourceApi().get_deployment2()
        for cluster in cm_deployment.clusters:
            self.collect_fs_image_report_from_cluster(cluster)

    def collect_fs_image_report_from_cluster(self, cluster):
        cluster_name = cluster.display_name
        log.debug(f"Checking if HDFS is deployed on {cluster_name}")
        hdfs_service = next(filter(lambda service: service.type == "HDFS", cluster.services), None)
        if not hdfs_service:
            log.debug(f"HDFS is not deployed on cluster service deployed on cluster: {cluster_name}")
            return
        client_config_path = self.fetch_client_config(cluster_name, hdfs_service.name)
        hdfs_policies_output_dir = os.path.join(self.output_dir, "workload", cluster.display_name.replace(" ", "_"), "service",
                                                hdfs_service.name)
        create_directory(hdfs_policies_output_dir)

        fs_image_path = os.path.join(hdfs_policies_output_dir,
                                     f"dfs_image_{cluster_name.replace(' ', '_')}_{datetime.utcnow().isoformat()}")
        run_cmd(['hdfs', '--config', client_config_path, 'dfsadmin', '-fetchImage', fs_image_path])

        # if previous command fails, necessary input file for the following command will be missing, output meaningful error message instead
        if os.path.exists(fs_image_path):
            hdfs_fs_csv_path = os.path.join(hdfs_policies_output_dir, "hdfs_fs.csv")
            run_cmd(
                ['hdfs', 'oiv', '-p', 'Delimited', '-delimiter', '","', '-i',
                 fs_image_path, '-o', hdfs_fs_csv_path])
	    os.remove(fs_image_path)
            return hdfs_fs_csv_path
        else:
            log.error("No local FSImage copy could be created due to previous error - skipping CSV conversion!")
            return

    def fetch_client_config(self, cluster_name, hdfs_service_name):
        response = self.services_resource.get_client_config(cluster_name=cluster_name,
                                                            service_name=hdfs_service_name,
                                                            _preload_content=False)
        client_config_dir = os.path.join("/tmp", "hdfs_report", cluster_name.replace(" ", "_"))
        create_directory(client_config_dir)
        with open(os.path.join(client_config_dir, "client_config.zip"), 'wb') as fd:
            fd.write(response.data)
        with zipfile.ZipFile(os.path.join(client_config_dir, "client_config.zip"), 'r') as zip_ref:
            zip_ref.extractall(client_config_dir)
        dest_directory = next(Path(client_config_dir).rglob("core-site.xml")).parent
        log.debug(f"Destination directory: {dest_directory}")
        self.update_ssl_config(dest_directory)
        return dest_directory.__str__()

    def update_ssl_config(self, destination_path):
        ssl_config_path = None
        truststores = Path("/var/run/cloudera-scm-agent/process/").rglob("*truststore*.jks")
        for truststore in truststores:
            configs = Path(truststore.parent).rglob("ssl-client.xml")
            for config in configs:
                ssl_config_path = config
                break
            if ssl_config_path:
                break
        if not ssl_config_path and os.path.exists("/etc/hadoop/conf/ssl-client.xml"):
            ssl_config_path = "/etc/hadoop/conf/ssl-client.xml"
        try:
            log.debug(f"SSL config path: {ssl_config_path}")
            log.debug(f"copying to {os.path.join(destination_path, 'ssl-client.xml')}")
            shutil.copy(ssl_config_path,
                        os.path.join(destination_path, "ssl-client.xml"))
        except:
            log.error(f"Unable to copy file from source: {ssl_config_path}")

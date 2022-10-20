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

import logging
import os
import shutil
import time
from pathlib import Path
from urllib.parse import urlparse
from zipfile import ZipFile

import cm_client
import requests as requests
from cm_client import ApiCollectDiagnosticDataArguments

log = logging.getLogger('main')


def create_directory(dir_path):
    path = Path(dir_path)
    path.mkdir(parents=True, exist_ok=True)


class DiagnosticBundleExtractor:
    def __init__(self, output_dir, start_timestamp, end_timestamp):
        self.output_dir = output_dir
        self.extracted_diag_bundle_path = os.path.join(output_dir, 'extracted_raw_diagnostic_bundle')
        self.bundle_output_dir = os.path.join(output_dir, 'bundle')
        self.start_timestamp = start_timestamp
        self.end_timestamp = end_timestamp
        self.clusters_resource_api = cm_client.ClouderaManagerResourceApi()
        self.command_resource_api = cm_client.CommandsResourceApi()
        self.hosts_resource_api = cm_client.HostsResourceApi()
        self.setup_output_dirs()

    def setup_output_dirs(self):
        create_directory(self.extracted_diag_bundle_path)
        create_directory(self.bundle_output_dir)

    def collect_diagnostic_bundle(self):
        log.info("Diagnostic bundle collection started.")
        self.fetch_diagnostic_bundle()
        self.collect_host_info()
        log.info("Diagnostic bundle collection finished.")

    def fetch_diagnostic_bundle(self):
        arguments = ApiCollectDiagnosticDataArguments(
            start_time=self.start_timestamp.replace(microsecond=0).isoformat(),
            end_time=self.end_timestamp.replace(microsecond=0).isoformat())
        api_response = self.clusters_resource_api.collect_diagnostic_data_command(body=arguments)
        command_id = int(api_response.id)
        self.wait_for_command_to_finish(command_id)
        self.unzip_diagnostic_bundle(command_id)
        log.debug("Diagnostic bundle collection finished.")

    def wait_for_command_to_finish(self, command_id):
        log.info("Waiting for %s command to succeed.", command_id)
        while True:
            command_response = self.command_resource_api.read_command(command_id=command_id)
            log.info("Command %s is active: %s", command_id, command_response.active)
            if not command_response.active:
                if command_response.success:
                    log.debug("Command finished successfully")
                    break
                else:
                    log.error("Command is not finished with id: %s. Unable to collect diagnostic bundles", command_id)
                    exit(-1)
            time.sleep(15)

    def unzip_diagnostic_bundle(self, command_id):
        log.debug("Diagnostic bundle available remotely, downloading from CM.")
        diagnostic_bundle_local_path = os.path.join(self.output_dir, f"{command_id}-scm-command-result.zip")
        config = cm_client.configuration
        api_url = urlparse(config.host)
        with requests.get(f"{api_url.scheme}://{api_url.netloc}/cmf/command/{command_id}/download",
                          auth=(config.username, config.password), verify=False, stream=True) as r:
            r.raise_for_status()
            with open(diagnostic_bundle_local_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
        log.debug("Unzipping diagnostic bundle from: %s", diagnostic_bundle_local_path)
        with ZipFile(diagnostic_bundle_local_path, 'r') as zipObj:
            zipObj.extractall(self.extracted_diag_bundle_path)
            log.debug("Diagnostic bundle unzipped at: %s", self.extracted_diag_bundle_path)
        for sub_zip_folder in Path(self.extracted_diag_bundle_path).rglob("*.zip"):
            ZipFile(sub_zip_folder, 'r').extractall(Path(sub_zip_folder).parent.absolute())
        os.remove(diagnostic_bundle_local_path)

    def collect_host_info(self):
        list_hosts = self.hosts_resource_api.read_hosts().items
        for host in list_hosts:
            create_directory(os.path.join(self.bundle_output_dir, host.hostname))
            host_statistic_path = os.path.join(self.extracted_diag_bundle_path,
                                               f"{host.hostname}-{host.host_id}-{host.ip_address}-host-statistics",
                                               "sysstats")
            host_statistic_dest_path = os.path.join(self.bundle_output_dir, host.hostname)
            self.collect_cpu_info(host_statistic_path, host_statistic_dest_path)
            self.collect_os_info(host_statistic_path, host_statistic_dest_path)
            self.collect_java_info(host_statistic_path, host_statistic_dest_path)
            self.collect_krb5_info(host_statistic_path, host_statistic_dest_path)
            self.collect_disk_info(host_statistic_path, host_statistic_dest_path)

    def collect_cpu_info(self, source_directory, destination_directory):
        file_name = "lscpu_stdout"
        try:
            shutil.copyfile(os.path.join(source_directory, file_name),
                            os.path.join(destination_directory, file_name))
        except FileNotFoundError as error:
            log.error(f"Unable to copy file. {error}")

    def collect_os_info(self, source_directory, destination_directory):
        file_name = "lsb_release_stdout"
        try:
            shutil.copyfile(os.path.join(source_directory, file_name),
                            os.path.join(destination_directory, file_name))
        except FileNotFoundError as error:
            log.error(f"Unable to copy file. {error}")

    def collect_java_info(self, source_directory, destination_directory):
        file_name = ''
        if os.path.exists(os.path.join(source_directory, "java_version_stdout")) and os.stat(os.path.join(source_directory, "java_version_stdout")).st_size != 0:
            file_name = "java_version_stdout"
        elif os.path.exists(os.path.join(source_directory, "java_version_stderr")) and os.stat(os.path.join(source_directory, "java_version_stderr")).st_size != 0:
            file_name = "java_version_stderr"
        if file_name:
            try:
                shutil.copyfile(os.path.join(source_directory, file_name),
                                os.path.join(destination_directory, "java_version"))
            except FileNotFoundError as error:
                log.error(f"Unable to copy file. {error}")
        else: 
            log.warn(f"Neither java_version_stdout nor java_version_stderr could be found in {source_directory}. Expect Discovery Report Builder to issue corresponding error message.")

    def collect_disk_info(self, source_directory, destination_directory):
        file_name = "df_stdout"
        try:
            shutil.copyfile(os.path.join(source_directory, file_name),
                            os.path.join(destination_directory, file_name))
        except FileNotFoundError as error:
            log.error(f"Unable to copy file. {error}")

    def collect_krb5_info(self, source_directory, destination_directory):
        file_name = "krb5_stdout"
        try:
            shutil.copyfile(os.path.join(source_directory, file_name),
                            os.path.join(destination_directory, file_name))
        except FileNotFoundError as error:
            log.error(f"Unable to copy file. {error}")

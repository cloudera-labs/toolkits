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
import re

from pathlib import Path

import numpy as np
import pandas as pd
import requests
from requests.auth import HTTPBasicAuth

from utility import create_directory, run_cmd, dump_json

log = logging.getLogger('main')

module_output_prefix = "workload"


def get_parent_path(path):
    matched = re.match("((?:[^/]*/)*)(.*)?", path)
    path = matched.group(1)
    return path if path == "/" else path[:-1]


def count_depth(path):
    return 0 if path == '/' else path.count('/')


class HdfsFsImageExtractor:
    def __init__(self, ambari_conf, default_level=4):
        self.ambari_server_host = ambari_conf['ambari_server_host']
        self.ambari_server_port = ambari_conf['ambari_server_port']
        self.ambari_http_protocol = ambari_conf['ambari_http_protocol']
        self.api_output_dir = ambari_conf['output_dir']
        self.ambari_user = ambari_conf['ambari_user']
        self.ambari_pass = ambari_conf['ambari_pass']
        self.ambari_server_timeout = ambari_conf['ambari_server_timeout']
        self.url_suffix = ""
        self.host_list = []
        self.service_list = []
        create_directory(self.api_output_dir + "/" + module_output_prefix)
        self.cluster_name = self.get_cluster_name()
        self.output_dir = self.api_output_dir
        self.prev_df = pd.DataFrame()
        self.collector_df = pd.DataFrame()
        self.default_level = default_level

    def collect_fs_image_reports(self):
        cluster = self.cluster_name
        hdfs_fs_csv_path = self.collect_fs_image_report_from_cluster(cluster)
        self.prev_df = pd.DataFrame()
        self.collector_df = pd.DataFrame()
        self.create_csv_report(hdfs_fs_csv_path)

    def collect_fs_image_report_from_cluster(self, cluster):
        log.debug(f"Checking if HDFS is deployed on {cluster}")
        hdfs_policies_output_dir = os.path.join(self.output_dir, "workload", cluster, "service")
        create_directory(hdfs_policies_output_dir)

        fs_image_path = os.path.join("/tmp", "dfs_image_{cluster}_{datetime.utcnow().isoformat()}")
        run_cmd(['hdfs', 'dfsadmin', '-fetchImage', fs_image_path])
        hdfs_fs_csv_path = os.path.join(hdfs_policies_output_dir, "hdfs_fs.csv")
        run_cmd(
            ['hdfs', 'oiv', '-p', 'Delimited', '-delimiter', '","', '-i',
             fs_image_path, '-o', hdfs_fs_csv_path])
        return hdfs_fs_csv_path

    def create_csv_report(self, hdfs_fs_csv_path):
        df = pd.read_csv(hdfs_fs_csv_path, on_bad_lines='skip')
        reduced_df = df.loc[:, ('Path', 'FileSize', 'BlocksCount')]
        reduced_df['Depth'] = (df.apply(lambda x: count_depth(x['Path']), axis=1))
        reduced_df['FileCount'] = np.select([df['Replication'] > 0], [1], 0)
        reduced_df['DirectoryCount'] = np.select([df['Replication'] == 0], [1], 0)
        reduced_df['SmallFile'] = np.select([df['FileSize'] < df['PreferredBlockSize']], [1], 0)
        reduced_df['SmallFile10'] = np.select([df['FileSize'] < df['PreferredBlockSize'] / 10], [1], 0)
        reduced_df['SmallFile1000'] = np.select([df['FileSize'] < df['PreferredBlockSize'] / 1000], [1], 0)
        groups = reduced_df.groupby('Depth')

        for i in range(len(groups) - 1, 0, -1):
            group = groups.get_group(i)
            self.__aggregate_tree_level(group, i - 1)
        self.collector_df.iloc[::-1].to_csv(os.path.join(Path(hdfs_fs_csv_path).parent, "hdfs_report.csv"), index=False)

    def __aggregate_tree_level(self, group, level):
        group = group.append(self.prev_df, ignore_index=True)
        directories = group.drop_duplicates(subset=['Path'], keep=False)
        directories = directories[directories['DirectoryCount'] > 0]
        if not directories.empty:
            self.__add_to_collector(directories, level)
        group['ParentPath'] = (group.apply(lambda x: get_parent_path(x['Path']), axis=1))
        aggregated_df = group.groupby('ParentPath', as_index=False).agg(
            DirectoryCount=pd.NamedAgg(column="DirectoryCount", aggfunc="sum"),
            FileCount=pd.NamedAgg(column="FileCount", aggfunc="sum"),
            SmallFile=pd.NamedAgg(column="SmallFile", aggfunc="sum"),
            SmallFile10=pd.NamedAgg(column="SmallFile10", aggfunc="sum"),
            SmallFile1000=pd.NamedAgg(column="SmallFile1000", aggfunc="sum"),
            BlocksCount=pd.NamedAgg(column="BlocksCount", aggfunc="sum"),
            FileSize=pd.NamedAgg(column="FileSize", aggfunc="sum")
        )
        aggregated_df.rename(columns={'ParentPath': 'Path'}, inplace=True)
        aggregated_df["Depth"] = level
        self.prev_df = aggregated_df
        aggregated_df["AvgFileSize"] = aggregated_df['FileSize'].div(aggregated_df['FileCount'])
        self.__add_to_collector(aggregated_df, level)

    def __add_to_collector(self, group, level):
        if level < self.default_level:
            self.collector_df = self.collector_df.append(group)

    def get_cluster_name(self):
        try:
            r = requests.get(
                self.ambari_http_protocol + "://" + self.ambari_server_host + ":" + self.ambari_server_port + "/api/v1/clusters",
                auth=HTTPBasicAuth(self.ambari_user, self.ambari_pass),verify=False)

        except requests.exceptions.RequestException as e:
            log.debug(
                "Issue connecting to ambari server. Please check the process is up and running and responding as expected.")
            raise SystemExit(e)
        return r.json()['items'][0]['Clusters']['cluster_name']

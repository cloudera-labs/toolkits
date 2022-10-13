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
import re
from pathlib import Path

import numpy as np
import pandas as pd


class HdfsReportBuilder:
    def __init__(self, hdfs_report_depth):
        self.prev_df = pd.DataFrame()
        self.collector_df = pd.DataFrame()
        self.default_level = hdfs_report_depth

    def get_parent_path(self, path):
        matched = re.match("((?:[^/]*/)*)(.*)?", path)
        path = matched.group(1)
        return path if path == "/" else path[:-1]

    def count_depth(self, path):
        return 0 if path == '/' else path.count('/')

    def create_csv_report(self, hdfs_fs_csv_path):
        output_path = Path(hdfs_fs_csv_path).parent
        cluster_name = output_path.parent.parent.name
        df = pd.read_csv(hdfs_fs_csv_path)
        self.__create_hdfs_modification_report(df, output_path, cluster_name)
        self.__create_hdfs_tree_report(df, output_path)

    def __create_hdfs_tree_report(self, df, output_path):
        reduced_df = df.loc[:, ('Path', 'FileSize', 'BlocksCount')]
        reduced_df['Depth'] = (df.apply(lambda x: self.count_depth(x['Path']), axis=1))
        reduced_df['FileCount'] = np.select([df['Replication'] > 0], [1], 0)
        reduced_df['DirectoryCount'] = np.select([df['Replication'] == 0], [1], 0)
        reduced_df['SmallFile'] = np.select([df['FileSize'] < df['PreferredBlockSize']], [1], 0)
        reduced_df['SmallFile10'] = np.select([df['FileSize'] < df['PreferredBlockSize'] / 10], [1], 0)
        reduced_df['SmallFile1000'] = np.select([df['FileSize'] < df['PreferredBlockSize'] / 1000], [1], 0)
        depth_aggregated_groups = reduced_df.groupby('Depth')

        for depth in sorted(depth_aggregated_groups.groups.keys(), reverse=True):
            if depth == 0:
                break
            depth_aggregated_group = depth_aggregated_groups.get_group(depth)
            self.__aggregate_tree_level(depth_aggregated_group, depth)
        self.collector_df.iloc[::-1].to_csv(os.path.join(output_path, "hdfs_structure_report.csv"), index=False,
                                            columns=["Path", "FileSize", "BlocksCount", "Depth", "FileCount",
                                                     "DirectoryCount", "SmallFile", "SmallFile10", "SmallFile1000",
                                                     "AvgFileSize"])

    def __aggregate_tree_level(self, group, level):
        group = group.append(self.prev_df, ignore_index=True)
        directories = group.drop_duplicates(subset=['Path'], keep=False)
        directories = directories[directories['DirectoryCount'] > 0]
        if not directories.empty:
            directories['DirectoryCount'] = 0
            self.__add_to_collector(directories, level)
        group['ParentPath'] = (group.apply(lambda x: self.get_parent_path(x['Path']), axis=1))
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
        parent_level = level - 1
        aggregated_df["Depth"] = parent_level
        self.prev_df = aggregated_df
        aggregated_df["AvgFileSize"] = aggregated_df['FileSize'].div(aggregated_df['FileCount'])
        self.__add_to_collector(aggregated_df, parent_level)

    def __add_to_collector(self, group, level):
        if level <= self.default_level:
            self.collector_df = self.collector_df.append(group)

    def __create_hdfs_modification_report(self, df, output_path, cluster_name):
        modification_time_aggregation = (pd.to_datetime(df['ModificationTime'])
                                         .dt.floor('d')
                                         .value_counts()
                                         .rename_axis('Date')
                                         .reset_index(name='Count'))
        modification_time_aggregation['ClusterName'] = cluster_name
        modification_time_aggregation.to_csv(os.path.join(output_path, "hdfs_modification_times.csv"),
                                             index=False,
                                             columns=["ClusterName", "Date", "Count"])

        del modification_time_aggregation

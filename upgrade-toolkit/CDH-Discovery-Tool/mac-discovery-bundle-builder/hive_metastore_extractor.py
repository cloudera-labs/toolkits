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
import logging.config
import os
from pathlib import Path

import cm_client
import jaydebeapi

root_path = os.path.dirname(os.path.realpath(__file__))
log = logging.getLogger('main')

psql = {
    'driver_class': 'org.postgresql.Driver',
    'query': 'select "NAME" as "DB_NAME", "TBL_NAME","PART_NAME" IS NOT NULL as "IS_PARTITIONED","PKEY_NAME", count("PKEY_NAME") as "PARTITION_COUNT","TBL_TYPE","DB_LOCATION_URI", "LOCATION" from "TBLS" join "DBS" on "DBS"."DB_ID"="TBLS"."DB_ID" left join "PARTITIONS" on "TBLS"."TBL_ID"="PARTITIONS"."TBL_ID" left join "PARTITION_KEYS" on "PARTITION_KEYS"."TBL_ID"="TBLS"."TBL_ID" left join "SDS" on "TBLS"."SD_ID"="SDS"."SD_ID" group by "NAME", "TBL_NAME", "PART_NAME" IS NOT NULL, "PKEY_NAME", "TBL_TYPE", "DB_LOCATION_URI", "LOCATION";',
    'jdbc_format': 'jdbc:{db_type}://{db_host}:{db_port}/{db_name}'
}

mysql = {
    'driver_class': 'com.mysql.jdbc.Driver',
    'query': 'select name as DB_NAME, tbl_name as TBL_NAME, PART_NAME IS NOT NULL as IS_PARTITIONED, PKEY_NAME, count(PKEY_NAME) as PARTITION_COUNT, tbl_type as TBL_TYPE, db_location_uri as DB_LOCATION_URI, LOCATION from TBLS join DBS on TBLS.db_id=DBS.db_id left join PARTITIONS on TBLS.tbl_id=PARTITIONS.tbl_id left join PARTITION_KEYS on PARTITION_KEYS.tbl_id=TBLS.tbl_id left join SDS on TBLS.SD_ID=SDS.SD_ID group by name, tbl_name,  PART_NAME IS NOT NULL, PKEY_NAME, tbl_type, db_location_uri, LOCATION;',
    'jdbc_format': 'jdbc:{db_type}://{db_host}:{db_port}/{db_name}'
}

oracle = {
    'driver_class': 'oracle.jdbc.driver.OracleDriver',
    'query': "select name as DB_NAME , tbl_name as TBL_NAME, case nvl(PKEY_NAME,'false') when 'false' then 'f' else 't' end as IS_PARTITIONED, PKEY_NAME, count(PKEY_NAME) as PARTITION_COUNT, tbl_type as TBL_TYPE , db_location_uri as DB_LOCATION_URI, LOCATION from TBLS join DBS on TBLS.db_id=DBS.db_id left join PARTITIONS on TBLS.tbl_id=PARTITIONS.tbl_id left join PARTITION_KEYS on PARTITION_KEYS.tbl_id=TBLS.tbl_id left join SDS on TBLS.SD_ID=SDS.SD_ID group by name, tbl_name, case nvl(PKEY_NAME,'false') when 'false' then 'f' else 't' end, PKEY_NAME, tbl_type,  db_location_uri, LOCATION;",
    'jdbc_format': 'jdbc:{db_type}:thin:@{db_host}:{db_port}/{db_name}'
}

db_constants = {
    'postgresql': psql,
    'mysql': mysql,
    'mariadb': mysql,
    'oracle': oracle
}


def create_directory(dir_path):
    path = Path(dir_path)
    path.mkdir(parents=True, exist_ok=True)


def write_csv(columns, rows, output):
    csv_file = open(output, mode='w')
    writer = csv.writer(csv_file, delimiter=',', lineterminator="\n")
    writer.writerow(columns)
    for row in rows:
        writer.writerow(row)
    log.debug(f"CSV write finished, results at: {output}")


class HiveMetastoreExtractor:
    def __init__(self, output_dir, db_driver_path):
        self.output_dir = output_dir
        self.services_resource = cm_client.ServicesResourceApi()
        self.cloudera_manager_resource = cm_client.ClouderaManagerResourceApi()
        self.db_driver_path = db_driver_path

    def extract_hive_metastore(self):
        log.info("Started Hive metastore extraction")
        clusters = self.cloudera_manager_resource.get_deployment2().clusters
        for cluster in clusters:
            for service in cluster.services:
                hive_metastore_role = next(filter(lambda rcg: rcg.type == "HIVEMETASTORE", service.roles), None)
                if hive_metastore_role:
                    log.debug(f"Hive Metastore deployed on {cluster.display_name} cluster under {service.name} service.")
                    hive_ms_output_dir = os.path.join(self.output_dir, "workload", cluster.display_name.replace(" ", "_"), "service",
                                                      service.name)
                    create_directory(hive_ms_output_dir)

                    self.collect_metastore_info(cluster.display_name, service.name, hive_ms_output_dir)
        log.info("Finished Hive metastore extraction")

    def collect_metastore_info(self, cluster_name, service_name, output_dir):
        configs = self.services_resource.read_service_config(cluster_name, service_name, view="FULL").items
        db_type_config = next(filter(lambda config: config.name == 'hive_metastore_database_type', configs))
        db_host_config = next(filter(lambda config: config.name == 'hive_metastore_database_host', configs))
        db_port_config = next(filter(lambda config: config.name == 'hive_metastore_database_port', configs))
        db_name_config = next(filter(lambda config: config.name == 'hive_metastore_database_name', configs))
        db_user_config = next(filter(lambda config: config.name == 'hive_metastore_database_user', configs))
        db_password_config = next(filter(lambda config: config.name == 'hive_metastore_database_password', configs))
        db_type = self.get_config_value(db_type_config)
        db_host = self.get_config_value(db_host_config)
        db_port = self.get_config_value(db_port_config)
        db_name = self.get_config_value(db_name_config)
        db_user = self.get_config_value(db_user_config)
        db_password = self.get_config_value(db_password_config)
        db_constant = db_constants.get(db_type)
        if not db_constant:
            log.error(f"Unsupported database type: {db_type}, exiting thread.")
            exit(-1)
        log.debug(f"Connecting to {db_name} database on {db_host}")
        conn = jaydebeapi.connect(
            db_constant['driver_class'],
            db_constant['jdbc_format'].format(db_type=db_type, db_host=db_host, db_port=db_port, db_name=db_name),
            [f'{db_user}', f'{db_password}'],
            self.db_driver_path)
        curs = conn.cursor()
        log.debug(f"Executing query: {db_constant['query']}")
        curs.execute(db_constant['query'])
        columns = [column_description[0] for column_description in curs.description]
        rows = curs.fetchall()
        write_csv(columns, rows, os.path.join(output_dir, f"hive_ms.csv"))
        conn.close()
        log.debug("Hive Metastore collection finished.")

    @staticmethod
    def get_config_value(config):
        log.debug(f"Config name: {config.name}, value: {config.value if not config.sensitive else '*******'}, default value: {config.default}")
        config_value = config.value if config.value is not None else config.default
        if config_value is None:
            log.error(f"Config value is not found for {config.name}, exiting thread.")
            exit(-1)
        log.debug(f"Using {config_value if not config.sensitive else '*******'} for config {config.name}")
        return config.value if config.value is not None else config.default

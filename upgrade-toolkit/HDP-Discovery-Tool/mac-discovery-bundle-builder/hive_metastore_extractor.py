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
import logging
import jaydebeapi
import requests.exceptions

from utility import create_directory, write_csv

root_path = os.path.dirname(os.path.realpath(__file__))
log = logging.getLogger('main')
log.setLevel(logging.INFO)

psql = {
    'driver_class': 'org.postgresql.Driver',
    'query': 'select "NAME" as "DB_NAME", "TBL_NAME","PART_NAME" IS NOT NULL as "IS_PARTITIONED","PKEY_NAME", count("PKEY_NAME") as "PARTITION_COUNT","TBL_TYPE","DB_LOCATION_URI", "LOCATION" from "TBLS" join "DBS" on "DBS"."DB_ID"="TBLS"."DB_ID" left join "PARTITIONS" on "TBLS"."TBL_ID"="PARTITIONS"."TBL_ID" left join "PARTITION_KEYS" on "PARTITION_KEYS"."TBL_ID"="TBLS"."TBL_ID" left join "SDS" on "TBLS"."SD_ID"="SDS"."SD_ID" group by "NAME", "TBL_NAME", "PART_NAME" IS NOT NULL, "PKEY_NAME", "TBL_TYPE", "DB_LOCATION_URI", "LOCATION";'
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

class HiveMetastoreExtractor:
    def __init__(self, ambari_conf):
        self.output_dir = ambari_conf['output_dir']
        self.hive_metastore_type = ambari_conf['hive_metastore_type']
        self.hive_metastore_server = ambari_conf['hive_metastore_server']
        self.hive_metastore_server_port = ambari_conf['hive_metastore_server_port']
        self.hive_metastore_database_name = ambari_conf['hive_metastore_database_name']
        self.hive_metastore_database_user = ambari_conf['hive_metastore_database_user']
        self.hive_metastore_database_password = ambari_conf['hive_metastore_database_password']
        self.hive_metastore_database_driver_path = ambari_conf['hive_metastore_database_driver_path']

    def collect_metastore_info(self):
        db_type = self.hive_metastore_type
        db_host = self.hive_metastore_server
        db_port = self.hive_metastore_server_port
        db_name = self.hive_metastore_database_name
        db_user = self.hive_metastore_database_user
        db_password = self.hive_metastore_database_password
        db_constant = db_constants.get(db_type)
        db_path = self.hive_metastore_database_driver_path

        if not os.path.exists(db_path):
            log.error(f"JDBC driver does not exist at the provided path: {db_path}")
            exit(-1)

        create_directory(os.path.join(self.output_dir, "workload", "hive"))

        if not db_constant:
            log.error("Unsupported database type: {db_type}")
            exit(-1)
        log.debug(f"Connecting to {db_name} database on {db_host}")
        try:
            conn = jaydebeapi.connect(db_constant['driver_class'],db_constant['jdbc_format'].format(db_type=db_type, db_host=db_host, db_port=db_port, db_name=db_name),[db_user, db_password],db_path)
        except Exception as e:
            log.error("jaydebeapi.connect didn't went well:" + str(e))
            log.error("Please verify if 1) Database server details 2) server is up and running 3) Server is responding as expected")
        curs = conn.cursor()
        log.debug("Executing query: {db_constant['query']}")
        curs.execute(db_constant['query'])
        columns = [column_description[0] for column_description in curs.description]
        rows = curs.fetchall()
        write_csv(columns, rows, os.path.join(self.output_dir, "workload/hive/", "hive_ms.csv"))
        log.debug("Hive Metastore collection finished.")

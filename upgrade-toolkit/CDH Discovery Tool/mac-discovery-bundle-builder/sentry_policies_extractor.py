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


mysql = {
    'driver_class': 'com.mysql.jdbc.Driver',
    'query': '(select "HIVE" as SERVICE_TYPE, u.USER_NAME, null as GROUP_NAME, null as ROLE_NAME, p.PRIVILEGE_SCOPE, p.SERVER_NAME, p.DB_NAME, p.TABLE_NAME, p.COLUMN_NAME, null as RESOURCE_NAME_0, null as RESOURCE_NAME_1, null as RESOURCE_NAME_2, null as RESOURCE_NAME_3, null as RESOURCE_TYPE_0, null as RESOURCE_TYPE_1, null as RESOURCE_TYPE_2, null as RESOURCE_TYPE_3, p.URI, p.ACTION, p.WITH_GRANT_OPTION from SENTRY_USER u join SENTRY_USER_DB_PRIVILEGE_MAP up on up.USER_ID = u.USER_ID join SENTRY_DB_PRIVILEGE p on p.DB_PRIVILEGE_ID = up.DB_PRIVILEGE_ID) UNION ALL (select "HIVE" as SERVICE_TYPE, null as USER_NAME, g.GROUP_NAME, r.ROLE_NAME, p.PRIVILEGE_SCOPE, p.SERVER_NAME, p.DB_NAME, p.TABLE_NAME, p.COLUMN_NAME, p.URI, null as RESOURCE_NAME_0, null as RESOURCE_NAME_1, null as RESOURCE_NAME_2, null as RESOURCE_NAME_3, null as RESOURCE_TYPE_0, null as RESOURCE_TYPE_1, null as RESOURCE_TYPE_2, null as RESOURCE_TYPE_3, p.ACTION, p.WITH_GRANT_OPTION from SENTRY_ROLE_GROUP_MAP rg join SENTRY_ROLE r on r.ROLE_ID = rg.ROLE_ID join SENTRY_ROLE_DB_PRIVILEGE_MAP rp on rp.ROLE_ID = r.ROLE_ID join SENTRY_DB_PRIVILEGE p on p.DB_PRIVILEGE_ID = rp.DB_PRIVILEGE_ID join SENTRY_GROUP g on g.GROUP_ID = rg.GROUP_ID) UNION ALL (select upper(p.COMPONENT_NAME) as SERVICE_TYPE, null as USER_NAME, g.GROUP_NAME, r.ROLE_NAME, upper(p.SCOPE) as PRIVILEGE_SCOPE, null as SERVER_NAME, null as DB_NAME, null as TABLE_NAME, null as COLUMN_NAME, null as URI, p.RESOURCE_NAME_0, p.RESOURCE_NAME_1, p.RESOURCE_NAME_2, p.RESOURCE_NAME_3, p.RESOURCE_TYPE_0, p.RESOURCE_TYPE_1, p.RESOURCE_TYPE_2, p.RESOURCE_TYPE_3, p.ACTION, p.WITH_GRANT_OPTION from SENTRY_GROUP g join SENTRY_ROLE_GROUP_MAP rg on rg.GROUP_ID = g.GROUP_ID join SENTRY_ROLE r on r.ROLE_ID = rg.ROLE_ID join SENTRY_ROLE_GM_PRIVILEGE_MAP rp on rp.ROLE_ID = r.ROLE_ID join SENTRY_GM_PRIVILEGE p on p.GM_PRIVILEGE_ID = rp.GM_PRIVILEGE_ID) ;',
    'jdbc_format': 'jdbc:{db_type}://{db_host}:{db_port}/{db_name}'
}


db_constants = {
    'mysql': mysql,
    'mariadb': mysql
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

class SentryPoliciesExtractor:
    def __init__(self, output_dir, db_driver_path):
        self.output_dir = output_dir
        self.services_resource = cm_client.ServicesResourceApi()
        self.cloudera_manager_resource = cm_client.ClouderaManagerResourceApi()
        self.db_driver_path = db_driver_path

    def extract_sentry_policies(self):
        log.info("Started Sentry policy extraction")
        clusters = self.cloudera_manager_resource.get_deployment2().clusters
        for cluster in clusters:
            for service in cluster.services:
                sentry_server_role = next(filter(lambda rcg: rcg.type == "SENTRY_SERVER", service.roles), None)
                if sentry_server_role:
                    log.debug(f"Sentry Server deployed on {cluster.display_name} cluster under {service.name} service.")
                    sentry_policies_output_dir = os.path.join(self.output_dir, "workload", cluster.display_name.replace(" ", "_"), "service",
                                                      service.name)
                    create_directory(sentry_policies_output_dir)

                    self.collect_sentry_policies_info(cluster.display_name, service.name, sentry_policies_output_dir)
        log.info("Finished Sentry policy extraction")

    def collect_sentry_policies_info(self, cluster_name, service_name, output_dir):
        configs = self.services_resource.read_service_config(cluster_name, service_name).items
        db_type = next(filter(lambda config: config.name == 'sentry_server_database_type', configs)).value
        db_host = next(filter(lambda config: config.name == 'sentry_server_database_host', configs)).value
        db_port = next(filter(lambda config: config.name == 'sentry_server_database_port', configs)).value
        db_name = next(filter(lambda config: config.name == 'sentry_server_database_name', configs)).value
        db_user = next(filter(lambda config: config.name == 'sentry_server_database_user', configs)).value
        db_password = next(filter(lambda config: config.name == 'sentry_server_database_password', configs)).value
        db_constant = db_constants.get(db_type)
        if not db_constant:
            log.error(f"Unsupported database type: {db_type}")
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
        write_csv(columns, rows, os.path.join(output_dir, f"sentry_policies.csv"))
        conn.close()
        log.debug("Sentry Policy collection finished.")
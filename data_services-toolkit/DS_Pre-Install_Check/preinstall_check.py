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

# Default
import json
import os
import socket
from socket import gaierror
import subprocess
import re
import logging
import yaml

# Install via Pip3
import requests
import urllib3
from urllib.parse import quote as quote_url
from urllib3.exceptions import InsecureRequestWarning
import xlsxwriter
import cm_client
from cm_client.rest import ApiException

urllib3.disable_warnings(InsecureRequestWarning)


class XlsxHandler:
    def __init__(self, name, formats, worksheets):
        self.__workbook_name = name
        self.formats = formats
        self.worksheets = worksheets

        # Initiate workbook
        self._workbook = xlsxwriter.Workbook(self.__workbook_name)

        # Initiate workbook row indices
        self.ws_idx = {x: 0 for x in self.worksheets.keys()}

        # Initiate worksheets and formats
        self._ws = {x: self._workbook.add_worksheet(y) for x, y in self.worksheets.items()}
        self._ft = {x: self._workbook.add_format(y) for x, y in self.formats.items()}

    def write_cell(self, worksheet: str, cell: tuple, value, cell_format='header'):
        # cell is a tuple of (row, column), zero indexed
        logging.debug("writing to worksheet [{0}] in cell [{1}] with value [{2}] using format [{3}]"
                      .format(worksheet, str(cell), value, cell_format))
        self._ws[worksheet].write(cell[0], cell[1], value, self._ft[cell_format])

    def add_row(self, worksheet, header: str, values: list, header_format='header', value_format='text'):
        row_idx = self.ws_idx[worksheet]
        self.write_cell(worksheet, (row_idx, 0), header, header_format)
        for col_idx, value in enumerate(values):
            self.write_cell(worksheet, (row_idx, col_idx + 1), value, value_format)
        self.ws_idx[worksheet] = row_idx + 1

    def set_column(self, worksheet, first_col, last_col, width):
        # Format Worksheet cell width
        self._ws[worksheet].set_column(first_col, last_col, width=width)

    def close(self):
        self._workbook.close()


class CmHandler:
    def __init__(self, host, username='admin', password='admin', verify_ssl=False, api_version='v41', port='7183'):
        self.host = host
        self.username = username
        self.password = password
        self.verify_ssl = verify_ssl
        self.api_url = 'https://' + host + ':' + port + '/api/' + api_version  # api_url

        # Init CM client
        cm_client.configuration.username = self.username
        cm_client.configuration.password = self.password
        cm_client.configuration.verify_ssl = self.verify_ssl
        self._cm_config = cm_client.Configuration()

        # Init API Clients
        self.api_client = cm_client.ApiClient(self.api_url)
        self.hosts_api = cm_client.HostsResourceApi(self.api_client)  # hosts_api_instance
        self.rcg_api = cm_client.RoleConfigGroupsResourceApi(self.api_client)  # api_instance
        self.services_api = cm_client.ServicesResourceApi(self.api_client)  # services_api_instance
        self.cluster_api = cm_client.ClustersResourceApi(self.api_client)  # cluster_api_instance

    def get_uri(self, path):
        logging.debug("Calling URI {0}".format(self.api_url + '/' + path))
        response = requests.get(
            self.api_url + '/' + path,
            verify=self.verify_ssl,
            auth=(self._cm_config.username, self._cm_config.password)
        )
        return response


class CompatibilityChecker:
    def __init__(self, cm_handler=None, report_handler=None, ecs_hosts=None, ecs_db_host=None, debug=False,
                 ssh_user=None, ssh_key=None, ssh_disable_strict=False):
        # static values
        self.supported_postgres_versions = ["10", "11", "12", "14"]
        self.supported_mysql_versions = ["8.0", "5.7", "5.6"]
        self.supported_mariaDB_versions = ["10.5", "10.4", "10.3", "10.2"]
        self.python_hue_version = ["Python 2.7.5"]
        self.required_services = ["ZOOKEEPER", "HDFS", "OZONE", "HBASE", "HIVE", "KAFKA", "SOLR", "RANGER", "ATLAS",
                                  "YARN"]
        self.hue_services = {
            'hue': {'hue_load_balancer': 'LOAD_BALANCER', 'hue_server': 'SERVER', 'kerberos_ticket_renewer': 'KT'}
        }
        self.rhel_versions = [
            "Red Hat Enterprise Linux Server release 8.4 (Ootpa)",
            "Red Hat Enterprise Linux Server release 8.2 (Ootpa)",
            "Red Hat Enterprise Linux Server release 7.9 (Maipo)",
            "Red Hat Enterprise Linux Server release 7.7 (Maipo)",
            "Red Hat Enterprise Linux Server release 7.6 (Maipo)"
        ]
        self.centos_versions = [
            "CentOS Linux release 8.2.2004 (Core)",
            "CentOS Linux release 7.9.2009 (Core)",
            "CentOS Linux release 7.7.1908 (Core)",
            "CentOS Linux release 7.6.1810 (Core)"
        ]
        self.oracle_java_versions = ["1.8"]
        self.open_jdk_versions = ["1.8", "11.0"]
        self.ssh_errors = [
            'Could not resolve hostname',
            'Permission denied'
        ]

        # Logging
        log_level = logging.DEBUG if debug else logging.ERROR
        logging.basicConfig(filename='DS_PreInstallCheck.log', level=log_level)
        logging.getLogger().addHandler(logging.StreamHandler())

        # user inputs
        self.ecs_hosts = ecs_hosts
        self.ecs_db_host = ecs_db_host
        self.cm = cm_handler
        self.report = report_handler
        self.ssh_key = ssh_key
        self.ssh_user = ssh_user
        self.ssh_host_key_checks_disable = ssh_disable_strict

        # Init shared info
        self.ssh_cmd = None
        self.scp_cmd = None
        self.cm_db_host = None
        self.hosts_info = None
        self.clusters = None

    def main_process(self):
        # Init report
        self.report = self.report if self.report is not None else self.init_report()
        self.report.add_row('vers', 'Hostname', ['Error on Host'], value_format='header')
        self.report.add_row('tls', 'Hostname', ['SSL Parameter Name', 'SSL Enabled?'], value_format='header')
        self.report.add_row('kerb', 'Name of Service', ['Kerberos Parameter Name', 'Kerberos Parameter Value'],
                            value_format='header')
        # Init Connectivity Controls
        self.init_connectivity()

        # Fetch hosts list from CM, if connected
        if self.cm:
            self.check_dns(self.cm.host)
            self.hosts_info = self.cm.hosts_api.read_hosts(view='FULL')
        # Check DNS resolution for ECS hosts, if provided
        if self.ecs_hosts:
            _ = [self.check_dns(x) for x in self.ecs_hosts]
        # Check passwordless SSH to all ECS hosts, and CM hosts, if provided
        self.check_ssh()

        # Run CDP Base checks if CmHandler is setup
        if self.cm:
            self.cm_db_host = self.get_cm_db_host()
            self.clusters = self.get_cluster_info()
            self.check_os_version()
            self.check_db()
            self.check_clusters()
            self.check_hue_python()
            for cluster in self.clusters:
                self.check_services_security(
                    self.clusters[cluster]['display_name'],
                    self.clusters[cluster]['service_names']
                )
            self.check_parcel_space()
            self.check_java_version()

        # Run ECS checks
        if self.ecs_hosts is not None:
            self.run_ecs_host_checks()
        if self.ecs_db_host is not None:
            self.check_postgres_encryption(self.ecs_db_host)

        # Close report
        self.finalise_report()

    def init_connectivity(self):
        self.ssh_cmd = 'ssh'
        if self.ssh_key is not None:
            self.ssh_cmd += '-i ' + os.path.expanduser(self.ssh_key)
        if self.ssh_host_key_checks_disable:
            self.ssh_cmd += ' -o StrictHostKeyChecking=no'
        if self.ssh_user is not None:
            self.ssh_cmd += ' ' + self.ssh_user


        self.scp_cmd = 'scp'

    def run_ecs_host_checks(self):
        ecs_checks = [
            ("All ECS nodes have clean iptables", self.check_iptables),
            ("All ECS nodes have scsi devices", self.check_scsi),
            ("All ECS nodes have devices with ftype=1", self.check_ftype),
            ("All ECS nodes are not running firewalld", self.check_firewalld),
            ("All ECS nodes are running either NTP or Chronyd", self.check_time_svcs),
            ("All ECS nodes have vm.swappiness=1", self.check_swappiness),
            ("All ECS nodes have nfs utils installed", self.check_nfs_utils),
            ("All ECS nodes have SE Linux disabled", self.check_se_linux)
        ]
        for statement, check_func in ecs_checks:
            logging.info("Checking: {0}".format(statement))
            result = "Yes" if all([check_func(y) for y in self.ecs_hosts]) else "No"
            self.report.add_row('summary', statement, [result])

    @staticmethod
    def init_report():
        return XlsxHandler(
            name='Version_Check.xlsx',
            formats={
                'header': {'bold': True, 'italic': False, "center_across": True, 'font_size': 13},
                'text': {'text_wrap': True}
            },
            worksheets={
                'summary': 'Status Summary',  # worksheet1
                'vers': 'Incompatible Versions Error Log',  # worksheet2
                'tls': 'TLS Service Level Info',  # worksheet3
                'kerb': 'Kerberos Information'  # worksheet4
            }
        )

    def finalise_report(self):
        # Format Worksheet cell width
        self.report.set_column('summary', 0, 4, 100)
        self.report.set_column('vers', 0, 4, 100)
        self.report.set_column('tls', 0, 4, 50)
        self.report.set_column('kerb', 0, 4, 50)
        logging.debug("Closing Xlsx workbook")
        self.report.close()

    def get_cm_db_host(self):
        # Get DB Host & check compatibility
        db_host = subprocess.getoutput(
            "ssh {0} 'cat /etc/cloudera-scm-server/db.properties |egrep host | cut -c 26-'".format(self.cm.host))
        p = '(?P<host>[^:/ ]+).?(?P<port>[0-9]*).*'
        m = re.search(p, db_host)
        return m.group('host')

    def check_ssh(self):
        # Avoiding additional dependency of Paramiko, but it means we need to handle our own SSH errors
        if self.hosts_info is not None:
            for k in self.hosts_info.items:
                result = subprocess.getoutput("%s %s 'sudo tail -1 /var/log/messages'" % (self.ssh_cmd, k.hostname))
                if any(x in result for x in self.ssh_errors):
                    logging.error("Passwordless SSH with sudo not working for {0}, response was {1}"
                                  .format(k.hostname, result))
                    raise(ConnectionError("SSH test for %s failed with %s" % (k.hostname, result)))
                else:
                    logging.info("Passwordless SSH working for {0}, message response was {1}"
                                 .format(k.hostname, result))

        if self.ecs_hosts is not None:
            for k in self.ecs_hosts:
                result = subprocess.getoutput("%s %s 'sudo tail -1 /var/log/messages'" % (self.ssh_cmd, k))
                if 'Permission denied' in result:
                    logging.error("Passwordlss SSH with sudo not working for {0}, response was {1}"
                                  .format(k, result))
                else:
                    logging.info("Passwordless SSH working for {0}, message response was {1}"
                                 .format(k, result))

    def check_db(self):
        r = self.cm.get_uri('cm/scmDbInfo')
        first_pair = next(iter((json.loads(r.text).items())))
        self.report.add_row('summary', str(first_pair[0]), [str(first_pair[1])])

        db_version_result_aggregate = []

        if first_pair[1] == "POSTGRESQL":
            db_version = subprocess.getoutput("ssh {0} 'postgres --version'".format(self.cm_db_host))
            head, sep, tail = db_version.partition('.')
            temp = head
            head, sep, tail = temp.partition('(PostgreSQL) ')
            db_version = tail

            postgres_result = any(db_version in string for string in self.supported_postgres_versions)

            # Check if Version of PostgreSQL is Compatible
            if not postgres_result:
                self.report.add_row('vers', "The postgres version installed is not supported", ['Yes'])
            else:
                db_version_result_aggregate.append(str(postgres_result))

            bool_result = any("False" in string for string in db_version_result_aggregate)
            # Write Summary Result for DB Version to Worksheet
            if not bool_result:
                self.report.add_row('summary', 'Is the version of postgres running supported?', ['Yes'])
            else:
                self.report.add_row('summary', 'Is the version of postgres running supported?', ['No'])

        # Check if DB Type is MySQL or MariaDB
        elif first_pair[1] == "MYSQL" or first_pair[1] == "MARIADB":
            db_version = subprocess.getoutput("ssh {0} 'mysql -V'".format(self.cm_db_host))
            head, sep, tail = db_version.partition('Distrib ')
            temp = tail
            head, sep, tail = temp.partition('-MariaDB')
            temp2 = head
            x = temp2.split('.')
            db_version = x[0] + '.' + x[1]
            print(db_version)
            db_result = any(db_version in string for string in self.supported_mysql_versions) or any(
                db_version in string for string in self.supported_mariaDB_versions)

            # Check if Version of MariaDB / MySQL Installed is Supported
            if not db_result:
                self.report.add_row('summary', 'Is the MariaDb/MySQL db version installed supported?', ['No'])
            else:
                db_version_result_aggregate.append(str(db_result))

            # Write Result to Worksheet
            bool_result = any("False" in string for string in db_version_result_aggregate)
            if not bool_result:
                self.report.add_row('summary', "The version of {0} installed is supported".format(first_pair[1]),
                                    ['Yes'])
            else:
                self.report.add_row('summary', "The version of {0} installed is supported".format(first_pair[1]),
                                    ['No'])

    def get_cluster_info(self):
        clusters = {}
        api_response = self.cm.cluster_api.read_clusters(view='SUMMARY')
        for cluster in api_response.items:
            services = self.cm.services_api.read_services(cluster.display_name, view='FULL')
            cluster_services = []
            service_names = []
            for service in services.items:
                cluster_services.append(service.type)
                service_names.append(service.name)
            clusters[cluster.name] = {
                'display_name': cluster.display_name,
                'cluster_services': cluster_services,
                'service_names': service_names
            }
        logging.debug(clusters)
        return clusters

    def check_clusters(self):
        service_result = []
        for cluster_name in self.clusters.keys():
            display_name = self.clusters[cluster_name]['display_name']
            # Process TLS Result
            r2 = self.cm.get_uri('clusters/{0}/isTlsEnabled'.format(quote_url(display_name)))
            response = 'Yes' if r2.ok else r2.status_code
            self.report.add_row('summary', "{0} is TLS Secured".format(display_name), [response, ])

            # Process Kerberos Result
            r3 = self.cm.get_uri('cm/kerberosInfo')
            second_pair = json.loads(r3.text)
            values = list(second_pair.values())
            if values[1]:
                self.report.add_row('summary', "{0} has Kerberos enabled".format(display_name), ['Yes'])
            else:
                self.report.add_row('summary', "{0} has Kerberos enabled".format(display_name), ['No'])

            # Check Required Services are installed
            service_result.append(
                all(elem in self.clusters[cluster_name]['cluster_services'] for elem in self.required_services)
            )
        if service_result:
            self.report.add_row('summary', "Required Services are not Installed", ['Yes'])
        else:
            self.report.add_row(
                'summary', "All Required Services are Installed for all clusters",
                ["All Clusters require" + str(self.required_services) + "to be considered a supported base cluster"]
            )

    def check_hue_python(self):
        python_version_result_aggregate = []
        for i in self.hue_services:
            for j in self.hue_services[i]:
                for k in self.hosts_info.items:
                    for l in k.role_refs:
                        if self.hue_services[i][j] in l.role_name and i in l.role_name:
                            installed_python_version = subprocess.getoutput("%s %s 'python -V'" % (self.ssh_cmd, k.hostname))
                            python_result = any(
                                installed_python_version in string for string in self.python_hue_version
                            )
                            if not python_result:
                                self.report.add_row('vers', k.hostname, [installed_python_version])
                            else:
                                python_version_result_aggregate.append(str(python_result))

        # Write Python Summary Status to Sheet
        bool_result = any("False" in string for string in python_version_result_aggregate)
        if not bool_result:
            self.report.add_row('summary', 'Are all base cluster nodes are running the supported version of python?',
                                ['Yes'])

    def get_rcg_info(self, cluster_name, service_full_name, service_short_name):
        try:
            return self.cm.rcg_api.read_config(cluster_name, service_full_name, service_short_name, view="summary")
        except ApiException as e:
            print("Exception when calling RoleConfigGroupsResourceApi->read_config: %s\n" % e)

    def get_service_info(self, cluster_name, service_short_name):
        try:
            return self.cm.services_api.read_service_config(cluster_name, service_short_name, view="summary")
        except ApiException as e:
            print("Exception when calling ServicesResourceApi->read_config: %s\n" % e)

    def check_service_config(self, cluster_name, short_name, suffixes=None, rcg_items=None, svc_items=None):
        if svc_items is not None:
            svc_config = self.get_service_info(cluster_name, short_name)
            for config_item in svc_config.items:
                for ws, header, terms in svc_items:
                    if config_item.name in terms:
                        self.report.add_row(ws, header, [config_item.name, config_item.value])

        if rcg_items is not None:
            suffixes = suffixes if suffixes is not None else [""]
            for suffix in suffixes:
                rcg_config = self.get_rcg_info(cluster_name, short_name + suffix, short_name)
                for config_item in rcg_config.items:
                    for ws, header, terms in rcg_items:
                        if config_item.name in terms:
                            self.report.add_row(ws, header, [config_item.name, config_item.value])

    def check_services_security(self, cluster_name, service_list):
        for service_name in service_list:
            if 'atlas' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-ATLAS_SERVER-BASE"],
                    svc_items=[
                        ('kerb', "Atlas", ["ssl_enable", "ssl_enabled"]),
                    ],
                    rcg_items=[
                        ('tls', "Atlas", ["kerberos.auth.enable"])
                    ]
                )
            if 'hbase' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-HBASERESTSERVER-BASE", "-HBASETHRIFTSERVER-BASE"],
                    rcg_items=[
                        ('tls', "HBase Rest Server", ["hbase_restserver_ssl_enable", "hbase_restserver_ssl_enabled"]),
                        ('tls', "HBase Thrift Server", ["hbase_thriftserver_http_use_ssl", "hbase_thriftserver_https_use_ssl"]),
                        ],
                    svc_items=[
                        ('kerb', "HBase", ["hbase_security_authentication", "hbase_restserver_security_authentication"])
                    ]
                )
            if 'hdfs' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    svc_items=[
                        ('tls', "HDFS", ["hdfs_hadoop_ssl_enabled", "hdfs_hadoop_ssl_enable"]),
                        ('kerb', "HDFS", ["hadoop_security_authentication", "hadoop_secure_web_ui"])
                    ]
                )
            if "hive" in service_name.lower() and "hive_on_tez" not in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    svc_items=[
                        ('tls', "Hive Metastore Server", ["ssl_enabled_database", "ssl_enable_database"]),
                        ('tls', "Hive Server 2", ["hiveserver2_enable_ssl", "hiveserver2_enabled_ssl"])
                    ]
                )
            if 'hue' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-HUE_SERVER-BASE"],
                    rcg_items=[
                        ('tls', "Hue", ["ssl_enable", "ssl_enabled"])
                    ]
                )
            if 'impala' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    svc_items=[
                        ('tls', "Impala", ["client_services_ssl_enabled", "client_services_ssl_enable"])
                    ]
                )
            if 'kafka' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-KAFKA_BROKER-BASE", "-KAFKA_CONNECT-BASE", "-KAFKA_MIRROR_MAKER-BASE"],
                    rcg_items=[
                        ('tls', "Kafka Broker", ["ssl_enable", "ssl_enabled"]),
                        ('tls', "Kafka Connect", ["ssl_enable", "ssl_enabled"]),
                        ('tls', "Kafka Mirror Maker", ["ssl_enable", "ssl_enabled"])  # TODO: Check services have SSL enabled or report as insecure
                    ],
                    svc_items=[
                        ('kerb', "Kafka", ["kerberos.auth.enable"])
                    ]
                )
            if 'ranger' in service_name.lower() and 'ranger_rms' not in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-RANGER_ADMIN-BASE", "-RANGER_TAGSYNC-BASE"],
                    rcg_items=[
                        ('tls', "Ranger Admin", ["ssl_enable", "ssl_enabled"]),
                        ('tls', "Ranger Tagsync", ["ssl_enable", "ssl_enabled"])
                    ]
                )
            if 'ranger_rms' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-RANGER_RMS_SERVER-BASE"],
                    rcg_items=[
                        ('tls', "Ranger RMS", ["ssl_enable", "ssl_enabled"])
                    ],
                    svc_items=[
                        ('kerb', "Ranger RMS", ['ranger_rms_authentication'])
                    ]
                )
            if 'solr' in service_name.lower() and 'solr_user' not in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    svc_items=[
                        ('tls', "Solr", ["solr_use_ssl"]),
                        ('kerb', "Solr", ['solr_security_authentication'])
                    ]
                )
            if 'zookeeper' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    svc_items=[
                        ('tls', "Zookeeper", ["zookeeper_tls_enabled", "ssl_enabled"]),
                        ('kerb', "Zookeeper", ['enableSecurity', 'quorum_auth_enable_sasl'])
                    ]
                )
            if 'ozone' in service_name.lower():
                self.check_service_config(
                    cluster_name=cluster_name,
                    short_name=service_name,
                    suffixes=["-OZONE_DATANODE-BASE", "-OZONE_MANAGER-BASE", "-OZONE_RECON-BASE", "-S3_GATEWAY-BASE",
                              "-STORAGE_CONTAINER_MANAGER-BASE"],
                    rcg_items=[
                        ('tls', "Ozone Datanode", ["ssl_enabled", "ssl_enable"]),
                        ('tls', "Ozone Manager", ["ssl_enabled", "ssl_enable"]),
                        ('tls', "Ozone Recon", ["ssl_enabled", "ssl_enable"]),
                        ('tls', "Ozone Gateway", ["ssl_enabled", "ssl_enable"]),
                        ('tls', "Ozone Storage Container Manager", ["ssl_enabled", "ssl_enable"]),
                    ],
                    svc_items=[
                        ('kerb', "Ozone", ['ozone.security.enabled', 'ozone.security.http.kerberos.enabled'])
                    ]
                )

    def check_os_version(self):
        linux_version_result_aggregate = []
        for k in self.hosts_info.items:
            installed_os_version = subprocess.getoutput("%s %s 'cat /etc/redhat-release'" % (self.ssh_cmd, k.hostname))
            os_result = any(installed_os_version in string for string in self.rhel_versions) or any(
                installed_os_version in string for string in self.centos_versions)
            if not os_result:
                self.report.add_row('vers', k.hostname, [installed_os_version])
                linux_version_result_aggregate.append(str(os_result))
            else:
                linux_version_result_aggregate.append(str(os_result))
        # Write Summary Result for Linux Version
        bool_result_linux = any("False" in string for string in linux_version_result_aggregate)
        if not bool_result_linux:
            self.report.add_row('summary', "All base cluster nodes are running the supported version of Linux", ['Yes'])
        else:
            self.report.add_row('summary', "All base cluster nodes are running the supported version of Linux", ['No'])

    def check_parcel_space(self):
        parcel_result_aggregate = []
        for k in self.hosts_info.items:
            # Check if there is enough space on parcel directory to accommodate CDP Parcel
            parcel_space = subprocess.getoutput(
                "%s %s df -h /opt/cloudera/parcels | awk \'{print $4}\' | egrep \"G\" | sed \"s/G//\"" % (self.ssh_cmd, k.hostname))
            parcel_space = int(parcel_space)
            if parcel_space < 20:
                self.report.add_row('vers', k.hostname, ["20GB not free on /opt/cloudera/parcels dir"])
                parcel_result_aggregate.append(str("Yes"))
            else:
                parcel_result_aggregate.append(str("No"))
        # Write Summary Result for CDP Parcel Space
        bool_result_parcel = any("False" in string for string in parcel_result_aggregate)
        if bool_result_parcel:
            self.report.add_row(
                'summary', "All base cluster nodes have enough space to accommodate the CDP Parcel (20GB)", ['Yes'])
        else:
            self.report.add_row(
                'summary', "All base cluster nodes have enough space to accommodate the CDP Parcel (20GB)", ['No'])

    def check_java_version(self):
        java_version_result_aggregate = []
        for k in self.hosts_info.items:
            # Check Java Version
            installed_java_version = subprocess.getoutput(
                "%s %s java -version 2>&1 | grep \"version\" 2>&1 | awk -F\\\" '{ split($2,a,\".\"); print a[1]\".\"a[2]}'" % (self.ssh_cmd, k.hostname))
            java_result = any(installed_java_version in string for string in self.oracle_java_versions) or any(
                installed_java_version in string for string in self.open_jdk_versions)

            # If version is unsupported, add the hostname and java version that is not supported to the spreadsheet
            if not java_result:
                full_java_ver_info = subprocess.getoutput("%s %s 'java -version'" % (self.ssh_cmd, k.hostname))
                self.report.add_row('vers', k.hostname, [full_java_ver_info])
                java_version_result_aggregate.append(str(java_result))
            else:
                java_version_result_aggregate.append(str(java_result))
        # Write Summary Result for Java Version
        bool_result_java = any("False" in string for string in java_version_result_aggregate)
        if not bool_result_java:
            self.report.add_row(
                'summary', "All base cluster nodes are running the supported version of Java", ['Yes'])
        else:
            self.report.add_row(
                'summary', "All base cluster nodes are running the supported version of Java", ['No'])

    def check_iptables(self, host: str):
        os.system("%s virgin_iptable.txt %s:/tmp/" % (self.scp_cmd, host))
        os.system("%s iptable_check.sh %s:/tmp/" % (self.scp_cmd, host))
        iptable_check = subprocess.getoutput("%s %s 'sh /tmp/iptable_check.sh'" % (self.ssh_cmd, host))
        if "clean iptables" in iptable_check:
            return True
        else:
            self.report.add_row('vers', host, ["Iptables are filled with rules"])
            return False

    def check_scsi(self, host: str):
        os.system("%s scsi_check.sh %s:/tmp/" % (self.scp_cmd, host))
        scsi_check = subprocess.getoutput("%s %s 'sh /tmp/scsi_check.sh'" % (self.ssh_cmd, host))
        if "all devices are scsi" in scsi_check:
            return True
        else:
            self.report.add_row('vers', host, [scsi_check])
            return False

    def check_ftype(self, host: str):
        os.system("%s ftype.sh %s:/tmp/" % (self.scp_cmd, host))
        ftype_check = subprocess.getoutput("%s %s 'sh /tmp/ftype.sh'" % (self.ssh_cmd, host))
        if "ftype=1" == ftype_check:
            return True
        else:
            self.report.add_row('vers', host, [ftype_check])
            return False

    def check_firewalld(self, host: str):
        firewalld_output = subprocess.getoutput("%s %s 'systemctl status firewalld.service | grep Active'" % (self.ssh_cmd, host))
        if "inactive" in firewalld_output or "Unit firewalld.service could not be found." in firewalld_output:
            return True
        else:
            self.report.add_row('vers', host, ["Firewalld is Running"])
            return False

    def check_time_svcs(self, host: str):
        chronyd_output = subprocess.getoutput("%s %s 'systemctl status chronyd.service | grep Active'" % (self.ssh_cmd, host))
        ntpd_output = subprocess.getoutput("%s %s 'systemctl status ntpd.service | grep Active'" % (self.ssh_cmd, host))
        if "running" in chronyd_output or "running" in ntpd_output:
            return True
        else:
            self.report.add_row('vers', host, ["Chronyd/NTPD is not running"])
            return False

    def check_swappiness(self, host: str):
        vm_output = subprocess.getoutput("%s %s 'cat /etc/sysctl.conf | grep vm.swappiness'" % (self.ssh_cmd, host))
        if "1" in vm_output:
            return True
        else:
            self.report.add_row('vers', host, [vm_output])
            return False

    def check_nfs_utils(self, host: str):
        nfs_output = subprocess.getoutput("%s %s 'rpm -qa | grep nfs-utils'" % (self.ssh_cmd, host))
        if "nfs-utils" in nfs_output:
            return True
        else:
            self.report.add_row('vers', host, ["NFS Utility needs to be installed"])
            return False

    def check_se_linux(self, host: str):
        se_output = subprocess.getoutput("%s %s 'sestatus'" % (self.ssh_cmd, host))
        if "disabled" in se_output or "permissive" in se_output or "bash: sestatus: command not found" in se_output:
            return True
        else:
            self.report.add_row('vers', host, ["SE Linux needs to be set to disabled or permissive"])
            return False

    @staticmethod
    def check_dns(host: str):
        try:
            logging.debug("Checking DNS for {0}".format(host))
            _ = socket.getaddrinfo(host, 22)
        except gaierror:
            raise

    def check_postgres_encryption(self, host: str):
        encryption_result = subprocess.getoutput(
            "%s %s \'cat /var/lib/pgsql/10/data/postgresql.conf | grep \"ssl =\"\'" % (self.ssh_cmd, host))
        if encryption_result in "ssl = on":
            self.report.add_row('summary', "The ECS Cluster Postgres DB is Encrypted", ['Yes'])
        else:
            self.report.add_row('summary', "The ECS Cluster Postgres DB is Encrypted", ['No'])


def main():
    with open('config.yml', 'r') as config_s:
        try:
            config = yaml.safe_load(config_s)
        except yaml.YAMLError as e:
            raise e

    CompatibilityChecker(
        cm_handler=CmHandler(
            host=config['cm']['host'],
            username=config['cm']['username'],
            password=config['cm']['password']
        ),
        ecs_hosts=config['ecs']['hosts'],
        ecs_db_host=config['ecs']['db_host'],
        debug=config['debug'] if 'debug' in config else False
    ).main_process()


if __name__ == '__main__':
    main()

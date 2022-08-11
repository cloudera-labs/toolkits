#!/bin/bash

# Copyright 2021 Cloudera, Inc.
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

# Disclaimer
# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: install_cm.sh
# Author: WKD
# Date: 12JUN22
# Purpose: Install Cloudera Manager. This script will install 
# the Cloudera Manager server, the supporting database, and the
# Cloudera Manager agents. This script must be run on the cmhost.
# A text file, list_host, listing all of the nodes in the cluster, is
# required.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
HOST=cmhost.example.com
HOST_FILE=${DIR}/conf/list_host.txt
PASSWORD=BadPass@1
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/install_cm_agent.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [all|cm|database|show]"
        exit
}

function call_include() {
# Test for include script.

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin//include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function install_database() {
# Install Mariadb software

	sudo yum install -y mariadb-server
	# Enable Mariadb
	sudo systemctl enable --now mariadb
	sleep 180
	# mysql_secure_installation
	mysql -e "UPDATE mysql.user SET Password=PASSWORD('${PASSWORD}') WHERE User='root'"
	mysql -e "DELETE FROM mysql.user WHERE User=''"
	mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
	mysql -e "DROP DATABASE IF EXISTS test"
	mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
	mysql -e "FLUSH PRIVILEGES"
}

function config_database() {
# setup CDP databases
	mysql -e "source ~/ddl/create_cdp_databases.ddl"
	# Show data
	mysql -e "SELECT user FROM mysql.user"

	echo "Your MariaDB installation is complete"
}

function check_database() {
# check data
	mysql -e "SELECT user FROM mysql.user" > /dev/null
	ANS=$?

	if [ $ANS =eq 1 ]; then
		echo "ERROR: Database is not installed. Set up database first"
	fi
}

function setup_repo_file() {
# Create /etc/yum.repos.d

	sudo rm ~/config/cloudera-manager.repo

	sudo tee ~/config/cloudera-manager.repo > /dev/null << EOF
[cloudera-manager]
# Packages for Cloudera Manager, Version 7.4.4 on RedHat or CentOS 7.9 x86_64"
name=Cloudera Manager 
baseurl=http://cmhost:8064/cloudera/cm7/cm7.4.4/
gpgkey=http://cmhost:8064/cloudera/cm7/cm7.4.4/RPM-GPG-KEY-cloudera
gpgcheck=1
enabled=1
EOF

	sudo cp ~/config/cloudera-manager.repo /etc/yum.repos.d/
}

function install_cm() {
# Install cloudera manager server, agent, and daemons

	sudo yum -y install cloudera-manager-server cloudera-manager-daemons cloudera-manager-agent

	# Set up CDP databases
	sudo /opt/cloudera/cm/schema/scm_prepare_database.sh mysql scm scm BadPass@1

	# Enable and start cloudera manager services
	sudo systemctl enable --now cloudera-scm-server cloudera-scm-agent cloudera-manager-daemons
}

function message() {
# Post install message

	echo " "
	echo "Everything is installed and ready. Wait a few minutes and then open Cloudera Manager Web UI"
	echo " "
}

function show_server() {
# Show status of CM server.

    sudo systemctl status mariadb.service
    sudo systemctl status cloudera-scm-server
}

function run_option() {
# Case statement for options.

    case "${OPTION}" in
        -h | --help)
            usage
            ;;
    all)
       	check_arg 1
       	install_database
       	config_database
       	setup_repo_file 
	 	install_cm
		message
       	;;
    cm)
      	check_arg 1
		check_database
       	setup_repo_file 
	 	install_cm
		message
      	;;
    database)
       	check_arg 1
       	install_database
       	config_database
      	;;
     show)
       	check_arg 1
       	show_server
       	;;
     *)
       	usage
       	;;
    esac
}

# MAIN
# Run checks
call_include
check_sudo
setup_log

# Run command
run_option

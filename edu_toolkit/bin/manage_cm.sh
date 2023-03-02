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

# Title: manage_cm.sh
# Author: WKD
# Date: 12JUN22
# Purpose: Install Cloudera Manager. This script will install 
# the Cloudera Manager server, the supporting database, and the
# Cloudera Manager agents. This script must be run on the cmhost.
# A text file, list_host, listing all of the nodes in the cluster, is
# required. The script will also setup Cloudera Manager as an intermediate 
# CA. Use this script to delete the Cloudera Manager server and agents.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
option=$1
dir=${HOME}
host=cmhost.example.com
host_FILE=${dir}/conf/list_host.txt
cm_admin=training
cm_password=BadPass@1
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        exit
}

function get_help() {
# help page

cat << EOF
SYNOPSIS
	manage_cm.sh [OPTION]

DESCRIPTION
	Manage Cloudera Manager (CM) install, uninstall, and creating an 
	intermediate CA.

    	-h, --help)
		Help page
	-a, --agent
	 	Delete and clean out all CM agents	
	-c, --cert
		Configure CM as an intermediate CA	
	-d, --delete
		Delete the certificate files
	-i, --install
		Install the Cloudera Manager server
	-l, --list
		List the status of the CM server and the database	
	-s, --server
		Delete the CM server	
EOF
	exit
}

function call_include() {
# Test for include script.

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}


## INSTALL

function check_database() {
# check data
	mysql -e "SELECT user FROM mysql.user" > /dev/null
	ANS=$?

	if [ $ANS =eq 1 ]; then
		echo "ERROR: Database is not installed. Set up database first"
	fi
	exit 1
}

function install_cm_db() {
# setup CDP databases
	mysql -e "source ${dir}/ddl/create_cdp_databases.ddl"
	# Show data
	mysql -e "SELECT user FROM mysql.user"

	echo "Your MariaDB installation is complete"
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

function msg_cm() {
# Post install msg_cm

	echo " "
	echo "Everything is installed and ready. Wait a few minutes and then open Cloudera Manager Web UI"
	echo " "
}

# CM CA
function setup_cert() {
# Setup the certificate manager directory.

        sudo mkdir -p /var/lib/cloudera-scm-server/certmanager
        sudo chown -R cloudera-scm:cloudera-scm /var/lib/cloudera-scm-server/certmanager
}

function init_cert() {
# Create the private key and the certificate signing request in the
# certificate manager directory.

        sudo sh -c "export JAVA_HOME=/usr/java/default; /opt/cloudera/cm-agent/bin/certmanager --location /var/lib/cloudera-scm-server/certmanager  setup --configure-services --override ca_dn=CN=cmhost.example.com --stop-at-csr"
}

function kinit_root() {
# Initiate a TGT for root. This is required to run the IPA command.
        sudo sh -c "kinit -kt /etc/krb5.keytab host/cmhost.example.com"
}

function sign_cert() {
# Use IPA command to sign the certificate signing request.
        sudo sh -c "ipa cert-request /var/lib/cloudera-scm-server/certmanager/CMCA/private/ca_csr.pem --principal=host/cmhost.example.com --chain --certificate-out=/var/lib/cloudera-scm-server/certmanager/CMCA/private/ca_crt.pem"
}

function generate_cm_ca() {
# Use the REST API to run Auto-TLS to generate all keystores and PEM files
# on all hosts.

        curl -i -v -u training -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{
"location": "/var/lib/cloudera-scm-server/certmanager",
"additionalArguments" : ["--override", "ca_dn=CN=cmhost.example.com",
"--signed-ca-cert=/var/lib/cloudera-scm-server/certmanager/CMCA/private/ca_crt.pem"],
"configureAllServices" : "true",
"sshPort" : 22,
"userName" : "${cm_admin}",
"password" : "${cm_password}"
}' "http://${host}:7180/api/v41/cm/commands/generateCmca"
}

# DELETE CM CA

function delete_cert() {
# Remove the certmanager directory and any files.

        rm -r -f /var/lib/cloudera-scm-server/certmanager
}


# DELETE

function msg_server() {
# List actions to complete prior to running the script

        echo "The following steps must be completed:"
        echo "1. Cloudera Manager Home > Cluster Action > Stop"
        echo "2. Deactivete all Parcels"
        echo "3. Cloudera Manager Home > Parcels > Deactivate"
        echo "4. Cloudera Manager Home > Cluster Action > Delete"
        echo -n "Confirm the clusters is deleted. "
        check_continue
}

function stop_server() {
# Stop CM and the embedded CM DB.

        sudo systemctl stop cloudera-scm-server
}

function delete_server() {
# Use yum to remove CM and the embedded CM DB.

        sudo yum remove -y cloudera-manager-server
}


function stop_agent() {
# Stop CM and the CM DB.

   for host in $(cat ${HOST_FILE}); do
        ssh -tt ${host} "sudo systemctl stop cloudera-scm-supervisord.service"  >> ${logfile} 2>&1
        RESULT=$?
        if [ ${RESULT} -eq 0 ]; then
                    echo "Stop the agent on ${host}" | tee -a ${logfile}
        else
                    echo "ERROR: Failed to stop the agent on ${host}" | tee -a ${logfile}
        fi
   done
}

function delete_agent() {
# Use yum to remove CM Agent.

   for host in $(cat ${HOST_FILE}); do
        ssh -tt ${host} "sudo yum remove -y cloudera-manager-*"  >> ${logfile} 2>&1
        RESULT=$?
        if [ ${RESULT} -eq 0 ]; then
                    echo "Removed the agent on ${host}" | tee -a ${logfile}
                                ssh -tt ${host} "sudo yum clean all"  >> ${logfile} 2>&1
        else
                    echo "ERROR: Failed to remove the agent on ${host}" | tee -a ${logfile}
        fi
   done
}

function clean_agent() {
# Glean out support files for CM Agent.

   for host in $(cat ${HOST_FILE}); do
        ssh -tt ${host} "sudo rm /tmp/.scm_prepare_node.lock"  >> ${logfile} 2>&1
        ssh -tt ${host} "sudo umount cm_process"  >> ${logfile} 2>&1
        ssh -tt ${host} "sudo rm -Rf /usr/share/cmf /var/cache/cloudera* /var/lib/yum/cloudera* /var/log/cloudera* /var/run/cloudera* "  >> ${logfile} 2>&1
        RESULT=$?
        if [ ${RESULT} -eq 0 ]; then
                    echo "Clean the agent on ${host}" | tee -a ${logfile}
        else
                    echo "ERROR: Failed to clean the agent on ${host}" | tee -a ${logfile}
        fi
   done
}

# STATUS

function list_server() {
# Show status of CM server.

    sudo systemctl status mariadb.service
    sudo systemctl status cloudera-scm-server
}

# OPTION

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-a | --agent)
			check_arg 1
			stop_agent
			delete_agent
			clean_agent
			;;
		-c | --cert)
			check_arg 1
			setup_cert
			init_cert
			sign_cert
			generate_cm_ca
			;;
		-d | --delete)
			check_arg 1
			delete_cert
			;;
		-i | --install)
			check_arg 1
			check_database
			install_cm_db
			setup_repo_file 
			install_cm
			msg_cm
			;;
		-l | --list)
			check_arg 1
			list_server
			;;
		-s | --server)
			msg_server
			stop_server
			delete_server
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Run checks
	call_include
	check_sudo

	#setup_log

	# Run command
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
